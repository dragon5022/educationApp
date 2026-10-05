import 'package:in_app_purchase/in_app_purchase.dart';

/// A one-time (non-consumable / 買い切り) store product and the entitlements
/// it grants.
///
/// Entitlements decouple "what was bought" from "what is unlocked":
///
/// ```dart
/// // KIDS sold on its own
/// PurchaseProduct(id: 'com.ark.kids.full_unlock', entitlements: {'kids_full'})
/// // a future series pass sold inside the KIDS app
/// PurchaseProduct(id: 'com.ark.kids.series_pass',
///     entitlements: {'kids_full', 'teen_full'})
/// ```
class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.entitlements,
    this.debugTitle = 'ぜんぶ あそべる パック',
    this.debugPrice = '¥1,200',
  });

  /// Store product ID — identical in App Store Connect and Play Console.
  final String id;

  /// Entitlement keys granted by owning this product.
  final Set<String> entitlements;

  /// Title / price shown only in the debug simulation (store unavailable).
  final String debugTitle;
  final String debugPrice;
}

/// Decides whether a purchase reported by the store is trustworthy before
/// it is cached as an entitlement. Return `false` to reject.
///
/// The default accepts every purchase the platform plugin reports
/// (StoreKit 2 transactions are signature-checked on device by the plugin;
/// Google Play purchases come from the signed Billing client). Plug a
/// server-side check (e.g. Cloud Functions + App Store Server API / Play
/// Developer API) in here later without touching the UI.
typedef PurchaseVerifier = Future<bool> Function(PurchaseDetails purchase);

/// Per-app purchase configuration passed to `PurchaseService.configure`.
class PurchaseConfig {
  const PurchaseConfig({
    required this.products,
    required this.requiredEntitlement,
    this.primaryProductId,
    this.verifier,
    this.storageKey = 'ark_purchase.v1',
    this.allowDebugSimulation = true,
    this.restoreSettle = const Duration(seconds: 2),
    this.purchaseTimeout = const Duration(minutes: 3),
    this.revokeWhenStoreSaysNotOwned = true,
  });

  /// Every product this app may sell or recognise (must not be empty),
  /// e.g. the app's own unlock plus a series pass.
  final List<PurchaseProduct> products;

  /// The entitlement that unlocks "all content" in this app,
  /// e.g. `'kids_full'` or `'teen_full'`. Drives `PurchaseService.isUnlocked`.
  final String requiredEntitlement;

  /// Product sold by the paywall's main button. Defaults to the first
  /// product granting [requiredEntitlement].
  final String? primaryProductId;

  final PurchaseVerifier? verifier;

  /// SharedPreferences key for the offline entitlement cache.
  final String storageKey;

  /// Allows the debug-only purchase simulation when the store is not
  /// available (web, desktop, emulator without Play). Never active in a
  /// release build regardless of this flag.
  final bool allowDebugSimulation;

  /// How long `restore()` keeps listening for restored transactions after
  /// the store call returns.
  final Duration restoreSettle;

  /// Upper bound for one `buy()` call waiting for a store answer.
  final Duration purchaseTimeout;

  /// When the store gives an authoritative list of owned items (Google
  /// Play), drop cached products it no longer reports (refunds/revokes).
  final bool revokeWhenStoreSaysNotOwned;

  PurchaseProduct? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String get mainProductId {
    if (primaryProductId != null) return primaryProductId!;
    for (final p in products) {
      if (p.entitlements.contains(requiredEntitlement)) return p.id;
    }
    return products.first.id;
  }

  Set<String> get productIds => {for (final p in products) p.id};
}
