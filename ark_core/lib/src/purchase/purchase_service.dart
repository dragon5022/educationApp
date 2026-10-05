import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement_cache.dart';
import 'purchase_config.dart';
import 'store_gateway.dart';

/// A product as shown in the UI (store-localized price, or a debug stand-in).
@immutable
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.rawPrice,
    this.currencyCode,
    this.simulated = false,
  });

  factory StoreProduct.fromDetails(ProductDetails d) => StoreProduct(
    id: d.id,
    title: d.title,
    description: d.description,
    price: d.price,
    rawPrice: d.rawPrice,
    currencyCode: d.currencyCode,
  );

  final String id;
  final String title;
  final String description;

  /// Localized price string from the store, e.g. `¥1,200`. Always show this
  /// (never a hard-coded price) — App Store / Play requirement.
  final String price;
  final double? rawPrice;
  final String? currencyCode;
  final bool simulated;
}

enum PurchaseResultKind {
  success,
  restored,
  alreadyOwned,
  pending,
  canceled,
  nothingToRestore,
  timeout,
  error,
}

enum PurchaseErrorKind {
  storeUnavailable,
  productNotFound,
  network,
  notAllowed,
  unknown,
}

/// Outcome of `buy()` / `restore()`.
@immutable
class PurchaseResult {
  const PurchaseResult(
    this.kind, {
    this.error,
    this.detail,
    this.simulated = false,
  });

  final PurchaseResultKind kind;
  final PurchaseErrorKind? error;

  /// Raw store message, for logs only (not for children's eyes).
  final String? detail;

  /// Produced by the debug simulation (never in release builds).
  final bool simulated;

  bool get unlocked =>
      kind == PurchaseResultKind.success ||
      kind == PurchaseResultKind.restored ||
      kind == PurchaseResultKind.alreadyOwned;

  @override
  String toString() =>
      'PurchaseResult($kind${error == null ? '' : ', $error'}'
      '${simulated ? ', simulated' : ''})';
}

/// What the purchase UI should currently show.
enum PurchasePhase { idle, loading, purchasing, pending, restoring }

/// How `redeemCode()` was handled.
enum RedeemOutcome {
  /// iOS: the system offer-code sheet was shown; a successful redemption
  /// arrives as a normal purchase and unlocks automatically.
  sheetPresented,

  /// Android: the UI should open [PurchaseService.playRedeemUri] (or show
  /// the manual instructions). The resulting purchase is picked up on
  /// resume via [PurchaseService.refresh].
  openPlayStore,

  /// Debug simulation granted the main product.
  simulated,

  unsupported,
}

/// In-app purchase + entitlement state for one app.
///
/// ```dart
/// await PurchaseService.instance.configure(const PurchaseConfig(
///   products: [PurchaseProduct(id: 'com.ark.kids.full_unlock',
///                              entitlements: {'kids_full'})],
///   requiredEntitlement: 'kids_full',
/// ));
/// PurchaseService.instance.isUnlocked // ValueListenable<bool>
/// ```
class PurchaseService {
  PurchaseService({
    StoreGateway? gateway,
    EntitlementCache? cache,
    bool? releaseMode,
    DateTime Function()? clock,
  }) : _gatewayOverride = gateway,
       _cacheOverride = cache,
       _releaseMode = releaseMode ?? kReleaseMode,
       _clock = clock ?? DateTime.now;

  /// App-wide instance. Tests create their own `PurchaseService(...)`.
  static final PurchaseService instance = PurchaseService();

  final StoreGateway? _gatewayOverride;
  final EntitlementCache? _cacheOverride;
  final bool _releaseMode;
  final DateTime Function() _clock;

  StoreGateway? _gw;
  StoreGateway get _gateway =>
      _gw ??= _gatewayOverride ?? StoreGateway.forCurrentPlatform();

  EntitlementCache? _cache;
  PurchaseConfig? _config;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, OwnedProduct> _owned = {};
  final Map<String, ProductDetails> _details = {};
  final Map<String, Completer<PurchaseResult>> _buys = {};
  final Set<String> _restoredThisRound = {};
  Future<void> _queue = Future.value();

