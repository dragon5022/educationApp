import 'dart:async';

import 'package:ark_core/purchase.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const kidsId = 'com.ark.kids.full_unlock';
const passId = 'com.ark.series_pass';

const kidsConfig = PurchaseConfig(
  products: [
    PurchaseProduct(id: kidsId, entitlements: {'kids_full'}),
    PurchaseProduct(id: passId, entitlements: {'kids_full', 'teen_full'}),
  ],
  requiredEntitlement: 'kids_full',
  restoreSettle: Duration.zero,
  purchaseTimeout: Duration(seconds: 5),
);

PurchaseDetails pd(
  String id,
  PurchaseStatus status, {
  bool pendingComplete = true,
  IAPError? error,
}) {
  return PurchaseDetails(
      purchaseID: 'tx-$id-${status.name}',
      productID: id,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'test',
      ),
      transactionDate: '0',
      status: status,
    )
    ..pendingCompletePurchase = pendingComplete
    ..error = error;
}

ProductDetails product(String id, String price) => ProductDetails(
  id: id,
  title: 'Full $id',
  description: 'desc',
  price: price,
  rawPrice: 1200,
  currencyCode: 'JPY',
);

/// Scriptable stand-in for the App Store / Play Billing.
class FakeStoreGateway implements StoreGateway {
  FakeStoreGateway({this.kind = StoreKind.appStore, this.available = true});

  @override
  StoreKind kind;
  bool available;

  final _ctrl = StreamController<List<PurchaseDetails>>.broadcast();
  final Map<String, ProductDetails> catalog = {
    kidsId: product(kidsId, '¥1,200'),
    passId: product(passId, '¥2,000'),
  };

  /// What the store "does" after the purchase sheet opens.
  List<PurchaseDetails> Function(ProductDetails p)? onBuy;
  bool buyStarts = true;
  Object? buyThrows;

  /// Emitted on [restorePurchases].
  List<PurchaseDetails> restoreEmits = [];

  /// Android-style authoritative ownership (null = iOS behaviour).
  List<PurchaseDetails>? owned;
  Object? ownedError;

  final List<String> bought = [];
  final List<PurchaseDetails> completed = [];
  int restoreCalls = 0;
  int redeemSheets = 0;

  void emit(List<PurchaseDetails> list) => _ctrl.add(list);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _ctrl.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    return ProductDetailsResponse(
      productDetails: [
        for (final id in ids)
          if (catalog[id] != null) catalog[id]!,
      ],
      notFoundIDs: [
        for (final id in ids)
          if (catalog[id] == null) id,
      ],
    );
  }

  @override
  Future<bool> buyNonConsumable(ProductDetails p) async {
    if (buyThrows != null) throw buyThrows!;
    bought.add(p.id);
    if (!buyStarts) return false;
    final react = onBuy;
    if (react != null) {
      scheduleMicrotask(() => emit(react(p)));
    }
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    if (restoreEmits.isNotEmpty) emit(List.of(restoreEmits));
  }

  @override
  Future<List<PurchaseDetails>?> queryOwnedPurchases() async {
    if (ownedError != null) throw ownedError!;
    return owned;
  }

  @override
  Future<void> presentCodeRedemptionSheet() async {
    redeemSheets++;
  }

  Future<void> close() => _ctrl.close();
}
