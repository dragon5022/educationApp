import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One owned product as remembered on the device.
class OwnedProduct {
  const OwnedProduct({
    required this.productId,
    required this.verifiedAt,
    this.simulated = false,
  });

  final String productId;
  final DateTime verifiedAt;

  /// Created by the debug simulation — ignored by release builds.
  final bool simulated;

  Map<String, Object?> toJson() => {
    'at': verifiedAt.toUtc().toIso8601String(),
    if (simulated) 'sim': true,
  };

  static OwnedProduct? fromJson(String id, Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return OwnedProduct(
      productId: id,
      verifiedAt: at,
      simulated: raw['sim'] == true,
    );
  }
}

/// Offline storage for owned products (so content stays unlocked without a
/// network connection).
abstract class EntitlementCache {
  Future<Map<String, OwnedProduct>> load();
  Future<void> save(Map<String, OwnedProduct> owned);
}

/// Default cache: a JSON blob in SharedPreferences.
///
/// Note: like any client-side flag this can be edited on a rooted /
/// jailbroken device. Acceptable for v1 (no server); a server-side verifier
/// can be added via `PurchaseConfig.verifier`.
class SharedPrefsEntitlementCache implements EntitlementCache {
  SharedPrefsEntitlementCache(this.key);

  final String key;

  @override
  Future<Map<String, OwnedProduct>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(key);
      if (s == null) return {};
      return decode(s);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, OwnedProduct> owned) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encode(owned));
  }

  static String encode(Map<String, OwnedProduct> owned) => jsonEncode({
    'owned': {for (final e in owned.entries) e.key: e.value.toJson()},
  });

  static Map<String, OwnedProduct> decode(String s) {
    final raw = jsonDecode(s);
    if (raw is! Map || raw['owned'] is! Map) return {};
    final out = <String, OwnedProduct>{};
    (raw['owned'] as Map).forEach((k, v) {
      final p = OwnedProduct.fromJson('$k', v);
      if (p != null) out['$k'] = p;
    });
    return out;
  }
}

/// In-memory cache (tests, or apps that don't want persistence).
class MemoryEntitlementCache implements EntitlementCache {
  Map<String, OwnedProduct> data = {};

  @override
  Future<Map<String, OwnedProduct>> load() async => Map.of(data);

  @override
  Future<void> save(Map<String, OwnedProduct> owned) async {
    data = Map.of(owned);
  }
}
