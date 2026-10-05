import 'package:ark_core/auth.dart';
import 'package:flutter_test/flutter_test.dart';

SyncEntry e(Object v, int t) => SyncEntry(v, t);

void main() {
  group('MergeRule.max', () {
    test('keeps the larger int regardless of time', () {
      expect(MergeRule.max.merge(e(5, 100), e(9, 1)).value, 9);
      expect(MergeRule.max.merge(e(12, 1), e(9, 100)).value, 12);
    });

    test('numeric strings (lb2_*/eb2_*) compare numerically, keep String', () {
      final m = MergeRule.max.merge(e('9', 1), e('120', 1));
      expect(m.value, '120');
      expect(m.value, isA<String>());
      // remote int, local String → String
      expect(MergeRule.max.merge(e('30', 1), e(40, 1)).value, '40');
      // remote String, local int → int
      expect(MergeRule.max.merge(e(3, 1), e('40', 1)).value, 40);
    });

    test('non-numeric falls back to last-writer-wins', () {
      expect(MergeRule.max.merge(e('abc', 1), e('xyz', 2)).value, 'xyz');
    });

    test('timestamp is the newer one', () {
      expect(MergeRule.max.merge(e(1, 10), e(2, 20)).updatedAt, 20);
    });
  });

  group('MergeRule.union', () {
    test('JSON string arrays: union, cloud order first', () {
      final m = MergeRule.union.merge(
        e('["vocamon","lismon"]', 1),
        e('["gramon","vocamon"]', 2),
      );
      expect(m.value, '["gramon","vocamon","lismon"]');
    });

    test('JSON int arrays (cards)', () {
      final m = MergeRule.union.merge(e('[1,5]', 1), e('[5,9,30]', 1));
      expect(m.value, '[5,9,30,1]');
    });

    test('List<String> values', () {
      final m = MergeRule.union.merge(e(['a', 'b'], 1), e(['c', 'a'], 1));
      expect(m.value, ['c', 'a', 'b']);
    });

    test('empty / broken JSON falls back to LWW, never throws', () {
      expect(MergeRule.union.merge(e('[]', 1), e('[2]', 1)).value, '[2]');
      expect(MergeRule.union.merge(e('oops', 1), e('[2]', 2)).value, '[2]');
    });
  });

  group('MergeRule.lastWriteWins', () {
    test('newer wins, tie keeps local', () {
      expect(MergeRule.lastWriteWins.merge(e('A', 1), e('B', 2)).value, 'B');
      expect(MergeRule.lastWriteWins.merge(e('A', 3), e('B', 2)).value, 'A');
      expect(MergeRule.lastWriteWins.merge(e('A', 2), e('B', 2)).value, 'A');
    });
  });

  group('MergeRule.auto', () {
    test('picks union / max / lww by shape', () {
      expect(MergeRule.auto.merge(e('[1]', 1), e('[2]', 1)).value, '[2,1]');
      expect(MergeRule.auto.merge(e('7', 9), e('3', 1)).value, '7');
      expect(MergeRule.auto.merge(e('Ken', 1), e('Aya', 2)).value, 'Aya');
    });
  });

  test('MergeRule.custom', () {
    final sum = MergeRule.custom((l, r) => (l.value as int) + (r.value as int));
    expect(sum.merge(e(2, 1), e(3, 5)), e(5, 5));
  });

  group('ProgressSyncSpec', () {
    const spec = ProgressSyncSpec([
      SyncKey('ark_name', MergeRule.lastWriteWins),
      SyncKey.prefix('ark_', MergeRule.max),
      SyncKey.prefix('ark_cards_', MergeRule.union),
    ]);

    test('exact beats prefix, longest prefix wins', () {
      expect(spec.ruleFor('ark_name'), MergeRule.lastWriteWins);
      expect(spec.ruleFor('ark_cards_lismon'), MergeRule.union);
      expect(spec.ruleFor('ark_s_lismon'), MergeRule.max);
      expect(spec.ruleFor('lb2_g5_0'), isNull);
    });

    test('ark_core_ bookkeeping keys are never synced', () {
      const all = ProgressSyncSpec([SyncKey.prefix('')]);
      expect(all.includes('ark_core_sync_meta'), isFalse);
      expect(all.includes('anything'), isTrue);
    });
  });

  group('planMerge', () {
    const spec = ProgressSyncSpec([
      SyncKey('ark_name', MergeRule.lastWriteWins),
      SyncKey('ark_friends', MergeRule.union),
      SyncKey.prefix('ark_best_', MergeRule.max),
    ]);

    test('missing keys are copied, never deleted', () {
      final p = planMerge(
        spec,
        {'ark_best_talk': e(10, 1)},
        {'ark_best_vocabulary': e(20, 1)},
      );
      expect(p.merged.keys, {'ark_best_talk', 'ark_best_vocabulary'});
      expect(p.toLocal.keys, {'ark_best_vocabulary'});
      expect(p.toRemote.keys, {'ark_best_talk'});
    });

    test('unlisted remote keys are ignored', () {
      final p = planMerge(spec, {}, {'other': e(1, 1)});
      expect(p.merged, isEmpty);
    });

    test('two devices converge without losing progress', () {
      final a = {
        'ark_name': e('ken', 100),
        'ark_friends': e('["vocamon"]', 50),
        'ark_best_talk': e(80, 50),
      };
      final b = {
        'ark_name': e('けん', 200),
        'ark_friends': e('["lismon"]', 60),
        'ark_best_talk': e(30, 300),
      };
      final p = planMerge(spec, a, b);
      expect(p.merged['ark_name']!.value, 'けん');
      expect(p.merged['ark_friends']!.value, '["lismon","vocamon"]');
      expect(p.merged['ark_best_talk']!.value, 80);
      // B then merges with the result and gets the same values.
      final q = planMerge(spec, b, p.merged);
      for (final k in p.merged.keys) {
        expect(q.merged[k]!.value, p.merged[k]!.value, reason: k);
      }
      expect(q.toRemote, isEmpty);
    });

    test('equal values produce no writes', () {
      final p = planMerge(
        spec,
        {'ark_best_talk': e(5, 1)},
        {'ark_best_talk': e(5, 9)},
      );
      expect(p.toLocal, isEmpty);
      expect(p.toRemote, isEmpty);
    });
  });

  test('SyncEntry.fromMap handles Firestore shapes', () {
    expect(SyncEntry.fromMap({'v': 3, 't': 5}), e(3, 5));
    expect(
      SyncEntry.fromMap({
        'v': ['a'],
        't': 5.0,
      }),
      e(['a'], 5),
    );
    expect(
      SyncEntry.fromMap({
        'v': {'x': 1},
        't': 1,
      }),
      isNull,
    );
    expect(SyncEntry.fromMap('nope'), isNull);
  });
}
