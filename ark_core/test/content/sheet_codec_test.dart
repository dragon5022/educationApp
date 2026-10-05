import 'dart:convert';
import 'dart:io';

import 'package:ark_core/src/content/csv.dart';
import 'package:ark_core/src/content/sheet_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String name) => jsonDecode(
      File('test/content/fixtures/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// An empty cell means "no value": `null` fields come back absent, which
/// the pack parsers treat the same (`j['img'] as String?`).
dynamic _withoutNulls(dynamic v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (e.value != null) e.key: _withoutNulls(e.value),
    };
  }
  if (v is List) return [for (final e in v) _withoutNulls(e)];
  return v;
}

/// What Google Sheets returns: the flattened tab as CSV text.
List<Map<String, String>> _viaCsv(List<List<String>> rows) =>
    parseCsvRecords(toCsv(rows));

void main() {
  group('round trip pack → sheet CSV → pack', () {
    for (final name in ['vocab', 'listening', 'talk', 'sentence']) {
      test(name, () {
        final pack = _fixture(name);
        final rebuilt = rebuildPack(pack, _viaCsv(flattenPack(pack)));
        expect(rebuilt, equals(_withoutNulls(pack)));
      });
    }
  });

  test('edited cells become the template types; new rows are added', () {
    final pack = _fixture('vocab');
    final rows = _viaCsv(flattenPack(pack));
    rows[0]['ja'] = 'カフェ'; // fix a meaning
    rows.add({
      pathColumn: 'items',
      'id': '999',
      'w': 'apple',
      'ja': 'りんご',
      'lv': '5',
    });
    final items = rebuildPack(pack, rows)['items'] as List;
    expect(items.first['ja'], 'カフェ');
    expect(items.last, {'id': 999, 'w': 'apple', 'ja': 'りんご', 'lv': 5});
    expect(items.length, (pack['items'] as List).length + 1);
  });

  test('variable-length parts and blank rows', () {
    final pack = _fixture('sentence');
    final rows = _viaCsv(flattenPack(pack));
    // Blank out the last two parts of the first g4 item (5 → 3 parts).
    final g4 = rows.firstWhere((r) => r[pathColumn] == 'grades.g4');
    for (final k in g4.keys.toList()) {
      if (RegExp(r'^(ja|answer)\.[34](\.|$)').hasMatch(k)) g4[k] = '';
    }
    rows.insert(0, {pathColumn: '', 'id': 'メモ: この行は無視'});
    final out = rebuildPack(pack, rows);
    final first = (out['grades']['g4'] as List).first as Map;
    expect((first['answer'] as List).length, 3);
    expect((out['grades']['g5'] as List).length, (pack['grades']['g5'] as List).length);
  });

  test('tabs without rows for a path keep the bundled questions', () {
    final pack = _fixture('talk');
    final rows = _viaCsv(flattenPack(pack))
        .where((r) => r[pathColumn] == 'grades.g5')
        .toList();
    final out = rebuildPack(pack, rows);
    expect(out['grades']['g4'], pack['grades']['g4']);
  });

  test('csv handles quotes, commas and line breaks', () {
    const text = '﻿a,b\r\n"x, ""y""","line1\nline2"\r\n';
    expect(parseCsv(text), [
      ['a', 'b'],
      ['x, "y"', 'line1\nline2'],
    ]);
  });
}
