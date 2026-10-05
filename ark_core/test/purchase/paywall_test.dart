import 'package:ark_core/purchase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'fakes.dart';

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(PurchaseService svc) => MaterialApp(
    home: Scaffold(
      body: Paywall(
        service: svc,
        features: const [PaywallFeature('📚', 'ぜんぶの もんだい')],
        termsUrl: Uri.parse('https://example.com/terms'),
        privacyUrl: Uri.parse('https://example.com/privacy'),
      ),
    ),
  );

  testWidgets('shows store price, buys and switches to unlocked', (
    tester,
  ) async {
    bigScreen(tester);
    final store = FakeStoreGateway();
    final svc = PurchaseService(
      gateway: store,
      cache: MemoryEntitlementCache(),
      releaseMode: false,
    );
    await svc.configure(kidsConfig);
    store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];

    await tester.pumpWidget(host(svc));
    expect(find.text('¥1,200 で購入'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-debug-banner')), findsNothing);
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('コードを使う'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall-buy')));
    await tester.pumpAndSettle();

    expect(svc.isUnlocked.value, isTrue);
    expect(find.textContaining('ありがとう'), findsWidgets);
    expect(
      find.byKey(const ValueKey('paywall-close-unlocked')),
      findsOneWidget,
    );
    await store.close();
  });

  testWidgets('error shows Japanese message with retry', (tester) async {
    bigScreen(tester);
    final store = FakeStoreGateway();
    final svc = PurchaseService(
      gateway: store,
      cache: MemoryEntitlementCache(),
      releaseMode: false,
    );
    await svc.configure(kidsConfig);
    store.onBuy = (p) => [
      pd(
        p.id,
        PurchaseStatus.error,
        error: IAPError(source: 't', code: 'x', message: 'network down'),
      ),
    ];
    await tester.pumpWidget(host(svc));
    await tester.tap(find.byKey(const ValueKey('paywall-buy')));
    await tester.pumpAndSettle();
    expect(find.text(const PurchaseStrings().network), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);
    await store.close();
  });

  testWidgets('debug simulation banner + simulated purchase', (tester) async {
    bigScreen(tester);
    final svc = PurchaseService(
      gateway: UnsupportedStoreGateway(),
      cache: MemoryEntitlementCache(),
      releaseMode: false,
    );
    await svc.configure(kidsConfig);
    await tester.pumpWidget(host(svc));
    expect(find.byKey(const ValueKey('paywall-debug-banner')), findsOneWidget);
    expect(find.textContaining('（テスト）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paywall-buy')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(svc.isUnlocked.value, isTrue);
  });

  testWidgets('showPaywall with parent gate: cancel never shows the sheet', (
    tester,
  ) async {
    bigScreen(tester);
    debugResetParentGate();
    final svc = PurchaseService(
      gateway: FakeStoreGateway(),
      cache: MemoryEntitlementCache(),
      releaseMode: false,
    );
    await svc.configure(kidsConfig);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showPaywall(
              context,
              service: svc,
              requireParentGate: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ParentGateDialog), findsOneWidget);
    expect(find.byType(Paywall), findsNothing);

    await tester.tap(find.byKey(const ValueKey('parent-gate-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(Paywall), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('LockedOverlay routes taps to onLockedTap', (tester) async {
    var lockedTaps = 0;
    var childTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LockedOverlay(
            locked: true,
            onLockedTap: () => lockedTaps++,
            child: GestureDetector(
              onTap: () => childTaps++,
              child: const SizedBox(width: 120, height: 120),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LockedBadge), findsOneWidget);
    await tester.tap(find.byType(LockedOverlay));
    expect(lockedTaps, 1);
    expect(childTaps, 0);
  });
}
