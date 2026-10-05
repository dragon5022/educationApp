import 'package:flutter/foundation.dart';

import 'purchase_service.dart';

/// Which content is free (trial) without the purchase. Per app.
///
/// Precedence for one item:
/// 1. an explicit `free: true/false` flag on the item ([isFree] `itemFree`),
/// 2. [custom] predicate (if it returns non-null),
/// 3. pack in [freePacks] → free; pack in [lockedPacks] → locked,
/// 4. `itemIndex < count` where count comes from [freeCounts] using the key
///    `'$packId/$group'`, then `'$packId'`, else [defaultFreeCount].
///
/// `itemIndex` is 0-based within the pack, or within the group (level /
/// grade / stage) when a group is given.
@immutable
class ContentAccessRules {
  const ContentAccessRules({
    this.defaultFreeCount = 0,
    this.freeCounts = const {},
    this.freePacks = const {},
    this.lockedPacks = const {},
    this.custom,
  });

  /// e.g. `{'vocab': 3, 'listening/g3': 2}`.
  final Map<String, int> freeCounts;
  final int defaultFreeCount;
  final Set<String> freePacks;
  final Set<String> lockedPacks;
  final bool? Function(String packId, String? group, int itemIndex)? custom;

  /// Everything free (e.g. a juku-only build or a review build).
  static const allFree = ContentAccessRules(defaultFreeCount: 1 << 30);

  /// From remote/JSON config:
  /// `{"defaultFreeCount":2,"freeCounts":{"vocab":3},"freePacks":["talk"]}`.
  factory ContentAccessRules.fromJson(Map<String, dynamic> json) {
    Set<String> set(Object? v) =>
        v is List ? {for (final e in v) '$e'} : const <String>{};
    final counts = <String, int>{};
    final raw = json['freeCounts'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = v is num ? v.toInt() : int.tryParse('$v');
        if (n != null) counts['$k'] = n;
      });
    }
    final d = json['defaultFreeCount'];
    return ContentAccessRules(
      defaultFreeCount: d is num ? d.toInt() : 0,
      freeCounts: counts,
      freePacks: set(json['freePacks']),
      lockedPacks: set(json['lockedPacks']),
    );
  }

  bool isFree(String packId, int itemIndex, {String? group, bool? itemFree}) {
    if (itemFree != null) return itemFree;
    final c = custom?.call(packId, group, itemIndex);
    if (c != null) return c;
    if (freePacks.contains(packId)) return true;
    if (lockedPacks.contains(packId)) return false;
    final count =
        (group == null ? null : freeCounts['$packId/$group']) ??
        freeCounts[packId] ??
        defaultFreeCount;
    return itemIndex < count;
  }
}

/// Combines the free rules with the purchase state. Listen to it (it is a
/// [Listenable]) to rebuild menus when the unlock changes.
class ContentAccess extends ChangeNotifier {
  ContentAccess({required this.rules, ValueListenable<bool>? unlocked})
    : _unlocked = unlocked ?? PurchaseService.instance.isUnlocked {
    _unlocked.addListener(notifyListeners);
  }

  ContentAccessRules rules;
  final ValueListenable<bool> _unlocked;

  bool get isUnlocked => _unlocked.value;

  /// Free regardless of purchase.
  bool isFree(String packId, int itemIndex, {String? group, bool? itemFree}) =>
      rules.isFree(packId, itemIndex, group: group, itemFree: itemFree);

  /// Free or purchased.
  bool canAccess(
    String packId,
    int itemIndex, {
    String? group,
    bool? itemFree,
  }) =>
      isUnlocked || isFree(packId, itemIndex, group: group, itemFree: itemFree);

  bool isLocked(
    String packId,
    int itemIndex, {
    String? group,
    bool? itemFree,
  }) => !canAccess(packId, itemIndex, group: group, itemFree: itemFree);

  /// Reads an item's `free` field from pack JSON (`true`, `"1"`, `"TRUE"`…).
  static bool? itemFreeFlag(Map<String, dynamic> item) {
    final v = item['free'];
    if (v == null) return null;
    if (v is bool) return v;
    final s = '$v'.trim().toLowerCase();
    if (s.isEmpty) return null;
    return s == 'true' || s == '1' || s == 'yes' || s == '○' || s == 'free';
  }

  void updateRules(ContentAccessRules r) {
    rules = r;
    notifyListeners();
  }

  @override
  void dispose() {
    _unlocked.removeListener(notifyListeners);
    super.dispose();
  }
}
