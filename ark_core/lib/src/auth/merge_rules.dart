import 'dart:convert';

/// One synced value plus the time (ms since epoch, client clock) it was last
/// changed. `value` is what SharedPreferences holds: String, int, double, bool
/// or `List<String>`.
class SyncEntry {
  const SyncEntry(this.value, this.updatedAt);

  final Object value;
  final int updatedAt;

  Map<String, Object> toMap() => {'v': value, 't': updatedAt};

  /// Parses `{v, t}` as stored in Firestore. Returns null when malformed.
  static SyncEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final v = normalizeValue(raw['v']);
    if (v == null) return null;
    final t = raw['t'];
    return SyncEntry(v, t is num ? t.toInt() : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is SyncEntry &&
      other.updatedAt == updatedAt &&
      valuesEqual(other.value, value);

  @override
  int get hashCode => Object.hash(encodeValue(value), updatedAt);

  @override
  String toString() => 'SyncEntry(${encodeValue(value)} @ $updatedAt)';
}

/// Converts a value coming from Firestore/JSON into a SharedPreferences-able
/// value (String, int, double, bool, `List<String>`). Returns null if the
/// value cannot be stored.
Object? normalizeValue(Object? v) {
  if (v is String || v is int || v is bool || v is double) return v;
  if (v is List) {
    if (v.every((e) => e is String)) return List<String>.from(v);
    return null;
  }
  return null;
}

/// Stable string form of a value, used to detect local changes.
String encodeValue(Object? v) => jsonEncode(v);

bool valuesEqual(Object? a, Object? b) => encodeValue(a) == encodeValue(b);

/// How two copies of the same key (this device vs. cloud) are combined.
///
/// Every rule is deterministic and never shrinks progress for the types it
/// understands; unknown shapes fall back to last-writer-wins.
abstract class MergeRule {
  const MergeRule();

  /// Keep the larger number (best scores, S-rank counters, level unlocks).
  /// Accepts ints, doubles and numeric strings such as `'120'` (KIDS stores
  /// `lb2_*` / `eb2_*` as strings). Non-numeric values → last writer wins.
  static const MergeRule max = _MaxRule();

  /// Union of JSON arrays (`'["vocamon","lismon"]'`, `'[1,5,9]'`) or
  /// `List<String>` values: the cloud's order first, then items only this
  /// device has (so devices converge without rewriting each other).
  /// Non-array values → last writer wins.
  static const MergeRule union = _UnionRule();

  /// The copy with the newest `updatedAt` wins (names, settings). Ties keep
  /// this device's value.
  static const MergeRule lastWriteWins = _LwwRule();

  /// Default when a key has no explicit rule: arrays → [union], numbers →
  /// [max], anything else → [lastWriteWins].
  static const MergeRule auto = _AutoRule();

  /// Your own rule. Return the merged value; its timestamp becomes the newer
  /// of the two inputs.
  const factory MergeRule.custom(
    Object Function(SyncEntry local, SyncEntry remote) merge,
  ) = _CustomRule;

