// Exports an app's bundled question packs to CSV files for Google Sheets.
//
//   dart run tool/sheets/export_sheets.dart <app>/assets/data <out-dir> [pack ...]
//
// Writes one `<pack>.csv` per pack (import each as its own tab, named like
// the pack) and `manifest.csv` (import as the first tab, then fill in each
// tab's gid). See doc/CONTENT_SHEETS.md.
import 'dart:convert';
import 'dart:io';

import 'package:ark_core/src/content/csv.dart';
import 'package:ark_core/src/content/sheet_codec.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: export_sheets.dart <data-dir> <out-dir> [pack ...]');
    exit(64);
  }
  final dataDir = Directory(args[0]);
  final outDir = Directory(args[1])..createSync(recursive: true);
  final only = args.skip(2).toSet();
  final manifest = <List<String>>[
    ['pack', 'version', 'gid', 'minAppBuild', 'memo'],
  ];
  final files = dataDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final id = f.uri.pathSegments.last.replaceAll('.json', '');
    if (only.isNotEmpty && !only.contains(id)) continue;
    final decoded = jsonDecode(f.readAsStringSync());
    if (decoded is! Map) continue;
    final pack = Map<String, dynamic>.from(decoded);
    final arrays = itemArrays(pack);
    if (arrays.isEmpty) continue; // not a question pack (e.g. config)
    final rows = flattenPack(pack);
    // UTF-8 with BOM so Excel also opens the Japanese text correctly.
    File('${outDir.path}/$id.csv').writeAsStringSync('﻿${toCsv(rows)}\r\n');
    final count = rows.length - 1;
    manifest.add([id, '${pack['version'] ?? 1}', '', '', '$count 問']);
    stdout.writeln('$id: $count rows, ${rows.first.length} columns, paths: ${arrays.keys.join(', ')}');
  }
  File('${outDir.path}/manifest.csv').writeAsStringSync('﻿${toCsv(manifest)}\r\n');
  stdout.writeln('manifest.csv: ${manifest.length - 1} packs');
}
