// Checks a live Google Sheet against an app's bundled question packs, using
// the same requests and conversion as the apps.
//
//   dart run tool/sheets/verify_sheet.dart <app>/assets/data/content_source.json <app>/assets/data
//
// For every pack: finds its manifest row, downloads the tab, rebuilds the
// pack and compares it with the bundled JSON. "same" right after importing
// the workbook means the round trip is exact; after edits, the differences
// listed are the edits the app will pick up.
import 'dart:convert';
import 'dart:io';

import 'package:ark_core/src/content/csv.dart';
import 'package:ark_core/src/content/sheet_codec.dart';
import 'package:ark_core/src/content/sheet_source.dart';
import 'package:http/http.dart' as http;

/// Canonical form for comparing: no nulls (an empty cell means "none") and
/// sorted keys (the sheet's column order may differ from the JSON's).
dynamic _noNulls(dynamic v) {
  if (v is Map) {
    final keys = [for (final e in v.entries) if (e.value != null) '${e.key}']..sort();
    return {for (final k in keys) k: _noNulls(v[k])};
  }
  return v is List ? [for (final e in v) _noNulls(e)] : v;
}

Future<String> _get(http.Client c, Uri u) async {
  final r = await c.get(u);
  final body = utf8.decode(r.bodyBytes);
  if (r.statusCode != 200 || body.trimLeft().startsWith('<')) {
    throw 'HTTP ${r.statusCode} for $u (not shared, or tab missing)';
  }
  return body;
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: verify_sheet.dart <content_source.json> <data-dir>');
    exit(64);
  }
  final cfg = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final source = SheetSource.fromConfig(cfg);
  if (source == null) {
    stderr.writeln('No spreadsheetId / publishedId in ${args[0]}');
    exit(1);
  }
  final client = http.Client();
  var problems = 0;
  try {
    final manifest = {
      for (final r in parseCsvRecords(await _get(client, source.manifestCsv())))
        (r['pack'] ?? '').trim(): r,
    };
    final packs = Directory(args[1])
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in packs) {
      final id = f.uri.pathSegments.last.replaceAll('.json', '');
      final bundled = jsonDecode(f.readAsStringSync());
      if (bundled is! Map || itemArrays(Map<String, dynamic>.from(bundled)).isEmpty) continue;
      final template = Map<String, dynamic>.from(bundled);
      final row = manifest[id];
      if (row == null) {
        stdout.writeln('✗ $id: no row in manifest');
        problems++;
        continue;
      }
      final remote = int.tryParse((row['version'] ?? '').trim());
      final local = (template['version'] as num?)?.toInt() ?? 0;
      try {
        final rows = parseCsvRecords(
          await _get(client, source.packCsv(id, gid: (row['gid'] ?? '').trim())),
        );
        if (rows.isEmpty || !rows.first.containsKey(pathColumn)) {
          stdout.writeln('✗ $id: tab missing or has no _path column');
          problems++;
          continue;
        }
        final rebuilt = rebuildPack(template, rows)..['version'] = local;
        final count = rows.where((r) => (r[pathColumn] ?? '').trim().isNotEmpty).length;
        final same = jsonEncode(_noNulls(rebuilt)) == jsonEncode(_noNulls(template));
        final ver = remote == null
            ? 'version ✗ (not a number)'
            : remote > local
                ? 'version $remote > app $local → apps will download'
                : 'version $remote (app $local)';
        stdout.writeln('${same ? '✓' : '•'} $id: $count questions, '
            '${same ? 'same as the app' : 'DIFFERENT from the app (edited)'}, $ver');
        if (remote == null) problems++;
      } catch (e) {
        stdout.writeln('✗ $id: $e');
        problems++;
      }
    }
  } finally {
    client.close();
  }
  stdout.writeln(problems == 0 ? 'OK' : '$problems problem(s)');
  exit(problems == 0 ? 0 : 1);
}