  final ValueNotifier<Set<String>> _entitlements = ValueNotifier(const {});
  final ValueNotifier<bool> _unlocked = ValueNotifier(false);
  final ValueNotifier<Map<String, StoreProduct>> _products = ValueNotifier(
    const {},
  );
  final ValueNotifier<PurchasePhase> _phase = ValueNotifier(PurchasePhase.idle);
  final ValueNotifier<bool> _storeAvailable = ValueNotifier(false);

  // ---------------------------------------------------------------- state --

  PurchaseConfig get config {
    final c = _config;
    if (c == null) {
      throw StateError('PurchaseService.configure() has not been called.');
    }
    return c;
  }

  bool get isConfigured => _config != null;

  /// True when this app's "all content" entitlement is owned. Other modules
  /// (menus, progress sync…) listen to this.
  ValueListenable<bool> get isUnlocked => _unlocked;

  /// Every entitlement currently owned (supports multi-app / series pass).
  ValueListenable<Set<String>> get entitlements => _entitlements;

  bool hasEntitlement(String entitlement) =>
      _entitlements.value.contains(entitlement);

  bool isOwned(String productId) => _owned.containsKey(productId);

  /// Products with store prices (keyed by product id).
  ValueListenable<Map<String, StoreProduct>> get products => _products;

  StoreProduct? product(String productId) => _products.value[productId];

  /// Localized price for [productId] (defaults to the main product).
  String? priceOf([String? productId]) =>
      _products.value[productId ?? config.mainProductId]?.price;

  ValueListenable<PurchasePhase> get phase => _phase;

  ValueListenable<bool> get storeAvailable => _storeAvailable;

  StoreKind get storeKind => _gateway.kind;

  /// Debug-only simulation: store unavailable, debug/profile build, and
  /// allowed by config. Always false in release builds.
  bool get isSimulating =>
      !_releaseMode &&
      (_config?.allowDebugSimulation ?? false) &&
      !_storeAvailable.value;

  /// Play Store redeem page, optionally pre-filled with [code].
  Uri playRedeemUri([String? code]) => Uri.https(
    'play.google.com',
    '/redeem',
    code == null || code.trim().isEmpty ? null : {'code': code.trim()},
  );

  // ---------------------------------------------------------- lifecycle --

  /// Loads the offline cache (content unlocks immediately, even offline),
  /// starts listening to the store and refreshes in the background.
  ///
  /// Call once at startup, before `runApp` or right after. Awaiting is
  /// optional; [isUnlocked] is valid as soon as the cache has loaded.
  Future<void> configure(PurchaseConfig config) async {
    if (config.products.isEmpty) {
      throw ArgumentError('PurchaseConfig.products must not be empty');
    }
    _config = config;
    _cache = _cacheOverride ?? SharedPrefsEntitlementCache(config.storageKey);
    final cached = await _cache!.load();
    _owned
      ..clear()
      ..addEntries(
        cached.entries.where((e) => !(e.value.simulated && _releaseMode)),
      );
    _recompute();
    // Subscribe first: iOS re-delivers unfinished transactions immediately.
    _sub ??= _gateway.purchaseStream.listen(
      (list) => _queue = _queue.then((_) => _handleAll(list)),
      onError: (Object e) => debugPrint('[purchase] stream error: $e'),
    );
    await refresh();
  }

  /// Re-checks the store (availability, prices, owned items on Android).
  /// Safe to call on app resume; never revokes on network errors.
  Future<void> refresh() async {
    final cfg = config;
    bool available;
    try {
      available = await _gateway.isAvailable();
    } catch (_) {
      available = false;
    }
    _storeAvailable.value = available;
    if (available) {
      await loadProducts();
      await _reconcileOwned();
    } else if (isSimulating) {
      _products.value = {
        for (final p in cfg.products)
          p.id: StoreProduct(
            id: p.id,
            title: p.debugTitle,
            description: '',
            price: '${p.debugPrice}（テスト）',
            simulated: true,
          ),
      };
    }
  }

