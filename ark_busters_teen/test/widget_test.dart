import 'dart:convert';
import 'dart:io';

import 'package:ark_busters_teen/data/stage_pack.dart';
import 'package:ark_busters_teen/screens/stage/result_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 21 packs parse and every answer is among its choices', () {
    var total = 0;
    for (final id in stagePackIds) {
      final j = jsonDecode(File('assets/data/$id.json').readAsStringSync());
      final pack = StagePack.fromJson(j as Map<String, dynamic>);
      expect(pack.levels, isNotEmpty, reason: id);
      for (final list in pack.levels.values) {
        for (final p in list) {
          expect(p.choices, contains(p.a), reason: '$id: ${p.q}');
        }
      }
      total += pack.questionCount;
    }
    expect(total, 3000); // school question bank, 2026-10
  });

  test('rank table matches the web', () {
    expect(rankFor(1800).$1, 'S');
    expect(rankFor(1799).$1, 'A');
    expect(rankFor(1400).$1, 'A');
    expect(rankFor(900).$1, 'B');
    expect(rankFor(500).$1, 'C');
    expect(rankFor(499).$1, 'D');
  });
}
