import 'dart:math';

import 'package:ark_core/purchase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kanji numbers', () {
    expect(ParentGateQuestion.toKanjiNumber(47082), '四万七千八十二');
    expect(ParentGateQuestion.toKanjiNumber(10000), '一万');
    expect(ParentGateQuestion.toKanjiNumber(11111), '一万千百十一');
    expect(ParentGateQuestion.toKanjiNumber(90506), '九万五百六');
    expect(ParentGateQuestion.toKanjiNumber(3725), '三千七百二十五');
  });

  test('generated questions are adult-level', () {
    final rng = Random(1);
    for (var i = 0; i < 200; i++) {
      final q = ParentGateQuestion.generate(rng);
      expect(q.answer.length, greaterThanOrEqualTo(3));
      expect(int.tryParse(q.answer), isNotNull);
      if (q.prompt.contains('×')) {
        final parts = q.prompt.split(RegExp(r'[^0-9]+'));
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        expect(a, greaterThanOrEqualTo(13));
        expect(b, greaterThanOrEqualTo(12));
        expect('${a * b}', q.answer);
      } else {
        expect(q.answer.length, 5);
        expect(q.prompt, contains('万'));
      }
    }
  });

  group('dialog', () {
    const fixed = ParentGateQuestion(
      instruction: '次の計算の答えを入力してください。',
      prompt: '23 × 17 = ?',
      answer: '391',
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugResetParentGate();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showParentGate(
                    context,
                    questionFactory: () => fixed,
                    random: Random(3),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String digits) async {
      for (final d in digits.split('')) {
        await tester.tap(find.byKey(ValueKey('parent-gate-digit-$d')));
        await tester.pump();
      }
    }

    testWidgets('correct answer passes', (tester) async {
      bool? result;
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugResetParentGate();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await showParentGate(
                context,
                questionFactory: () => fixed,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('23 × 17 = ?'), findsOneWidget);
      expect(find.textContaining('おうちの方へ'), findsOneWidget);

      await type(tester, '391');
      expect(find.text('391'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parent-gate-ok')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancel returns false; tapping outside does not close', (
      tester,
    ) async {
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(ParentGateDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parent-gate-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ParentGateDialog), findsNothing);
    });

    testWidgets('3 wrong answers lock the keypad, even after reopening', (
      tester,
    ) async {
      await open(tester);
      for (var i = 0; i < 3; i++) {
        await type(tester, '12');
        await tester.tap(find.byKey(const ValueKey('parent-gate-ok')));
        await tester.pump();
      }
      expect(find.textContaining('しばらくお待ちください'), findsOneWidget);

      // Locked: digits do nothing.
      await type(tester, '391');
      expect(find.text('391'), findsNothing);

      // Close and reopen: still locked.
      await tester.tap(find.byKey(const ValueKey('parent-gate-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('しばらくお待ちください'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parent-gate-cancel')));
      await tester.pumpAndSettle();
      debugResetParentGate();
    });
  });
}
