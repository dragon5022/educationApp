import 'package:ark_busters_kids/services/kids_store.dart';
import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locked content → parent gate → paywall → unlock, through the real KIDS
/// wiring. The store is unavailable in tests, so the purchase service runs
/// in its debug simulation (same code path as the web preview).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Answers the gate from its prompt (kanji number or `a × b = ?`).
  Future<void> solveGate(WidgetTester tester) async {
    final prompt = tester
        .widget<Text>(find.byKey(const ValueKey('parent-gate-prompt')))
        .data!;
    String answer;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(prompt);
    if (m != null) {
      answer = '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}';
    } else {
      final kanji = prompt.trim();
      answer = '';
      for (var n = 10000; n < 100000; n++) {
        if (ParentGateQuestion.toKanjiNumber(n) == kanji) {
          answer = '$n';
          break;
        }
      }
      expect(answer, isNotEmpty, reason: 'could not solve "$kanji"');
    }
    for (final d in answer.split('')) {
      await tester.tap(find.byKey(ValueKey('parent-gate-digit-$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('parent-gate-ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet pricing locks mode 2, gate + purchase unlocks it',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await KidsStore.init();
    // What the school would put in the sheet's pricing tab.
    ArkContent.instance.pricing.value = {'enabled': true, 'defaultFreeCount': 1};
    expect(KidsStore.monetizationEnabled.value, isTrue);
    expect(KidsStore.access.isLocked('vocab', 0, group: 'g5'), isFalse);
    expect(KidsStore.access.isLocked('vocab', 1, group: 'g5'), isTrue);
    expect(PurchaseService.instance.isSimulating, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ListenableBuilder(
            listenable: KidsStore.access,
            builder: (context, _) => LockedOverlay(
              locked: KidsStore.access.isLocked('vocab', 1, group: 'g5'),
              onLockedTap: () => KidsStore.openPaywall(context),
              child: const SizedBox(
                key: ValueKey('mode-2'),
                width: 300,
                height: 80,
                child: Text('スペル3択'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LockedBadge), findsOneWidget);

    // Tap the locked card → parent gate (the child itself is not tappable).
    await tester.tap(find.byKey(const ValueKey('mode-2')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('parent-gate-prompt')), findsOneWidget);

    await solveGate(tester);
    // Paywall with the KIDS copy and the debug banner.
    expect(find.byKey(const ValueKey('paywall-buy')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-debug-banner')), findsOneWidget);
    expect(find.textContaining('4つの ゲーム'), findsOneWidget);
    expect(find.text('購入を復元'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall-buy')));
    await tester.pumpAndSettle();
    expect(PurchaseService.instance.isUnlocked.value, isTrue);
    await tester.tap(find.byKey(const ValueKey('paywall-close-unlocked')));
    await tester.pumpAndSettle();

    // Everything is open now; the padlock is gone.
    expect(KidsStore.access.isLocked('vocab', 1, group: 'g5'), isFalse);
    expect(find.byType(LockedBadge), findsNothing);
  });

  testWidgets('wrong gate answer keeps the paywall closed', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await KidsStore.init();
    await PurchaseService.instance.debugReset(all: true);
    ArkContent.instance.pricing.value = {'enabled': true, 'defaultFreeCount': 1};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => KidsStore.openPaywall(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-gate-digit-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parent-gate-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('parent-gate-message')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-buy')), findsNothing);
    expect(PurchaseService.instance.isUnlocked.value, isFalse);
  });
}
