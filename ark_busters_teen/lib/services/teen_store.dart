import 'dart:async';

import 'package:ark_core/auth.dart';
import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'progress_keys.dart';

/// Store-facing setup for TEEN: one-time unlock, login and cloud progress
/// sync (all from `ark_core`). TEEN is not a Kids-category app, so no parent
/// gate. Values marked TODO depend on the client (藤井先生).
class TeenStore {
  TeenStore._();

  /// TODO(client): final product id from App Store Connect / Play Console.
  static const productId = 'com.ark.teen.full_unlock';
  static const entitlement = 'teen_full';

  /// Purchases are controlled from the Google Sheet's `pricing` tab
  /// (`teen,enabled,true`), so the school can switch them on without an app
  /// update. Debug builds always show the purchase UI for testing.
  static final ValueNotifier<bool> monetizationEnabled = ValueNotifier(false);
  static bool get showPurchaseUi => monetizationEnabled.value || kDebugMode;

  /// What is free without buying, while the sheet has no `pricing` rows for
  /// this app (and as the offline first-launch default).
  // Lv1 of each stage is free.
  static const defaultRules = ContentAccessRules(defaultFreeCount: 1);

  static final access = ContentAccess(rules: defaultRules);

  /// Applies the sheet's settings (see `ark_core` pricing_sheet.dart).
  static void _applyPricing() {
    final p = ArkContent.instance.pricing.value;
    if (p == null) {
      monetizationEnabled.value = false;
      access.updateRules(defaultRules);
      return;
    }
    monetizationEnabled.value = p['enabled'] == true;
    // While purchases are off, everything stays playable.
    access.updateRules(
      monetizationEnabled.value ? ContentAccessRules.fromJson(p) : ContentAccessRules.allFree,
    );
  }

  /// TODO(client): 利用規約 / プライバシーポリシー pages.
  static final Uri? termsUrl = null;
  static final Uri? privacyUrl = null;

  static const purchaseTheme = PurchaseTheme(
    borderColor: TeenColors.goldBright,
    accent: TeenColors.navy,
    accentDeep: TeenColors.navyDeep,
    ink: Color(0xFF1B2333),
    muted: Color(0xFF5E6B80),
    panelColor: TeenColors.lightBlue,
    radius: 18,
    borderWidth: 3,
    fontFamily: TeenFonts.mplus,
    fontFamilyFallback: [TeenFonts.zen],
  );

  static final authTheme = ArkAuthTheme.kids.copyWith(
    borderColor: TeenColors.goldBright,
    borderWidth: 3,
    radius: 18,
    buttonColor: TeenColors.navy,
    titleColor: TeenColors.navy,
    fieldFill: TeenColors.lightBlue,
    fontFamily: TeenFonts.mplus,
  );

  static const _rankOrder = 'DCBAS';

  static Future<void> init() async {
    ArkContent.instance.pricing.addListener(_applyPricing);
    _applyPricing();
    unawaited(PurchaseService.instance.configure(const PurchaseConfig(
      products: [PurchaseProduct(id: productId, entitlements: {entitlement})],
      requiredEntitlement: entitlement,
    )));

    await ArkAuth.instance.init(
      appId: 'teen',
      // TODO(client): DefaultFirebaseOptions.currentPlatform after
      // `flutterfire configure` (same Firebase project as KIDS).
      firebaseOptions: null,
      sync: ProgressSyncSpec([
        SyncKey.prefix('${ProgressKeys.prefix}best_', MergeRule.max),
        SyncKey.prefix('${ProgressKeys.prefix}rank_', MergeRule.custom(_betterRank)),
        SyncKey.prefix('${ProgressKeys.prefix}plays_', MergeRule.max),
        // ark_teen_bgm stays per device.
      ]),
    );
  }

  /// Keeps the better of two best ranks (S > A > B > C > D).
  static Object _betterRank(SyncEntry local, SyncEntry remote) {
    final a = _rankOrder.indexOf('${local.value}');
    final b = _rankOrder.indexOf('${remote.value}');
    return b > a ? remote.value : local.value;
  }

  /// Paywall (no parent gate on TEEN). Returns true when unlocked.
  static Future<bool> openPaywall(BuildContext context) => showPaywall(
        context,
        theme: purchaseTheme,
        features: const [
          PaywallFeature('📚', '5教科・全ステージの問題'),
          PaywallFeature('🆕', '追加される新しい問題も'),
          PaywallFeature('💎', '一度の購入でずっと'),
        ],
        termsUrl: termsUrl,
        privacyUrl: privacyUrl,
        openUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      );
}
