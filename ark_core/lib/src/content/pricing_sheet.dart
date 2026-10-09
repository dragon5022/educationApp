/// The sheet's `pricing` tab: which content is free, per app, editable by
/// the school without an app update.
///
/// | app  | item                 | value | メモ            |
/// |------|----------------------|-------|-----------------|
/// | kids | enabled              | true  | 課金を有効にする |
/// | kids | defaultFreeCount     | 1     | 各級の無料モード数 |
/// | kids | freeCounts.vocab     | 2     |                 |
/// | kids | freeCounts.listening/g5 | 2  | 5級だけ         |
/// | kids | freePacks            | talk  | 全部無料のゲーム（カンマ区切り） |
/// | teen | lockedPacks          | k-kanji,k-koten |      |
///
/// Rows for other apps are ignored. The result is the JSON shape
/// `ContentAccessRules.fromJson` reads, plus `enabled`.
library;

/// Rows (`app`, `item`, `value`) → settings for [appId], or null when the
/// tab has no rows for this app.
Map<String, dynamic>? pricingFromRows(
  List<Map<String, String>> rows,
  String appId,
) {
  final counts = <String, int>{};
  final out = <String, dynamic>{};
  var any = false;
  for (final r in rows) {
    if ((r['app'] ?? '').trim().toLowerCase() != appId.toLowerCase()) continue;
    final item = (r['item'] ?? '').trim();
    final value = (r['value'] ?? '').trim();
    if (item.isEmpty || value.isEmpty) continue;
    any = true;
    if (item == 'enabled') {
      out['enabled'] = _bool(value);
    } else if (item == 'defaultFreeCount') {
      final n = int.tryParse(value);
      if (n != null) out['defaultFreeCount'] = n;
    } else if (item.startsWith('freeCounts.')) {
      final n = int.tryParse(value);
      if (n != null) counts[item.substring('freeCounts.'.length)] = n;
    } else if (item == 'freePacks' || item == 'lockedPacks') {
      out[item] = [
        for (final p in value.split(RegExp(r'[,、\s]+')))
          if (p.isNotEmpty) p,
      ];
    }
  }
  if (!any) return null;
  if (counts.isNotEmpty) out['freeCounts'] = counts;
  return out;
}

bool _bool(String v) {
  final s = v.toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'on' || s == '○';
}