  /// Merges two present copies. The result's type follows [local] whenever
  /// possible so the app keeps reading it with the same getter.
  SyncEntry merge(SyncEntry local, SyncEntry remote);
}

int _newer(SyncEntry a, SyncEntry b) =>
    a.updatedAt >= b.updatedAt ? a.updatedAt : b.updatedAt;

num? _asNum(Object v) {
  if (v is num) return v;
  if (v is bool) return null;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

/// Coerces [value] to the runtime type of [like] where that is lossless
/// (e.g. remote int 120 → local String '120').
Object coerceLike(Object like, Object value) {
  if (like.runtimeType == value.runtimeType) return value;
  if (like is String) {
    if (value is num || value is bool) return '$value';
    if (value is List<String>) return jsonEncode(value);
  }
  if (like is int) {
    final n = _asNum(value);
    if (n != null && n == n.roundToDouble()) return n.toInt();
  }
  if (like is double) {
    final n = _asNum(value);
    if (n != null) return n.toDouble();
  }
  if (like is List<String>) {
    final l = _asList(value);
    if (l != null) return l.map((e) => '$e').toList();
  }
  return value;
}

List<Object?>? _asList(Object v) {
  if (v is List) return v;
  if (v is String) {
    final s = v.trim();
    if (!s.startsWith('[')) return null;
    try {
      final d = jsonDecode(s);
      return d is List ? d : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

class _LwwRule extends MergeRule {
  const _LwwRule();

  @override
  SyncEntry merge(SyncEntry local, SyncEntry remote) {
    if (remote.updatedAt > local.updatedAt) {
      return SyncEntry(coerceLike(local.value, remote.value), remote.updatedAt);
    }
    return local;
  }
}

class _MaxRule extends MergeRule {
  const _MaxRule();

  @override
  SyncEntry merge(SyncEntry local, SyncEntry remote) {
    final a = _asNum(local.value);
    final b = _asNum(remote.value);
    if (a == null || b == null) {
      return MergeRule.lastWriteWins.merge(local, remote);
    }
    final winner = b > a ? remote.value : local.value;
    return SyncEntry(coerceLike(local.value, winner), _newer(local, remote));
  }
}

class _UnionRule extends MergeRule {
  const _UnionRule();

  @override
  SyncEntry merge(SyncEntry local, SyncEntry remote) {
    final a = _asList(local.value);
    final b = _asList(remote.value);
    if (a == null || b == null) {
      return MergeRule.lastWriteWins.merge(local, remote);
    }
    final seen = <String>{};
    final out = <Object?>[];
    for (final e in [...b, ...a]) {
      if (seen.add(jsonEncode(e))) out.add(e);
    }
    final Object value = local.value is List<String>
        ? out.map((e) => '$e').toList()
        : jsonEncode(out);
    return SyncEntry(value, _newer(local, remote));
  }
}

class _AutoRule extends MergeRule {
  const _AutoRule();

  @override
  SyncEntry merge(SyncEntry local, SyncEntry remote) {
    if (_asList(local.value) != null && _asList(remote.value) != null) {
      return MergeRule.union.merge(local, remote);
    }
    if (_asNum(local.value) != null && _asNum(remote.value) != null) {
      return MergeRule.max.merge(local, remote);
    }
    return MergeRule.lastWriteWins.merge(local, remote);
  }
}

class _CustomRule extends MergeRule {
  const _CustomRule(this._fn);

  final Object Function(SyncEntry local, SyncEntry remote) _fn;

  @override
  SyncEntry merge(SyncEntry local, SyncEntry remote) {
    final v = normalizeValue(_fn(local, remote)) ?? local.value;
    return SyncEntry(v, _newer(local, remote));
  }
}

/// Which SharedPreferences keys to sync and how to merge each.
///
/// ```dart
/// ProgressSyncSpec([
///   SyncKey('ark_name', MergeRule.lastWriteWins),
///   SyncKey('ark_friends', MergeRule.union),
///   SyncKey.prefix('ark_cards_', MergeRule.union),
///   SyncKey.prefix('ark_best_', MergeRule.max),
///   SyncKey.prefix('lb2_'), // MergeRule.auto
/// ])
/// ```
class ProgressSyncSpec {
  const ProgressSyncSpec(this.keys);

  final List<SyncKey> keys;

  /// The rule for [key], or null when the key is not synced. Exact keys win
  /// over prefixes; the longest matching prefix wins among prefixes.
  MergeRule? ruleFor(String key) {
    if (key.startsWith(reservedPrefix)) return null;
    SyncKey? best;
    for (final k in keys) {
      if (!k.isPrefix) {
        if (k.key == key) return k.rule;
      } else if (key.startsWith(k.key) &&
          (best == null || k.key.length > best.key.length)) {
        best = k;
      }
    }
    return best?.rule;
  }

  bool includes(String key) => ruleFor(key) != null;

  /// Keys starting with this are ark_core's own bookkeeping, never synced.
  static const reservedPrefix = 'ark_core_';
}

/// A synced key (exact name) or key family (prefix).
class SyncKey {
  const SyncKey(this.key, [this.rule = MergeRule.auto]) : isPrefix = false;
  const SyncKey.prefix(this.key, [this.rule = MergeRule.auto])
    : isPrefix = true;

  final String key;
  final bool isPrefix;
  final MergeRule rule;
}

/// Result of merging this device with the cloud.
class MergePlan {
  MergePlan({
    required this.merged,
    required this.toLocal,
    required this.toRemote,
  });

  /// Final state of every synced key.
  final Map<String, SyncEntry> merged;

  /// Keys whose local value must be (over)written.
  final Map<String, SyncEntry> toLocal;

  /// Keys whose cloud copy must be (over)written.
  final Map<String, SyncEntry> toRemote;
}

/// Pure merge of [local] and [remote] snapshots under [spec]. Keys missing on
/// one side are copied from the other — a missing key never deletes data.
MergePlan planMerge(
  ProgressSyncSpec spec,
  Map<String, SyncEntry> local,
  Map<String, SyncEntry> remote,
) {
  final merged = <String, SyncEntry>{};
  final toLocal = <String, SyncEntry>{};
  final toRemote = <String, SyncEntry>{};
  final keys = {...local.keys, ...remote.keys};
  for (final key in keys) {
    final rule = spec.ruleFor(key);
    if (rule == null) continue;
    final l = local[key];
    final r = remote[key];
    final SyncEntry m;
    if (l == null) {
      m = r!;
    } else if (r == null) {
      m = l;
    } else {
      m = rule.merge(l, r);
    }
    merged[key] = m;
    if (l == null || !valuesEqual(l.value, m.value)) toLocal[key] = m;
    // Only value changes are pushed; a newer timestamp alone is not worth a
    // write (avoids ping-pong between devices).
    if (r == null || !valuesEqual(r.value, m.value)) toRemote[key] = m;
  }
  return MergePlan(merged: merged, toLocal: toLocal, toRemote: toRemote);
}
