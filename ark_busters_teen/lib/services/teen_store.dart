import 'dart:async';

import 'package:ark_core/auth.dart';
import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../firebase_options.dart';
import 'progress_keys.dart';

/// Store-facing setup for TEEN: one-time unlock, login and cloud progress
/// sync (all from `ark_core`). TEEN is not a Kids-category app, so no parent
/// gate. Values marked TODO depend on the client (藤井先生).
class TeenStore {
  TeenStore._();

  /// Product id to create in App Store Connect / Play Console (same on both).
  static const productId = 'top.arkacademy.teen.full_unlock';
  static const entitlement = 'teen_full';

  /// Purchases are controlled from the Google Sheet's `pricing` tab
  /// (`teen,enabled,true`), so the school can switch them on without an app
  /// update. Debug builds always show the purchase UI for testing.
  static final ValueNotifier<bool> monetizationEnabled = ValueNotifier(false);
  static bool get showPurchaseUi => monetizationEnabled.value || kDebugMode;

  /// Level locks while purchases are on and the sheet gives no level rules:
  /// Lv1 of each stage free (the bank also marks each question `free`).
  static const defaultRules = ContentAccessRules(defaultFreeCount: 1);

  static final access = ContentAccess(rules: defaultRules);

  /// Paid questions are hidden while purchases are on and not yet made.
  static bool get paidQuestionsLocked =>
      monetizationEnabled.value && !access.isUnlocked;

  /// [items] without the paid ones when [paidQuestionsLocked].
  static Iterable<T> allowed<T>(Iterable<T> items, bool Function(T) isFree) =>
      paidQuestionsLocked ? items.where(isFree) : items;

  /// Applies the sheet's settings (see `ark_core` pricing_sheet.dart).
  static void _applyPricing() {
    final p = ArkContent.instance.pricing.value;
    monetizationEnabled.value = p != null && p['enabled'] == true;
    if (!monetizationEnabled.value) {
      // Purchases off (or no pricing rows yet): everything stays playable.
      access.updateRules(ContentAccessRules.allFree);
      return;
    }
    // Mode / level locks from the sheet; without such rows, the defaults.
    final hasModeRules = p!.keys.any((k) => k != 'enabled');
    access.updateRules(hasModeRules ? ContentAccessRules.fromJson(p) : defaultRules);
  }

  /// Legal pages on the school's site (drafts in docs/store/site; the client
  /// uploads them at exactly these paths).
  static final Uri termsUrl = Uri.parse('https://arkacademy.top/arkbusters/terms.html');
  static final Uri privacyUrl = Uri.parse('https://arkacademy.top/arkbusters/privacy.html');

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
      // Student IDs become <id>@students.arkacademy.top (the school's domain).
      config: const ArkAuthConfig(
        idDomain: 'students.arkacademy.top',
        supportContact: 'contact@arkacademy.top',
        accountDeletionUrl: 'https://arkacademy.top/arkbusters/privacy.html#delete',
      ),
      // lib/firebase_options.dart: a null stub until `flutterfire configure`
      // writes the school's project into it (docs/store/SETUP_RUNBOOK.md).
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
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
