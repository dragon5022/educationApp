import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'auth_backend.dart';
import 'firebase_backend.dart';
import 'merge_rules.dart';
import 'progress_sync.dart';

enum ArkAuthStatus {
  /// [ArkAuth.init] has not finished yet.
  initializing,

  /// Firebase is not configured (or failed to start): the app runs offline
  /// and login UI is hidden or shows a friendly message.
  unavailable,
  signedOut,
  signedIn,
}

/// Per-app settings for the login module.
class ArkAuthConfig {
  const ArkAuthConfig({
    this.idDomain = 'students.ark-busters.app',
    this.supportContact,
    this.accountDeletionUrl,
  });

  /// Login ID `ark001` is sent to Firebase as `ark001@<idDomain>`. Must match
  /// the domain used by `tool/students` when creating accounts.
  final String idDomain;

  /// Shown under “パスワードを わすれたら” / “アカウントを けしたい” (e.g.
  /// `'ARK BUSTERS 事務局 info@example.com'`). Null → “じゅくの せんせい”.
  final String? supportContact;

  /// Optional page describing account/data deletion requests (shown as text;
  /// ark_core does not open URLs).
  final String? accountDeletionUrl;
}

/// Result of [ArkAuth.login].
class ArkLoginResult {
  const ArkLoginResult.success() : error = null;
  const ArkLoginResult.failure(ArkAuthError this.error);

  final ArkAuthError? error;
  bool get ok => error == null;
}

/// Login (school-issued ID + password) and cloud progress sync for one app.
///
/// Optional at runtime: with no [FirebaseOptions] the status is
/// [ArkAuthStatus.unavailable] and nothing else happens. Login never unlocks
/// paid content — it only saves progress and shares it across the series.
class ArkAuth extends ChangeNotifier with WidgetsBindingObserver {
  ArkAuth();

  /// The app-wide instance used by the widgets when none is passed.
  static final ArkAuth instance = ArkAuth();

  ArkAuthConfig _config = const ArkAuthConfig();
  ArkAuthConfig get config => _config;

  ArkAuthBackend? _backend;
  ProgressSync? _sync;
  StreamSubscription<ArkUser?>? _sub;
  bool _observing = false;

  ArkAuthStatus _status = ArkAuthStatus.initializing;
  ArkAuthStatus get status => _status;

  /// Why the module is unavailable (for logs), when it is.
  Object? unavailableReason;

  ArkUser? _user;
  ArkUser? get user => _user;

  bool _busy = false;

  /// True while a login/logout request is running.
  bool get isBusy => _busy;

  bool get isAvailable =>
      _status == ArkAuthStatus.signedOut || _status == ArkAuthStatus.signedIn;
  bool get isSignedIn => _status == ArkAuthStatus.signedIn;

  /// The login ID shown to the user (`ark001`), or null when signed out.
  String? get currentId => _user == null ? null : idForEmail(_user!.email);

  /// Progress sync, when Firebase is available and a spec was given.
  ProgressSync? get sync => _sync;

  /// Starts the module. Call once after `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// [firebaseOptions]: `DefaultFirebaseOptions.currentPlatform` from the
  /// app's `firebase_options.dart`, or null while the app has none — then the
  /// module reports [ArkAuthStatus.unavailable] and the app plays offline.
  /// If the app already called `Firebase.initializeApp` itself, that app is used.
  Future<void> init({
    required String appId,
    required FirebaseOptions? firebaseOptions,
    ProgressSyncSpec? sync,
    ArkAuthConfig config = const ArkAuthConfig(),
    AccountSwitchPolicy switchPolicy =
        AccountSwitchPolicy.replaceOtherAccountsProgress,
  }) async {
    _config = config;
    try {
      if (Firebase.apps.isEmpty) {
        if (firebaseOptions == null) {
          _markUnavailable('Firebase is not configured for this app');
          return;
        }
        await Firebase.initializeApp(options: firebaseOptions);
      }
    } catch (e) {
      _markUnavailable(e);
      return;
    }
    try {
      // Offline-first: keep reads/writes in the on-device cache.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (_) {
      // Already in use with other settings — keep them.
    }
    try {
      await initWithBackends(
        appId: appId,
        backend: FirebaseArkAuthBackend(),
        remote: sync == null ? null : FirestoreProgressRemote(),
        sync: sync,
        config: config,
        switchPolicy: switchPolicy,
      );
    } catch (e) {
      _markUnavailable(e);
    }
  }

