import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'merge_rules.dart';

/// Cloud side of progress sync (`users/{uid}/apps/{appId}` in Firestore).
/// Abstracted so tests (and future backends) can provide their own.
abstract class ProgressRemote {
  /// All entries stored for this user/app. Empty map when nothing is stored.
  /// Throws when the cloud cannot be reached and nothing is cached.
  Future<Map<String, SyncEntry>> load(String uid, String appId);

  /// Upserts [entries] (other keys are left untouched). Returns true once the
  /// server acknowledged, false when the write was queued offline and will be
  /// sent later. Throws when the write was rejected.
  Future<bool> save(String uid, String appId, Map<String, SyncEntry> entries);
}

/// What happens to this device's progress when someone logs in.
enum AccountSwitchPolicy {
  /// Device progress last synced to a *different* account is replaced by the
  /// new account's cloud progress (it is already saved under the old
  /// account). Guest progress (never synced) is always merged in.
  replaceOtherAccountsProgress,

  /// Always merge device progress into whichever account logs in.
  alwaysMerge,
}

enum SyncState {
  /// Not signed in / sync not running.
  idle,
  syncing,

  /// Last sync reached the server.
  synced,

  /// Last sync was saved on the device and will be sent when online.
  pendingOffline,

  /// Last sync failed; a retry is scheduled.
  error,
}

