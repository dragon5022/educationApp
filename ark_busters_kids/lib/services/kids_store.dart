import 'dart:async';

import 'package:ark_core/auth.dart';
import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/progress/progress_keys.dart';
import 'progress_service.dart';

/// Store-facing setup for KIDS: one-time unlock, parent gate, login and
/// cloud progress sync (all from `ark_core`).
///
/// Values marked TODO depend on the client (藤井先生): product id, what is
/// free, legal URLs and the Firebase project.
class KidsStore {
  KidsStore._();

  /// Product id to create in App Store Connect / Play Console (same on both).
  static const productId = 'top.arkacademy.kids.full_unlock';
  static const entitlement = 'kids_full';

  /// Purchases are controlled from the Google Sheet's `pricing` tab
  /// (`kids,enabled,true`), so the school can switch them on without an app
  /// update. Debug builds always show the purchase UI for testing.
  static final ValueNotifier<bool> monetizationEnabled = ValueNotifier(false);
  static bool get showPurchaseUi => monetizationEnabled.value || kDebugMode;

  /// Mode locks while purchases are on and the sheet gives no mode rules:
  /// none — KIDS gates per question via the `free` column instead.
  static const defaultRules = ContentAccessRules.allFree;

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

  static Future<void> init() async {
    ArkContent.instance.pricing.addListener(_applyPricing);
    _applyPricing();
    unawaited(PurchaseService.instance.configure(const PurchaseConfig(
      products: [PurchaseProduct(id: productId, entitlements: {entitlement})],
      requiredEntitlement: entitlement,
    )));

    await ArkAuth.instance.init(
      appId: 'kids',
      // Student IDs become <id>@students.arkacademy.top (the school's domain).
      config: const ArkAuthConfig(
        idDomain: 'students.arkacademy.top',
        supportContact: 'contact@arkacademy.top',
        accountDeletionUrl: 'https://arkacademy.top/arkbusters/privacy.html#delete',
      ),
      // TODO(client): DefaultFirebaseOptions.currentPlatform after running
      // `flutterfire configure`. Until then login is hidden and the app
      // plays fully offline.
      firebaseOptions: null,
      sync: ProgressSyncSpec([
        const SyncKey(ProgressKeys.playerName, MergeRule.lastWriteWins),
        const SyncKey(ProgressKeys.friends, MergeRule.union),
        const SyncKey(ProgressKeys.storySeen, MergeRule.lastWriteWins),
        const SyncKey(ProgressKeys.story2Seen, MergeRule.lastWriteWins),
        SyncKey.prefix(ProgressKeys.cards(''), MergeRule.union),
        SyncKey.prefix(ProgressKeys.sRankCount(''), MergeRule.max),
        const SyncKey.prefix('ark_best_', MergeRule.max),
        const SyncKey.prefix('lb2_', MergeRule.max), // listening level bests
        const SyncKey.prefix('eb2_', MergeRule.max), // sentence bests
        // ark_se / ark_voice / ark_bgm stay per device on purpose.
      ]),
    );
    // Progress pulled from the cloud (another device): refresh screens.
    ArkAuth.instance.sync?.onPulled = (_) => ProgressService.instance.notifyExternalChange();
  }

  /// Parent gate → paywall. Returns true when everything is unlocked.
  static Future<bool> openPaywall(BuildContext context) => showPaywall(
        context,
        requireParentGate: true,
        features: const [
          PaywallFeature('🎮', '4つの ゲームの ぜんぶの もんだい'),
          PaywallFeature('🆕', 'ふえていく あたらしい もんだいも あそべる'),
          PaywallFeature('💎', 'いちど かえば ずっと あそべる'),
        ],
        termsUrl: termsUrl,
        privacyUrl: privacyUrl,
        openUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      );
}
