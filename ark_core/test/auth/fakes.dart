import 'dart:async';

import 'package:ark_core/auth.dart';

/// In-memory stand-in for Firestore `users/{uid}/apps/{appId}`.
class FakeRemote implements ProgressRemote {
  final docs = <String, Map<String, SyncEntry>>{};
  bool offline = false;
  bool queueWrites = false;
  int saves = 0;

  Map<String, SyncEntry> doc(String uid, String appId) =>
      docs.putIfAbsent('$uid/$appId', () => {});

  @override
  Future<Map<String, SyncEntry>> load(String uid, String appId) async {
    if (offline) throw StateError('offline');
    return Map.of(doc(uid, appId));
  }

  @override
  Future<bool> save(
    String uid,
    String appId,
    Map<String, SyncEntry> entries,
  ) async {
    if (offline) throw StateError('offline');
    saves++;
    doc(uid, appId).addAll(entries);
    return !queueWrites;
  }
}

/// Fake Firebase Auth with a fixed account list.
class FakeAuthBackend implements ArkAuthBackend {
  FakeAuthBackend({this.accounts = const {}, this.disabled = const {}});

  /// email → password
  final Map<String, String> accounts;
  final Set<String> disabled;
  bool offline = false;
  final _c = StreamController<ArkUser?>.broadcast();
  ArkUser? _user;
  String? lastEmail;

  @override
  ArkUser? get currentUser => _user;

  @override
  Stream<ArkUser?> userChanges() => _c.stream;

  @override
  Future<ArkUser> signIn(String email, String password) async {
    lastEmail = email;
    if (offline) throw const ArkAuthException(ArkAuthError.network);
    if (accounts[email] != password) {
      throw const ArkAuthException(ArkAuthError.wrongIdOrPassword);
    }
    if (disabled.contains(email)) {
      throw const ArkAuthException(ArkAuthError.disabled);
    }
    _user = ArkUser(uid: 'uid-$email', email: email);
    _c.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _c.add(null);
  }
}