  /// Like [init] but with explicit backends (tests, emulators, custom stores).
  /// Pass `backend: null` to simulate “Firebase not configured”.
  Future<void> initWithBackends({
    required String appId,
    required ArkAuthBackend? backend,
    ProgressRemote? remote,
    ProgressSyncSpec? sync,
    ArkAuthConfig config = const ArkAuthConfig(),
    AccountSwitchPolicy switchPolicy =
        AccountSwitchPolicy.replaceOtherAccountsProgress,
    LocalProgressStore? local,
    Duration debounce = const Duration(seconds: 3),
    bool observeLifecycle = true,
  }) async {
    _config = config;
    if (backend == null) {
      _markUnavailable('No auth backend');
      return;
    }
    await _sub?.cancel();
    _sync?.dispose();
    _backend = backend;
    _sync = (sync != null && remote != null)
        ? ProgressSync(
            appId: appId,
            spec: sync,
            remote: remote,
            local: local,
            debounce: debounce,
            switchPolicy: switchPolicy,
          )
        : null;
    _sub = backend.userChanges().listen(_onUser);
    _onUser(backend.currentUser);
    if (observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void _markUnavailable(Object reason) {
    unavailableReason = reason;
    debugPrint('[ark_core/auth] unavailable: $reason');
    _setStatus(ArkAuthStatus.unavailable);
  }

  void _onUser(ArkUser? u) {
    final prev = _user?.uid;
    _user = u;
    if (u == null) {
      _setStatus(ArkAuthStatus.signedOut);
      if (prev != null) unawaited(_sync?.stop(flush: false));
    } else {
      _setStatus(ArkAuthStatus.signedIn, force: prev != u.uid);
      if (prev != u.uid) unawaited(_sync?.start(u.uid));
    }
  }

  void _setStatus(ArkAuthStatus s, {bool force = false}) {
    if (_status == s && !force) return;
    _status = s;
    notifyListeners();
  }

  void _setBusy(bool b) {
    _busy = b;
    notifyListeners();
  }

  /// Signs in with a school-issued [id] (`ark001`) and [password].
  Future<ArkLoginResult> login(String id, String password) async {
    final backend = _backend;
    if (backend == null || !isAvailable) {
      return const ArkLoginResult.failure(ArkAuthError.unavailable);
    }
    final email = emailForId(id);
    if (email == null) {
      return const ArkLoginResult.failure(ArkAuthError.invalidId);
    }
    if (password.isEmpty) {
      return const ArkLoginResult.failure(ArkAuthError.wrongIdOrPassword);
    }
    _setBusy(true);
    try {
      final u = await backend
          .signIn(email, password)
          .timeout(const Duration(seconds: 20));
      _onUser(u);
      return const ArkLoginResult.success();
    } on ArkAuthException catch (e) {
      return ArkLoginResult.failure(e.error);
    } on TimeoutException {
      return const ArkLoginResult.failure(ArkAuthError.network);
    } catch (e) {
      debugPrint('[ark_core/auth] login failed: $e');
      return const ArkLoginResult.failure(ArkAuthError.unknown);
    } finally {
      _setBusy(false);
    }
  }

  /// Saves progress to the cloud (best effort), then signs out. Progress on
  /// this device is kept, so the app keeps working offline.
  Future<void> logout() async {
    final backend = _backend;
    if (backend == null || !isSignedIn) return;
    _setBusy(true);
    try {
      await _sync
          ?.stop(flush: true)
          .timeout(const Duration(seconds: 10), onTimeout: () {});
      await backend.signOut();
      _onUser(null);
    } finally {
      _setBusy(false);
    }
  }

  /// Call after saving progress; syncs a few seconds later (debounced).
  void notifyProgressChanged() => _sync?.notifyChanged();

  /// Syncs now (e.g. from a “セーブ” button). Null when not signed in.
  Future<SyncResult?> syncNow() async =>
      isSignedIn ? await _sync?.syncNow() : null;

  /// `ark001` → `ark001@<idDomain>`; null when the ID is not valid.
  /// Full-width input (ａｒｋ００１) is accepted. An ID containing `@` is used
  /// as an email as-is (staff/test accounts).
  String? emailForId(String id) {
    final n = normalizeId(id);
    if (n.isEmpty) return null;
    if (n.contains('@')) {
      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(n) ? n : null;
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(n)) return null;
    return '$n@${_config.idDomain}';
  }

  /// `ark001@<idDomain>` → `ark001`; other emails are returned whole.
  String idForEmail(String email) {
    final suffix = '@${_config.idDomain}';
    return email.toLowerCase().endsWith(suffix)
        ? email.substring(0, email.length - suffix.length)
        : email;
  }

  /// Trims, lower-cases and converts full-width ASCII to half-width.
  static String normalizeId(String id) {
    final b = StringBuffer();
    for (final r in id.trim().runes) {
      if (r >= 0xFF01 && r <= 0xFF5E) {
        b.writeCharCode(r - 0xFEE0);
      } else if (r == 0x3000) {
        b.write(' ');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString().trim().toLowerCase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isSignedIn) return;
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      unawaited(_sync?.syncNow());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sync?.dispose();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