  /// Queries product details/prices. Returns what was found.
  Future<Map<String, StoreProduct>> loadProducts() async {
    try {
      final res = await _gateway.queryProductDetails(config.productIds);
      for (final d in res.productDetails) {
        _details[d.id] = d;
      }
      if (res.error != null) {
        debugPrint('[purchase] product query error: ${res.error!.message}');
      }
      if (res.notFoundIDs.isNotEmpty) {
        debugPrint('[purchase] products not found: ${res.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('[purchase] product query failed: $e');
    }
    _products.value = {
      for (final d in _details.values) d.id: StoreProduct.fromDetails(d),
    };
    return _products.value;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    for (final c in _buys.values) {
      if (!c.isCompleted) {
        c.complete(const PurchaseResult(PurchaseResultKind.canceled));
      }
    }
    _buys.clear();
  }

  /// Completes once all purchase updates received so far are handled.
  @visibleForTesting
  Future<void> get idle => _queue;

  // ------------------------------------------------------------- actions --

  /// Buys [productId] (defaults to the main product). Shows the store sheet.
  /// Call only after the parent gate in KIDS.
  Future<PurchaseResult> buy([String? productId]) async {
    final cfg = config;
    final id = productId ?? cfg.mainProductId;
    if (cfg.productById(id) == null) {
      return PurchaseResult(
        PurchaseResultKind.error,
        error: PurchaseErrorKind.productNotFound,
        detail: 'not configured: $id',
      );
    }
    final existing = _buys[id];
    if (existing != null) return existing.future; // double tap

    if (isSimulating) {
      _phase.value = PurchasePhase.purchasing;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _grant(id, simulated: true);
      _phase.value = PurchasePhase.idle;
      return const PurchaseResult(PurchaseResultKind.success, simulated: true);
    }

    if (!_storeAvailable.value) await refresh();
    if (!_storeAvailable.value) {
      return const PurchaseResult(
        PurchaseResultKind.error,
        error: PurchaseErrorKind.storeUnavailable,
      );
    }
    var details = _details[id];
    if (details == null) {
      await loadProducts();
      details = _details[id];
    }
    if (details == null) {
      return const PurchaseResult(
        PurchaseResultKind.error,
        error: PurchaseErrorKind.productNotFound,
      );
    }

    final completer = Completer<PurchaseResult>();
    _buys[id] = completer;
    _phase.value = PurchasePhase.purchasing;
    try {
      bool started;
      try {
        started = await _gateway.buyNonConsumable(details);
      } catch (e) {
        final s = '$e';
        if (_looksCanceled(s)) {
          return const PurchaseResult(PurchaseResultKind.canceled);
        }
        return PurchaseResult(
          PurchaseResultKind.error,
          error: _classify(s),
          detail: s,
        );
      }
      if (!started) {
        // e.g. Play ITEM_ALREADY_OWNED: check what the store says we own.
        await _reconcileOwned();
        await _queue;
        if (isOwned(id)) {
          return const PurchaseResult(PurchaseResultKind.alreadyOwned);
        }
        if (completer.isCompleted) return await completer.future;
        return const PurchaseResult(
          PurchaseResultKind.error,
          error: PurchaseErrorKind.unknown,
          detail: 'store refused to start the purchase',
        );
      }
      return await completer.future.timeout(
        cfg.purchaseTimeout,
        onTimeout: () => const PurchaseResult(PurchaseResultKind.timeout),
      );
    } finally {
      _buys.remove(id);
      if (_phase.value == PurchasePhase.purchasing) {
        _phase.value = PurchasePhase.idle;
      }
    }
  }

  /// "購入を復元". Never removes an unlock (a failed/empty restore while
  /// offline must not lock a paying family out).
  Future<PurchaseResult> restore() async {
    final cfg = config;
    if (isSimulating) {
      _phase.value = PurchasePhase.restoring;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _phase.value = PurchasePhase.idle;
      final has = _owned.values.any((o) => o.simulated);
      return PurchaseResult(
        has ? PurchaseResultKind.restored : PurchaseResultKind.nothingToRestore,
        simulated: true,
      );
    }
    if (!_storeAvailable.value) await refresh();
    if (!_storeAvailable.value) {
      return const PurchaseResult(
        PurchaseResultKind.error,
        error: PurchaseErrorKind.storeUnavailable,
      );
    }
    _phase.value = PurchasePhase.restoring;
    _restoredThisRound.clear();
    try {
      await _gateway.restorePurchases();
      await _reconcileOwned(countAsRestored: true);
      await Future<void>.delayed(cfg.restoreSettle);
      await _queue;
    } catch (e) {
      return PurchaseResult(
        PurchaseResultKind.error,
        error: _classify('$e'),
        detail: '$e',
      );
    } finally {
      _phase.value = PurchasePhase.idle;
    }
    final found = _restoredThisRound.isNotEmpty;
    _restoredThisRound.clear();
    return PurchaseResult(
      found ? PurchaseResultKind.restored : PurchaseResultKind.nothingToRestore,
    );
  }

  /// "コードを使う". iOS shows Apple's offer-code sheet; Android returns
  /// [RedeemOutcome.openPlayStore] for the UI to open [playRedeemUri].
  Future<RedeemOutcome> redeemCode() async {
    if (isSimulating) {
      await _grant(config.mainProductId, simulated: true);
      return RedeemOutcome.simulated;
    }
    switch (_gateway.kind) {
      case StoreKind.appStore:
        try {
          await _gateway.presentCodeRedemptionSheet();
          return RedeemOutcome.sheetPresented;
        } catch (e) {
          debugPrint('[purchase] offer code sheet failed: $e');
          return RedeemOutcome.unsupported;
        }
      case StoreKind.playStore:
        return RedeemOutcome.openPlayStore;
      case StoreKind.none:
        return RedeemOutcome.unsupported;
    }
  }

  // --------------------------------------------------------------- debug --

  /// Debug builds only: pretend [productId] was bought.
  Future<void> debugSimulatePurchase([String? productId]) async {
    _assertDebug();
    await _grant(productId ?? config.mainProductId, simulated: true);
  }

  /// Debug builds only: forget simulated (or, with [all], every) purchase.
  Future<void> debugReset({bool all = false}) async {
    _assertDebug();
    _owned.removeWhere((_, o) => all || o.simulated);
    await _persist();
    _recompute();
  }

  void _assertDebug() {
    if (_releaseMode) {
      throw StateError('Purchase simulation is disabled in release builds.');
    }
  }

  // ------------------------------------------------------------ internal --

  Future<void> _handleAll(List<PurchaseDetails> list) async {
    for (final p in list) {
      try {
        await _handle(p);
      } catch (e) {
        debugPrint('[purchase] failed handling ${p.productID}: $e');
      }
    }
  }

  Future<void> _handle(PurchaseDetails p) async {
    final configured = _config?.productById(p.productID) != null;
    final completer = _buys[p.productID];
    void finish(PurchaseResult r) {
      if (completer != null && !completer.isCompleted) completer.complete(r);
    }

    switch (p.status) {
      case PurchaseStatus.pending:
        _phase.value = PurchasePhase.pending;
        finish(const PurchaseResult(PurchaseResultKind.pending));
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (!configured) {
          await _complete(p);
          return;
        }
        final ok = await _verify(p);
        if (!ok) {
          // Leave unfinished: the store re-delivers it later.
          finish(
            const PurchaseResult(
              PurchaseResultKind.error,
              error: PurchaseErrorKind.unknown,
              detail: 'verification failed',
            ),
          );
          return;
        }
        await _grant(p.productID);
        await _complete(p);
        if (p.status == PurchaseStatus.restored ||
            _phase.value == PurchasePhase.restoring) {
          _restoredThisRound.add(p.productID);
        }
        if (_phase.value == PurchasePhase.pending) {
          _phase.value = PurchasePhase.idle;
        }
        finish(
          PurchaseResult(
            p.status == PurchaseStatus.restored
                ? PurchaseResultKind.restored
                : PurchaseResultKind.success,
          ),
        );
        return;

      case PurchaseStatus.canceled:
        await _complete(p);
        if (_phase.value == PurchasePhase.pending) {
          _phase.value = PurchasePhase.idle;
        }
        finish(const PurchaseResult(PurchaseResultKind.canceled));
        return;

      case PurchaseStatus.error:
        await _complete(p);
        if (_phase.value == PurchasePhase.pending) {
          _phase.value = PurchasePhase.idle;
        }
        final e = p.error;
        final s = '${e?.code} ${e?.message} ${e?.details}';
        if (s.toLowerCase().contains('alreadyowned')) {
          await _reconcileOwned();
          if (isOwned(p.productID)) {
            finish(const PurchaseResult(PurchaseResultKind.alreadyOwned));
            return;
          }
        }
        if (_looksCanceled(s)) {
          finish(const PurchaseResult(PurchaseResultKind.canceled));
          return;
        }
        finish(
          PurchaseResult(
            PurchaseResultKind.error,
            error: _classify(s),
            detail: s,
          ),
        );
        return;
    }
  }

  Future<bool> _verify(PurchaseDetails p) async {
    final v = _config?.verifier;
    if (v == null) return true;
    try {
      return await v(p);
    } catch (e) {
      debugPrint('[purchase] verifier threw: $e');
      return false;
    }
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _gateway.completePurchase(p);
    } catch (e) {
      debugPrint('[purchase] completePurchase failed: $e');
    }
  }

  /// Android: ask Play what is owned right now. Grants missing items,
  /// acknowledges unacknowledged ones, and (optionally) drops refunded ones.
  Future<void> _reconcileOwned({bool countAsRestored = false}) async {
    List<PurchaseDetails>? owned;
    try {
      owned = await _gateway.queryOwnedPurchases();
    } catch (e) {
      debugPrint('[purchase] owned query failed (kept cache): $e');
      return;
    }
    if (owned == null) return;
    final cfg = config;
    final ownedIds = <String>{};
    for (final p in owned) {
      if (p.status != PurchaseStatus.purchased &&
          p.status != PurchaseStatus.restored) {
        continue;
      }
      if (cfg.productById(p.productID) == null) continue;
      if (!await _verify(p)) continue;
      ownedIds.add(p.productID);
      await _grant(p.productID);
      await _complete(p);
    }
    if (countAsRestored) _restoredThisRound.addAll(ownedIds);
    if (cfg.revokeWhenStoreSaysNotOwned) {
      final before = _owned.length;
      _owned.removeWhere(
        (id, o) =>
            !o.simulated &&
            cfg.productById(id) != null &&
            !ownedIds.contains(id),
      );
      if (_owned.length != before) {
        await _persist();
        _recompute();
      }
    }
  }

  Future<void> _grant(String productId, {bool simulated = false}) async {
    final prev = _owned[productId];
    // Keep the first real record; a real purchase replaces a simulated one.
    if (prev != null && !prev.simulated) return;
    _owned[productId] = OwnedProduct(
      productId: productId,
      verifiedAt: _clock(),
      simulated: simulated,
    );
    await _persist();
    _recompute();
  }

  Future<void> _persist() async {
    try {
      await _cache?.save(Map.of(_owned));
    } catch (e) {
      debugPrint('[purchase] cache save failed: $e');
    }
  }

  void _recompute() {
    final cfg = _config;
    final ents = <String>{};
    if (cfg != null) {
      for (final id in _owned.keys) {
        ents.addAll(cfg.productById(id)?.entitlements ?? const {});
      }
    }
    if (!setEquals(ents, _entitlements.value)) {
      _entitlements.value = Set.unmodifiable(ents);
    }
    _unlocked.value = cfg != null && ents.contains(cfg.requiredEntitlement);
  }

  static bool _looksCanceled(String s) {
    final l = s.toLowerCase();
    return l.contains('usercanceled') ||
        l.contains('usercancelled') ||
        l.contains('paymentcancelled') ||
        l.contains('cancelled by user');
  }

  static PurchaseErrorKind _classify(String s) {
    final l = s.toLowerCase();
    if (l.contains('network') ||
        l.contains('serviceunavailable') ||
        l.contains('servicedisconnected') ||
        l.contains('servicetimeout') ||
        l.contains('offline') ||
        l.contains('timed out')) {
      return PurchaseErrorKind.network;
    }
    if (l.contains('billingunavailable')) {
      return PurchaseErrorKind.storeUnavailable;
    }
    if (l.contains('itemunavailable') || l.contains('invalidproduct')) {
      return PurchaseErrorKind.productNotFound;
    }
    if (l.contains('notallowed') || l.contains('not allowed')) {
      return PurchaseErrorKind.notAllowed;
    }
    return PurchaseErrorKind.unknown;
  }
}
