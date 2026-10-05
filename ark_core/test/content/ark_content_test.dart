import 'dart:convert';
import 'dart:io';

import 'package:ark_core/content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _asset = 'assets/data/talk.json';
final _bundled = File('test/content/fixtures/talk.json').readAsStringSync();
final _pack = jsonDecode(_bundled) as Map<String, dynamic>;

/// A fake Google Sheet: manifest tab gid 0, talk tab gid 123.
class _Sheet {
  int version = 2;
  List<List<String>> talkRows = flattenPack(_pack);
  int talkFetches = 0;
  String? manifestOverride;

  MockClient client() => MockClient((req) async {
        final gid = req.url.queryParameters['gid'];
        if (gid == '0') {
          return http.Response.bytes(
            utf8.encode(manifestOverride ??
                'pack,version,gid\r\ntalk,$version,123\r\nunknown,9,456'),
            200,
          );
        }
        if (gid == '123') {
          talkFetches++;
          return http.Response.bytes(utf8.encode(toCsv(talkRows)), 200);
        }
        return http.Response('nope', 404);
      });
}

Future<void> _configure(_Sheet sheet, {int build = 1, http.Client? client}) =>
    ArkContent.instance.configure(
      appId: 'test',
      bundledPacks: {'talk': _asset},
      source: const SheetSource(spreadsheetId: 'ID'),
      validators: {
        'talk': (j) => ((jsonDecode(j) as Map)['grades']['g5'] as List).length >= 3,
      },
      appBuild: build,
      client: client ?? sheet.client(),
      assetLoader: (a) async => a == _asset ? _bundled : throw ArgumentError(a),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('without a sheet: bundled questions, report says not configured', () async {
    await ArkContent.instance.configure(
      appId: 'test',
      bundledPacks: {'talk': _asset},
      assetLoader: (_) async => _bundled,
    );
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.notConfigured, isTrue);
    expect(await ArkContent.instance.loadPack('talk'), _bundled);
  });

  test('higher version downloads, stores and is used offline later', () async {
    final sheet = _Sheet();
    sheet.talkRows[1][sheet.talkRows[0].indexOf('ja')] = 'こんにちは（更新）';
    await _configure(sheet);
    final before = ArkContent.instance.revision.value;
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.updated, ['talk']);
    expect(ArkContent.instance.revision.value, before + 1);
    final json = jsonDecode(await ArkContent.instance.loadPack('talk')) as Map;
    expect(json['version'], 2);
    expect((json['grades']['g5'] as List).first['ja'], 'こんにちは（更新）');
    expect(await ArkContent.instance.localVersion('talk'), 2);

    // Offline afterwards: still the downloaded questions.
    await _configure(sheet, client: MockClient((_) => throw const SocketException('offline')));
    final off = await ArkContent.instance.checkForUpdates(force: true);
    expect(off.offline, isTrue);
    expect(jsonDecode(await ArkContent.instance.loadPack('talk'))['version'], 2);
  });

  test('same version: nothing downloaded', () async {
    final sheet = _Sheet()..version = (_pack['version'] as num).toInt();
    await _configure(sheet);
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.upToDate, ['talk']);
    expect(sheet.talkFetches, 0);
  });

  test('invalid data is rejected and bundled questions stay', () async {
    final sheet = _Sheet();
    // Keep only one g5 row → validator needs ≥ 3.
    final header = sheet.talkRows.first;
    final g5 = sheet.talkRows.skip(1).where((r) => r[0] == 'grades.g5').take(1);
    sheet.talkRows = [header, ...g5];
    await _configure(sheet);
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.failed.keys, ['talk']);
    expect(await ArkContent.instance.loadPack('talk'), _bundled);
  });

  test('sheet not shared (login page) is reported', () async {
    final sheet = _Sheet()..manifestOverride = '<!DOCTYPE html><html>login</html>';
    await _configure(sheet);
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.failed.containsKey('manifest'), isTrue);
    expect(r.offline, isFalse);
  });

  test('minAppBuild newer than the app: skipped', () async {
    final sheet = _Sheet()..manifestOverride = 'pack,version,gid,minAppBuild\ntalk,5,123,99';
    await _configure(sheet, build: 3);
    final r = await ArkContent.instance.checkForUpdates(force: true);
    expect(r.needsAppUpdate, ['talk']);
    expect(sheet.talkFetches, 0);
  });

  test('without force, checks are throttled', () async {
    final sheet = _Sheet();
    await _configure(sheet);
    await ArkContent.instance.checkForUpdates();
    final again = await ArkContent.instance.checkForUpdates();
    expect(again.skipped, isTrue);
  });
}
