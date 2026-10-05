import 'package:ark_core/purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = ContentAccessRules(
    defaultFreeCount: 1,
    freeCounts: {'vocab': 3, 'listening/g3': 2},
    freePacks: {'talk'},
    lockedPacks: {'boss'},
  );

  test('free rules precedence', () {
    expect(rules.isFree('vocab', 2), isTrue);
    expect(rules.isFree('vocab', 3), isFalse);
    expect(rules.isFree('listening', 1, group: 'g3'), isTrue);
    expect(rules.isFree('listening', 2, group: 'g3'), isFalse);
    expect(rules.isFree('listening', 0, group: 'g4'), isTrue); // default 1
    expect(rules.isFree('listening', 1, group: 'g4'), isFalse);
    expect(rules.isFree('talk', 99), isTrue);
    expect(rules.isFree('boss', 0), isFalse);
    expect(rules.isFree('vocab', 50, itemFree: true), isTrue);
    expect(rules.isFree('vocab', 0, itemFree: false), isFalse);
  });

  test('fromJson + item flag parsing', () {
    final r = ContentAccessRules.fromJson({
      'defaultFreeCount': 2,
      'freeCounts': {'vocab': '4'},
      'freePacks': ['talk'],
    });
    expect(r.isFree('vocab', 3), isTrue);
    expect(r.isFree('other', 2), isFalse);
    expect(r.isFree('talk', 10), isTrue);
    expect(ContentAccess.itemFreeFlag({'free': 'TRUE'}), isTrue);
    expect(ContentAccess.itemFreeFlag({'free': ''}), isNull);
    expect(ContentAccess.itemFreeFlag({}), isNull);
    expect(ContentAccess.itemFreeFlag({'free': false}), isFalse);
  });

  test('ContentAccess follows the purchase state and notifies', () {
    final unlocked = ValueNotifier(false);
    final access = ContentAccess(rules: rules, unlocked: unlocked);
    var notified = 0;
    access.addListener(() => notified++);

    expect(access.isLocked('vocab', 5), isTrue);
    unlocked.value = true;
    expect(access.canAccess('vocab', 5), isTrue);
    expect(access.canAccess('boss', 0), isTrue);
    expect(notified, 1);
    access.dispose();
  });
}