/// Local SharedPreferences side, including ark_core's bookkeeping key
/// (`ark_core_sync_meta`: owner uid + per-key last-seen value and time).
class LocalProgressStore {
  LocalProgressStore([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const metaKey = '${ProgressSyncSpec.reservedPrefix}sync_meta';

  Future<_Meta> _readMeta() async {
    final raw = (await _p).getString(metaKey);
    if (raw == null) return _Meta();
    try {
      return _Meta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _Meta();
    }
  }

  Future<void> _writeMeta(_Meta m) async =>
      (await _p).setString(metaKey, jsonEncode(m.toJson()));

  /// Uid this device's progress was last synced with (null = never / guest).
  Future<String?> owner() async => (await _readMeta()).owner;

  Future<void> setOwner(String? uid) async {
    final m = await _readMeta();
    m.owner = uid;
    await _writeMeta(m);
  }

  /// Snapshot of synced keys. Values that changed since the last snapshot get
  /// `updatedAt = now`, which is what last-writer-wins compares.
  Future<Map<String, SyncEntry>> snapshot(
    ProgressSyncSpec spec,
    int now,
  ) async {
    final p = await _p;
    await p.reload();
    final m = await _readMeta();
    final out = <String, SyncEntry>{};
    var dirty = false;
    for (final key in p.getKeys()) {
      if (!spec.includes(key)) continue;
      final v = normalizeValue(p.get(key));
      if (v == null) continue;
      final enc = encodeValue(v);
      var t = m.times[key];
      if (t == null || m.hashes[key] != enc) {
        t = now;
        m.times[key] = t;
        m.hashes[key] = enc;
        dirty = true;
      }
      out[key] = SyncEntry(v, t);
    }
    if (dirty) await _writeMeta(m);
    return out;
  }

  /// Writes merged values and records them as seen. With [removeOthers],
  /// synced keys that are not in [all] are removed (account switch).
  Future<void> apply(
    ProgressSyncSpec spec,
    Map<String, SyncEntry> changed,
    Map<String, SyncEntry> all, {
    bool removeOthers = false,
  }) async {
    final p = await _p;
    final m = await _readMeta();
    for (final e in changed.entries) {
      await _set(p, e.key, e.value.value);
    }
    if (removeOthers) {
      for (final key in p.getKeys().toList()) {
        if (spec.includes(key) && !all.containsKey(key)) {
          await p.remove(key);
          m.times.remove(key);
          m.hashes.remove(key);
        }
      }
    }
    for (final e in all.entries) {
      m.times[e.key] = e.value.updatedAt;
      m.hashes[e.key] = encodeValue(e.value.value);
    }
    await _writeMeta(m);
  }

  static Future<void> _set(SharedPreferences p, String key, Object v) async {
    if (v is String) {
      await p.setString(key, v);
    } else if (v is bool) {
      await p.setBool(key, v);
    } else if (v is int) {
      await p.setInt(key, v);
    } else if (v is double) {
      await p.setDouble(key, v);
    } else if (v is List<String>) {
      await p.setStringList(key, v);
    }
  }
}

class _Meta {
  _Meta();

  factory _Meta.fromJson(Map<String, dynamic> j) => _Meta()
    ..owner = j['owner'] as String?
    ..times.addAll(
      (j['t'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
    )
    ..hashes.addAll(
      (j['h'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );

  String? owner;
  final times = <String, int>{};
  final hashes = <String, String>{};

  Map<String, Object?> toJson() => {'owner': owner, 't': times, 'h': hashes};
}

/// Outcome of one [ProgressSync.syncNow].
class SyncResult {
  const SyncResult({
    required this.state,
    this.pulled = const {},
    this.pushed = const {},
    this.error,
  });

  final SyncState state;

  /// Keys whose value on this device changed (the app may want to refresh).
  final Set<String> pulled;
  final Set<String> pushed;
  final Object? error;

  bool get ok => state == SyncState.synced || state == SyncState.pendingOffline;
}

/// Keeps this app's SharedPreferences progress in step with the cloud for the
/// signed-in user. Created and driven by `ArkAuth`; apps normally only call
/// [notifyChanged] after saving progress (optional — resume also syncs).
class ProgressSync extends ChangeNotifier {
  ProgressSync({
    required this.appId,
    required this.spec,
    required this.remote,
    LocalProgressStore? local,
    this.debounce = const Duration(seconds: 3),
    this.switchPolicy = AccountSwitchPolicy.replaceOtherAccountsProgress,
    this.loadTimeout = const Duration(seconds: 15),
    int Function()? clock,
  }) : local = local ?? LocalProgressStore(),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final String appId;
  final ProgressSyncSpec spec;
  final ProgressRemote remote;
  final LocalProgressStore local;
  final Duration debounce;
  final AccountSwitchPolicy switchPolicy;
  final Duration loadTimeout;
  final int Function() _clock;

  String? _uid;
  bool _replaceOnNextSync = false;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _failures = 0;
  Future<SyncResult>? _running;
  bool _again = false;

  SyncState _state = SyncState.idle;
  SyncState get state => _state;
  DateTime? lastSyncedAt;
  Object? lastError;

  /// Called after values on this device were changed by a sync.
  void Function(Set<String> keys)? onPulled;

  String? get uid => _uid;

  /// Starts syncing for [uid] and runs the first sync.
  Future<SyncResult> start(String uid) async {
    if (_uid == uid && _state != SyncState.idle) return syncNow();
    _uid = uid;
    final owner = await local.owner();
    _replaceOnNextSync =
        switchPolicy == AccountSwitchPolicy.replaceOtherAccountsProgress &&
        owner != null &&
        owner != uid;
    return syncNow();
  }

  /// Final sync, then stops. Device progress stays on the device.
  Future<void> stop({bool flush = true}) async {
    if (flush && _uid != null) {
      try {
        await syncNow();
      } catch (_) {}
    }
    _uid = null;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _failures = 0;
    _set(SyncState.idle);
  }

  /// Schedules a debounced sync (call after saving progress).
  void notifyChanged() {
    if (_uid == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => syncNow());
  }

  /// Syncs immediately. Concurrent calls share one run (plus one follow-up).
  Future<SyncResult> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final f = _run().whenComplete(() => _running = null);
    _running = f;
    return f;
  }

  Future<SyncResult> _run() async {
    SyncResult result;
    do {
      _again = false;
      result = await _once();
    } while (_again && _uid != null);
    return result;
  }

  Future<SyncResult> _once() async {
    final uid = _uid;
    if (uid == null) return const SyncResult(state: SyncState.idle);
    _debounceTimer?.cancel();
    _set(SyncState.syncing);
    try {
      final replace = _replaceOnNextSync;
      final now = _clock();
      final cloud = await remote.load(uid, appId).timeout(loadTimeout);
      if (_uid != uid) return const SyncResult(state: SyncState.idle);
      final mine = replace
          ? const <String, SyncEntry>{}
          : await local.snapshot(spec, now);
      final plan = planMerge(spec, mine, cloud);
      await local.apply(spec, plan.toLocal, plan.merged, removeOthers: replace);
      await local.setOwner(uid);
      _replaceOnNextSync = false;
      var acked = true;
      if (plan.toRemote.isNotEmpty) {
        acked = await remote.save(uid, appId, plan.toRemote);
      }
      _failures = 0;
      _retryTimer?.cancel();
      lastError = null;
      lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(_clock());
      final state = acked ? SyncState.synced : SyncState.pendingOffline;
      if (!acked) _scheduleRetry();
      _set(state);
      final pulled = plan.toLocal.keys.toSet();
      if (pulled.isNotEmpty) onPulled?.call(pulled);
      return SyncResult(
        state: state,
        pulled: pulled,
        pushed: plan.toRemote.keys.toSet(),
      );
    } catch (e) {
      lastError = e;
      _failures++;
      _scheduleRetry();
      _set(SyncState.error);
      return SyncResult(state: SyncState.error, error: e);
    }
  }

  void _scheduleRetry() {
    if (_uid == null) return;
    _retryTimer?.cancel();
    // 30 s, 60 s, 120 s … capped at 10 min.
    final secs = math.min(600, 30 * (1 << math.min(_failures, 5)));
    _retryTimer = Timer(Duration(seconds: secs), () => syncNow());
  }

  void _set(SyncState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _uid = null;
    super.dispose();
  }
}
