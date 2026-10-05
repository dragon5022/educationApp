import 'package:ark_core/purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStoreGateway store;
  late MemoryEntitlementCache cache;

  PurchaseService make({bool release = false, StoreGateway? gateway}) =>
      PurchaseService(
        gateway: gateway ?? store,
        cache: cache,
        releaseMode: release,
      );

  setUp(() {
    store = FakeStoreGateway();
    cache = MemoryEntitlementCache();
  });

  tearDown(() => store.close());

  group('buy', () {
    test('success unlocks, completes the transaction and caches', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      expect(svc.isUnlocked.value, isFalse);
      expect(svc.priceOf(), '¥1,200');

      store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];
      final r = await svc.buy();

      expect(r.kind, PurchaseResultKind.success);
      expect(r.simulated, isFalse);
      expect(svc.isUnlocked.value, isTrue);
      expect(svc.entitlements.value, {'kids_full'});
      expect(store.completed.single.productID, kidsId);
      expect(cache.data.keys, [kidsId]);
      expect(svc.phase.value, PurchasePhase.idle);
    });

    test('cancel leaves it locked and finishes the transaction', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.onBuy = (p) => [pd(p.id, PurchaseStatus.canceled)];

      final r = await svc.buy();

      expect(r.kind, PurchaseResultKind.canceled);
      expect(svc.isUnlocked.value, isFalse);
      expect(store.completed, hasLength(1));
      expect(cache.data, isEmpty);
    });

    test('pending (Ask to Buy / convenience store) then success', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.onBuy = (p) => [pd(p.id, PurchaseStatus.pending)];

      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.pending);
      expect(svc.phase.value, PurchasePhase.pending);
      expect(svc.isUnlocked.value, isFalse);

      // Parent approves later: the store delivers the purchase on its own.
      store.emit([pd(kidsId, PurchaseStatus.purchased)]);
      await Future<void>.delayed(Duration.zero);
      await svc.idle;

      expect(svc.isUnlocked.value, isTrue);
      expect(svc.phase.value, PurchasePhase.idle);
      expect(store.completed, hasLength(1));
    });

    test('network error is classified, then a retry succeeds', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.onBuy = (p) => [
        pd(
          p.id,
          PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: 'BillingResponse.serviceUnavailable',
          ),
        ),
      ];

      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.error);
      expect(r.error, PurchaseErrorKind.network);
      expect(svc.isUnlocked.value, isFalse);

      store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];
      final r2 = await svc.buy();
      expect(r2.kind, PurchaseResultKind.success);
      expect(svc.isUnlocked.value, isTrue);
    });

    test('buy throwing a platform error returns an error result', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.buyThrows = Exception('storekit_duplicate_product_object');
      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.error);
      expect(svc.phase.value, PurchasePhase.idle);
    });

    test('store refuses because already owned (Play) → alreadyOwned', () async {
      store.kind = StoreKind.playStore;
      store.owned = [];
      final svc = make();
      await svc.configure(kidsConfig);

      store.buyStarts = false;
      store.owned = [pd(kidsId, PurchaseStatus.purchased)];
      final r = await svc.buy();

      expect(r.kind, PurchaseResultKind.alreadyOwned);
      expect(svc.isUnlocked.value, isTrue);
    });

    test('unknown product / store unavailable', () async {
      store.catalog.remove(kidsId);
      final svc = make(release: true);
      await svc.configure(kidsConfig);
      final r = await svc.buy();
      expect(r.error, PurchaseErrorKind.productNotFound);

      store.available = false;
      await svc.refresh();
      final r2 = await svc.buy();
      expect(r2.error, PurchaseErrorKind.storeUnavailable);
    });

    test('verifier rejection keeps it locked and unfinished', () async {
      final svc = make();
      await svc.configure(
        PurchaseConfig(
          products: kidsConfig.products,
          requiredEntitlement: 'kids_full',
          restoreSettle: Duration.zero,
          verifier: (_) async => false,
        ),
      );
      store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];
      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.error);
      expect(svc.isUnlocked.value, isFalse);
      expect(store.completed, isEmpty);
    });
  });

  group('restore', () {
    test('restores owned purchase', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.restoreEmits = [pd(kidsId, PurchaseStatus.restored)];

      final r = await svc.restore();

      expect(r.kind, PurchaseResultKind.restored);
      expect(svc.isUnlocked.value, isTrue);
      expect(store.completed, hasLength(1));
    });

    test('nothing to restore', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      final r = await svc.restore();
      expect(r.kind, PurchaseResultKind.nothingToRestore);
      expect(svc.isUnlocked.value, isFalse);
    });

    test('series pass grants both entitlements', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.restoreEmits = [pd(passId, PurchaseStatus.restored)];
      await svc.restore();
      expect(svc.entitlements.value, {'kids_full', 'teen_full'});
      expect(svc.hasEntitlement('teen_full'), isTrue);
      expect(svc.isUnlocked.value, isTrue);
    });

    test('Android: owned query grants + acknowledges at startup', () async {
      store.kind = StoreKind.playStore;
      store.owned = [pd(kidsId, PurchaseStatus.purchased)];
      final svc = make();
      await svc.configure(kidsConfig);
      expect(svc.isUnlocked.value, isTrue);
      expect(store.completed.single.productID, kidsId); // acknowledged
    });

    test('Android: refund revokes; query failure keeps the cache', () async {
      store.kind = StoreKind.playStore;
      store.owned = [
        pd(kidsId, PurchaseStatus.purchased, pendingComplete: false),
      ];
      final svc = make();
      await svc.configure(kidsConfig);
      expect(svc.isUnlocked.value, isTrue);

      store.ownedError = Exception('offline');
      await svc.refresh();
      expect(svc.isUnlocked.value, isTrue, reason: 'network error ≠ refund');

      store.ownedError = null;
      store.owned = [];
      await svc.refresh();
      expect(svc.isUnlocked.value, isFalse);
      expect(cache.data, isEmpty);
    });
  });

  group('offline cache', () {
    test('unlock survives restart with no store (also in release)', () async {
      final first = make();
      await first.configure(kidsConfig);
      store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];
      await first.buy();
      await first.dispose();

      final offline = make(
        release: true,
        gateway: FakeStoreGateway(available: false),
      );
      await offline.configure(kidsConfig);
      expect(offline.isUnlocked.value, isTrue);
      expect(offline.isSimulating, isFalse);
    });

    test('iOS restore that finds nothing does not revoke', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      store.onBuy = (p) => [pd(p.id, PurchaseStatus.purchased)];
      await svc.buy();
      final r = await svc.restore();
      expect(r.kind, PurchaseResultKind.nothingToRestore);
      expect(svc.isUnlocked.value, isTrue);
    });

    test('SharedPreferences cache round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final c = SharedPrefsEntitlementCache('k');
      await c.save({
        kidsId: OwnedProduct(
          productId: kidsId,
          verifiedAt: DateTime.utc(2026, 1, 2),
        ),
      });
      final back = await c.load();
      expect(back[kidsId]!.verifiedAt, DateTime.utc(2026, 1, 2));
      expect(back[kidsId]!.simulated, isFalse);

      SharedPreferences.setMockInitialValues({'k': 'not json'});
      expect(await SharedPrefsEntitlementCache('k').load(), isEmpty);
    });
  });

  group('offer codes', () {
    test('iOS shows the sheet and a redeemed code unlocks', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      expect(await svc.redeemCode(), RedeemOutcome.sheetPresented);
      expect(store.redeemSheets, 1);

      // Redemption arrives as an ordinary transaction, no buy() in flight.
      store.emit([pd(kidsId, PurchaseStatus.purchased)]);
      await Future<void>.delayed(Duration.zero);
      await svc.idle;
      expect(svc.isUnlocked.value, isTrue);
    });

    test('Android returns the Play redeem URL', () async {
      store.kind = StoreKind.playStore;
      final svc = make();
      await svc.configure(kidsConfig);
      expect(await svc.redeemCode(), RedeemOutcome.openPlayStore);
      expect(
        svc.playRedeemUri(' ABC123 ').toString(),
        'https://play.google.com/redeem?code=ABC123',
      );
      expect(svc.playRedeemUri().toString(), 'https://play.google.com/redeem');
    });
  });

  group('debug simulation', () {
    test('debug build without a store simulates purchase/restore', () async {
      final svc = make(gateway: UnsupportedStoreGateway());
      await svc.configure(kidsConfig);
      expect(svc.isSimulating, isTrue);
      expect(svc.priceOf(), contains('テスト'));

      expect((await svc.restore()).kind, PurchaseResultKind.nothingToRestore);
      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.success);
      expect(r.simulated, isTrue);
      expect(svc.isUnlocked.value, isTrue);
      expect((await svc.restore()).kind, PurchaseResultKind.restored);

      await svc.debugReset();
      expect(svc.isUnlocked.value, isFalse);
    });

    test('release build: simulation disabled everywhere', () async {
      // A simulated unlock left over from a debug build is ignored.
      cache.data = {
        kidsId: OwnedProduct(
          productId: kidsId,
          verifiedAt: DateTime(2026),
          simulated: true,
        ),
      };
      final svc = make(release: true, gateway: UnsupportedStoreGateway());
      await svc.configure(kidsConfig);

      expect(svc.isSimulating, isFalse);
      expect(svc.isUnlocked.value, isFalse);
      final r = await svc.buy();
      expect(r.kind, PurchaseResultKind.error);
      expect(r.error, PurchaseErrorKind.storeUnavailable);
      expect(r.simulated, isFalse);
      expect(await svc.redeemCode(), RedeemOutcome.unsupported);
      await expectLater(svc.debugSimulatePurchase(), throwsStateError);
      expect(svc.isUnlocked.value, isFalse);
    });

    test('debug simulation is off when a real store is available', () async {
      final svc = make();
      await svc.configure(kidsConfig);
      expect(svc.isSimulating, isFalse);
    });
  });
}
