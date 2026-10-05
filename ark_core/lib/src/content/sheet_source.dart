/// Where question updates come from: one Google Sheet per app.
///
/// The sheet needs a `manifest` tab (columns `pack`, `version`, `gid`, and
/// optionally `minAppBuild`) and one tab per pack in the format described
/// in `sheet_codec.dart`. Raising a pack's `version` in the manifest is the
/// "update flag": apps download that tab the next time they are online.
class SheetSource {
  /// A sheet shared as "anyone with the link can view".
  /// [spreadsheetId] is the long id in the sheet's URL:
  /// `https://docs.google.com/spreadsheets/d/<spreadsheetId>/edit`.
  const SheetSource({required String spreadsheetId, this.manifestGid = '0'})
      : _id = spreadsheetId,
        _published = false;

  /// A sheet published with File → Share → Publish to web. [publishedId] is
  /// the id in the published link: `/spreadsheets/d/e/<publishedId>/pub…`.
  /// (Google caches published sheets for a few minutes.)
  const SheetSource.published({required String publishedId, this.manifestGid = '0'})
      : _id = publishedId,
        _published = true;

  /// Builds a source from the app's `content_source.json` config, or null
  /// when updates are not configured yet.
  static SheetSource? fromConfig(Map<String, dynamic> config) {
    final gid = '${config['manifestGid'] ?? '0'}';
    final published = '${config['publishedId'] ?? ''}'.trim();
    if (published.isNotEmpty) {
      return SheetSource.published(publishedId: published, manifestGid: gid);
    }
    final id = '${config['spreadsheetId'] ?? ''}'.trim();
    if (id.isNotEmpty) return SheetSource(spreadsheetId: id, manifestGid: gid);
    return null;
  }

  final String _id;
  final bool _published;

  /// Tab id of the manifest (the number after `gid=` in the tab's URL).
  final String manifestGid;

  /// CSV export of one tab.
  Uri tabCsv(String gid) => _published
      ? Uri.parse(
          'https://docs.google.com/spreadsheets/d/e/$_id/pub?gid=$gid&single=true&output=csv',
        )
      : Uri.parse(
          'https://docs.google.com/spreadsheets/d/$_id/export?format=csv&gid=$gid',
        );
}
