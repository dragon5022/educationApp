import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'csv.dart';
import 'sheet_codec.dart';
import 'sheet_source.dart';

/// Checks a pack's JSON before it is used (e.g. parse it with the game's
/// model and make sure there are enough questions).
typedef PackValidator = bool Function(String json);

/// Question packs that can be updated from a Google Sheet without
/// reinstalling the app.
///
/// ```dart
/// await ArkContent.instance.configure(
///   appId: 'kids',
///   bundledPacks: {'vocab': 'assets/data/vocab.json', …},
///   source: SheetSource(spreadsheetId: '…'),
///   validators: {'vocab': (j) => VocabPack.fromJsonString(j).items.length >= 10},
/// );
/// final json = await ArkContent.instance.loadPack('vocab');
/// unawaited(ArkContent.instance.checkForUpdates()); // when convenient
/// ```
///
/// - Always works offline: [loadPack] returns the last downloaded copy that
///   passed validation, otherwise the JSON bundled in the app.
/// - [checkForUpdates] reads the sheet's `manifest` tab; for every pack
///   whose `version` is higher than the local one it downloads that tab,
///   rebuilds the pack (bundled settings + sheet questions), validates it
///   and stores it. Anything that fails keeps the current questions.
/// - New questions take effect the next time a game loads its pack;
///   listen to [revision] to reload earlier.
class ArkContent {
  ArkContent._();
  static final ArkContent instance = ArkContent._();

  String _appId = 'app';
  Map<String, String> _bundled = const {};
  Map<String, PackValidator> _validators = const {};
  SheetSource? _source;
  int _appBuild = 0;
  http.Client? _client;
  Future<String> Function(String asset) _loadAsset = rootBundle.loadString;
  final Map<String, Map<String, dynamic>> _templates = {};

  /// Bumps whenever [checkForUpdates] installs a newer pack.
  final ValueNotifier<int> revision = ValueNotifier(0);

  String get appId => _appId;
  Iterable<String> get packIds => _bundled.keys;

  /// Whether a sheet is configured (updates possible).
  bool get canUpdate => _source != null;

  Future<void> configure({
    required String appId,
    required Map<String, String> bundledPacks,
    SheetSource? source,
    Map<String, PackValidator> validators = const {},
    int appBuild = 0,
    @visibleForTesting http.Client? client,
    @visibleForTesting Future<String> Function(String asset)? assetLoader,
  }) async {
    _appId = appId;
    _bundled = Map.unmodifiable(bundledPacks);
    _validators = Map.unmodifiable(validators);
    _source = source;
    _appBuild = appBuild;
    _client = client;
    _loadAsset = assetLoader ?? rootBundle.loadString;
    _templates.clear();
    _lastCheck = null;
  }

  /// Reads `content_source.json`-style config from an asset (missing or
  /// empty ids → updates disabled).
  static Future<SheetSource?> sourceFromAsset(String asset) async {
    try {
      final cfg = jsonDecode(await rootBundle.loadString(asset));
      return SheetSource.fromConfig(Map<String, dynamic>.from(cfg as Map));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ loading

  /// JSON text of [packId]: the downloaded copy if valid, else bundled.
  Future<String> loadPack(String packId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(packId, 'json'));
    if (stored != null && _isValid(packId, stored)) return stored;
    return _bundledJson(packId);
  }

  /// Version of the questions currently used for [packId].
  Future<int> localVersion(String packId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_key(packId, 'version'));
    if (v != null && prefs.getString(_key(packId, 'json')) != null) return v;
    final t = await _template(packId);
    return (t['version'] as num?)?.toInt() ?? 0;
  }

