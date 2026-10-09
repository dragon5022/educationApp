import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = parseCsvRecords('''app,item,value,メモ
kids,enabled,true,
kids,defaultFreeCount,1,
kids,freeCounts.vocab,2,
kids,freeCounts.listening/g5,3,
kids,freePacks,"talk, sentence",
teen,enabled,false,
teen,lockedPacks,k-kanji、k-koten,
,ignored,row,
''');

  test('rows → per-app settings', () {
    final kids = pricingFromRows(rows, 'kids')!;
    expect(kids['enabled'], isTrue);
    expect(kids['defaultFreeCount'], 1);
    expect(kids['freeCounts'], {'vocab': 2, 'listening/g5': 3});
    expect(kids['freePacks'], ['talk', 'sentence']);
    final teen = pricingFromRows(rows, 'TEEN')!;
    expect(teen['enabled'], isFalse);
    expect(teen['lockedPacks'], ['k-kanji', 'k-koten']);
    expect(pricingFromRows(rows, 'other'), isNull);
  });

  test('settings drive ContentAccessRules', () {
    final r = ContentAccessRules.fromJson(pricingFromRows(rows, 'kids')!);
    expect(r.isFree('vocab', 1), isTrue); // 2 free
    expect(r.isFree('vocab', 2), isFalse);
    expect(r.isFree('listening', 2, group: 'g5'), isTrue); // 3 free on g5
    expect(r.isFree('listening', 2, group: 'g4'), isFalse); // default 1
    expect(r.isFree('talk', 9), isTrue); // whole pack free
  });
}
