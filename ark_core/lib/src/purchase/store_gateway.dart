import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Which store backs the current build.
enum StoreKind { appStore, playStore, none }

/// Thin seam over `InAppPurchase` so the service can be tested with fakes
/// and so unsupported platforms never touch the plugin.
abstract class StoreGateway {
  StoreKind get kind;

  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);

  /// Starts the store's purchase sheet. `false` = the store refused to start
  /// (e.g. Play `ITEM_ALREADY_OWNED`). The outcome arrives on
  /// [purchaseStream].
  Future<bool> buyNonConsumable(ProductDetails product);

  /// iOS `finishTransaction` / Android acknowledgement.
  Future<void> completePurchase(PurchaseDetails purchase);

  /// Re-delivers owned non-consumables on [purchaseStream] as `restored`.
  Future<void> restorePurchases();

  /// Authoritative list of currently owned purchases, or `null` when the
  /// platform can't answer directly (iOS — use [restorePurchases]).
  /// Throws when the store can't be reached.
  Future<List<PurchaseDetails>?> queryOwnedPurchases();

  /// iOS / iPadOS: the system Offer Code redemption sheet.
  Future<void> presentCodeRedemptionSheet();

  /// Picks the real gateway for this platform.
  static StoreGateway forCurrentPlatform() {
    if (kIsWeb) return UnsupportedStoreGateway();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return InAppPurchaseGateway(StoreKind.playStore);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return InAppPurchaseGateway(StoreKind.appStore);
      default:
        return UnsupportedStoreGateway();
    }
  }
}

/// Production gateway backed by `package:in_app_purchase`.
class InAppPurchaseGateway implements StoreGateway {
  InAppPurchaseGateway(this.kind);

  @override
  final StoreKind kind;

  // Lazy: touching `InAppPurchase.instance` registers the native platform.
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _iap.queryProductDetails(ids);

  @override
  Future<bool> buyNonConsumable(ProductDetails product) => _iap
      .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  Future<List<PurchaseDetails>?> queryOwnedPurchases() async {
    if (kind != StoreKind.playStore) return null;
    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final res = await addition.queryPastPurchases();
    if (res.error != null) {
      throw StateError('queryPastPurchases: ${res.error!.message}');
    }
    return res.pastPurchases;
  }

  @override
  Future<void> presentCodeRedemptionSheet() async {
    if (kind != StoreKind.appStore) return;
    final addition = _iap
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await addition.presentCodeRedemptionSheet();
  }
}

/// Web / desktop / tests: the store simply isn't there.
class UnsupportedStoreGateway implements StoreGateway {
  @override
  StoreKind get kind => StoreKind.none;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: ids.toList(),
      );

  @override
  Future<bool> buyNonConsumable(ProductDetails product) async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<List<PurchaseDetails>?> queryOwnedPurchases() async => null;

  @override
  Future<void> presentCodeRedemptionSheet() async {}
}