  /// Forgets downloaded questions (all packs, or one).
  Future<void> resetToBundled([String? packId]) async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in packId == null ? _bundled.keys : [packId]) {
      await prefs.remove(_key(id, 'json'));
      await prefs.remove(_key(id, 'version'));
    }
    revision.value++;
  }

  // ------------------------------------------------------------ updates

  DateTime? _lastCheck;
  Future<ContentUpdateReport>? _running;

  /// Downloads newer packs from the sheet. Without [force], checks at most
  /// every 30 minutes. Never throws; see the returned report.
  Future<ContentUpdateReport> checkForUpdates({bool force = false}) {
    if (_running != null) return _running!;
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 30)) {
      return Future.value(ContentUpdateReport._skipped());
    }
    _running = _check().whenComplete(() {
      _running = null;
      _lastCheck = DateTime.now();
    });
    return _running!;
  }

  Future<ContentUpdateReport> _check() async {
    final report = ContentUpdateReport._();
    final source = _source;
    if (source == null) {
      report.notConfigured = true;
      return report;
    }
    final client = _client ?? http.Client();
    try {
      final manifest = parseCsvRecords(await _get(client, source.tabCsv(source.manifestGid)));
      final prefs = await SharedPreferences.getInstance();
      for (final row in manifest) {
        final id = (row['pack'] ?? '').trim();
        if (!_bundled.containsKey(id)) continue;
        final remote = int.tryParse((row['version'] ?? '').trim());
        final gid = (row['gid'] ?? '').trim();
        if (remote == null || gid.isEmpty) {
          report.failed[id] = 'manifest の version / gid が正しくありません';
          continue;
        }
        final minBuild = int.tryParse((row['minAppBuild'] ?? '').trim()) ?? 0;
        if (minBuild > _appBuild) {
          report.needsAppUpdate.add(id);
          continue;
        }
        if (remote <= await localVersion(id)) {
          report.upToDate.add(id);
          continue;
        }
        try {
          final rows = parseCsvRecords(await _get(client, source.tabCsv(gid)));
          final pack = rebuildPack(await _template(id), rows)..['version'] = remote;
          final json = jsonEncode(pack);
          final problem = _problem(id, pack, json);
          if (problem != null) {
            report.failed[id] = problem;
            continue;
          }
          await prefs.setString(_key(id, 'json'), json);
          await prefs.setInt(_key(id, 'version'), remote);
          report.updated.add(id);
        } catch (e) {
          report.failed[id] = '$e';
        }
      }
    } on _HttpFailure catch (e) {
      report.failed['manifest'] = e.message;
    } catch (e) {
      // DNS / socket / timeout: treat as offline, keep current questions.
      debugPrint('content update: offline ($e)');
      report.offline = true;
    } finally {
      if (_client == null) client.close();
    }
    if (report.updated.isNotEmpty) revision.value++;
    return report;
  }

  Future<String> _get(http.Client client, Uri uri) async {
    final res = await client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw _HttpFailure('HTTP ${res.statusCode}（シートの共有設定を確認してください）');
    }
    final body = utf8.decode(res.bodyBytes);
    if (body.trimLeft().startsWith('<')) {
      // Google answers with a login page when the sheet isn't shared.
      throw const _HttpFailure('シートが「リンクを知っている全員」に共有されていません');
    }
    return body;
  }

  /// Why [pack] can't be used, or null if it is fine.
  String? _problem(String id, Map<String, dynamic> pack, String json) {
    final template = _templates[id]!;
    for (final path in itemArrays(template).keys) {
      final items = itemArrays(pack)[path];
      if (items == null || items.isEmpty) return '$path の問題が 0 件です';
    }
    if (!_isValid(id, json)) return 'アプリで読み込めないデータです（列名や値を確認してください）';
    return null;
  }

  bool _isValid(String id, String json) {
    final v = _validators[id];
    if (v == null) return true;
    try {
      return v(json);
    } catch (e) {
      debugPrint('content validator $id: $e');
      return false;
    }
  }

  Future<String> _bundledJson(String packId) {
    final asset = _bundled[packId];
    if (asset == null) {
      throw ArgumentError('Unknown pack "$packId" for app "$_appId"');
    }
    return _loadAsset(asset);
  }

  Future<Map<String, dynamic>> _template(String packId) async =>
      _templates[packId] ??=
          Map<String, dynamic>.from(jsonDecode(await _bundledJson(packId)) as Map);

  String _key(String packId, String field) => 'ark_content.$_appId.$packId.$field';
}

class _HttpFailure implements Exception {
  const _HttpFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Result of [ArkContent.checkForUpdates].
class ContentUpdateReport {
  ContentUpdateReport._();
  ContentUpdateReport._skipped() : skipped = true;

  final List<String> updated = [];
  final List<String> upToDate = [];
  final List<String> needsAppUpdate = [];
  final Map<String, String> failed = {};
  bool offline = false;
  bool notConfigured = false;
  bool skipped = false;

  /// One-line Japanese summary for a settings screen.
  String get messageJa {
    if (notConfigured) return 'もんだいの こうしんは まだ せってい されていません';
    if (offline) return 'インターネットに つながると こうしん できます';
    if (failed.isNotEmpty) return 'こうしん できなかった もんだいが あります';
    if (updated.isNotEmpty) return 'あたらしい もんだいに こうしんしたよ！';
    return 'もんだいは さいしんだよ';
  }
}
