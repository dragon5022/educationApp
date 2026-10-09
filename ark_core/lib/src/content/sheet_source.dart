/// Where question updates come from: one Google Sheet (it may serve several
/// apps — each app only reads the packs it knows).
///
/// The sheet needs a `manifest` tab (columns `pack`, `version`, optional
/// `gid`, `minAppBuild`) and one tab per pack, named like the pack, in the
/// format described in `sheet_codec.dart`. Raising a pack's `version` in the
/// manifest is the "update flag": apps download that tab the next time they
/// are online.
///
/// Tabs are located by, in order: the manifest row's `gid`, the [tabGids]
/// map from the app config, then the tab **name** (fallback that keeps
/// working if a tab is recreated).
class SheetSource {
  /// A sheet shared as "anyone with the link can view".
  /// [spreadsheetId] is the long id in the sheet's URL:
  /// `https://docs.google.com/spreadsheets/d/<spreadsheetId>/edit`.
  const SheetSource({
    required String spreadsheetId,
    this.manifestGid = '',
    this.tabGids = const {},
  })  : _id = spreadsheetId,
        _published = false;

  /// A sheet published with File → Share → Publish to web. [publishedId] is
  /// the id in the published link: `/spreadsheets/d/e/<publishedId>/pub…`.
  /// (Google caches published sheets for a few minutes; name lookup is not
  /// available, so gids are required.)
  const SheetSource.published({
    required String publishedId,
    this.manifestGid = '0',
    this.tabGids = const {},
  })  : _id = publishedId,
        _published = true;

  /// Builds a source from the app's `content_source.json` config, or null
  /// when updates are not configured yet.
  static SheetSource? fromConfig(Map<String, dynamic> config) {
    final gid = '${config['manifestGid'] ?? ''}'.trim();
    final tabs = <String, String>{
      for (final e in (config['tabs'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value}'.trim(),
    }..removeWhere((_, v) => v.isEmpty);
    final published = '${config['publishedId'] ?? ''}'.trim();
    if (published.isNotEmpty) {
      return SheetSource.published(
        publishedId: published,
        manifestGid: gid.isEmpty ? '0' : gid,
        tabGids: tabs,
      );
    }
    final id = '${config['spreadsheetId'] ?? ''}'.trim();
    if (id.isNotEmpty) {
      return SheetSource(spreadsheetId: id, manifestGid: gid, tabGids: tabs);
    }
    return null;
  }

  final String _id;
  final bool _published;

  /// Tab id of the manifest ('' → find the tab named `manifest`).
  final String manifestGid;

  /// Pack id → tab id, captured when the sheet was set up.
  final Map<String, String> tabGids;

  static const manifestTab = 'manifest';

  /// Free/paid settings per app (see `pricing_sheet.dart`).
  static const pricingTab = 'pricing';

  /// CSV of the manifest tab.
  Uri manifestCsv() => manifestGid.isNotEmpty || _published
      ? tabCsv(manifestGid.isEmpty ? '0' : manifestGid)
      : tabCsvByName(manifestTab);

  /// CSV of a pack's tab: [gid] (from the manifest) → [tabGids] → name.
  Uri packCsv(String packId, {String? gid}) {
    final g = (gid != null && gid.isNotEmpty) ? gid : tabGids[packId];
    if (g != null && g.isNotEmpty) return tabCsv(g);
    return tabCsvByName(packId);
  }

  /// CSV export of one tab by id (exact cell text).
  Uri tabCsv(String gid) => _published
      ? Uri.parse(
          'https://docs.google.com/spreadsheets/d/e/$_id/pub?gid=$gid&single=true&output=csv',
        )
      : Uri.parse(
          'https://docs.google.com/spreadsheets/d/$_id/export?format=csv&gid=$gid',
        );

  /// CSV of one tab by name (Visualization API). `headers=1` keeps exactly
  /// one header row; the question tabs are plain-text formatted so values
  /// come back verbatim.
  Uri tabCsvByName(String name) => Uri.https(
        'docs.google.com',
        '/spreadsheets/d/$_id/gviz/tq',
        {'tqx': 'out:csv', 'headers': '1', 'sheet': name},
      );
}
