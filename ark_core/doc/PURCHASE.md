# アプリ内課金（買い切り）/ In-App Purchase — `package:ark_core/purchase.dart`

ARK BUSTERS KIDS / TEEN 共通の課金モジュールです。
**無料ダウンロード＋一部無料（体験）＋買い切り（非消耗型）1回でぜんぶ解放**。サブスクリプションは v1 では扱いません。

- Apple App内課金 / Google Play Billing のみ（外部決済リンクなし — App Store ガイドライン 3.1.1）
- 「購入を復元」ボタンあり（必須）
- KIDS は購入 UI の前に **保護者ゲート**（ガイドライン 1.3 キッズカテゴリ / Google Play ファミリー ポリシー）
- 塾向け：**Apple オファーコード**（iOS）／**Google Play プロモーションコード**（Android）で無料解放
- ログイン（Firebase）とは**連動させない**（ガイドライン 3.1.3(b) のリスク回避）。解放状態は端末にキャッシュしオフラインでも有効

---

## 1. アプリへの組み込み / Integrating in an app

```dart
import 'package:ark_core/purchase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await は任意。キャッシュ読込後すぐ isUnlocked が正しい値になる
  unawaited(PurchaseService.instance.configure(const PurchaseConfig(
    products: [
      PurchaseProduct(id: 'com.ark.kids.full_unlock', entitlements: {'kids_full'}),
      // 将来のシリーズパス例:
      // PurchaseProduct(id: 'com.ark.kids.series_pass', entitlements: {'kids_full', 'teen_full'}),
    ],
    requiredEntitlement: 'kids_full',      // TEEN は 'teen_full'
  )));
  runApp(const MyApp());
}

// 無料範囲（アプリごと）
final access = ContentAccess(rules: const ContentAccessRules(
  defaultFreeCount: 2,                      // 各パック/レベルの先頭2問は無料
  freeCounts: {'vocab': 5, 'listening/g3': 3},
  freePacks: {'talk'},
));

// メニュー
ListenableBuilder(listenable: access, builder: (context, _) => LockedOverlay(
  locked: access.isLocked('vocab', i, group: 'g3', itemFree: ContentAccess.itemFreeFlag(item)),
  onLockedTap: () => showPaywall(context,
    requireParentGate: true,              // KIDS は必ず true
    features: const [PaywallFeature('📚', 'ぜんぶの もんだい'), PaywallFeature('🎮', 'ぜんぶの ゲーム')],
    termsUrl: Uri.parse('https://…/terms'), privacyUrl: Uri.parse('https://…/privacy'),
    openUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication), // url_launcher（アプリ側で追加）
  ),
  child: card,
));
```

- 他モジュール（ログイン・進捗同期など）は `PurchaseService.instance.isUnlocked`（`ValueListenable<bool>`）または `entitlements`（`ValueListenable<Set<String>>`）を読むだけ。
- TEEN は `theme: PurchaseTheme.teen`（または独自の `PurchaseTheme`）と、必要なら `strings: PurchaseStrings(...)` で漢字多めの文言に差し替え。保護者ゲートは TEEN では任意（`requireParentGate: false`）。
- 保護者ゲート単体: `if (await showParentGate(context)) { … }`（外部リンクやレビュー依頼の前などにも使う）。
- アプリ起動時以外にも `PurchaseService.instance.refresh()` を呼べば最新化（Paywall 表示中はアプリ復帰時に自動で呼ばれます）。

### デバッグ / Debug
ストアに接続できない環境（Web・Windows・Play 未導入のエミュレータ等）の **debug/profile ビルド**では、
Paywall に赤い「DEBUG」バナーが出て、購入・復元・コードが**シミュレート**されます。
`PurchaseService.instance.debugSimulatePurchase()` / `debugReset()` も使えます。
**release ビルドでは常に無効**（`kReleaseMode`。シミュレートで保存された解放もリリース版では無視されます）。

---

## 2. App Store Connect の設定（クライアント作業）

1. **契約・税務・口座**：App Store Connect →「ビジネス」で *有料 App 契約 (Paid Applications Agreement)* に同意し、銀行口座・税務情報（米国税務 W-8BEN 等）を登録。**これが「有効」になるまで課金アイテムは取得できません。**
2. **App内課金の作成**：アプリ →「App内課金」→ ＋ →種類 **「非消耗型 (Non-Consumable)」**
   - 製品ID：例 `com.ark.kids.full_unlock`（TEEN は `com.ark.teen.full_unlock`）。**後から変更・再利用不可**。
   - 参照名、価格（価格帯）、表示名・説明（日本語）、審査用スクリーンショット（Paywall の画面）、審査メモ。
   - ファミリー共有：ON 推奨（家族で使える。要判断）。
   - 最初の課金アイテムは**アプリのバージョンと一緒に審査提出**します（バージョン画面の「App内課金」に追加）。
3. **キッズカテゴリ**（KIDS）：年齢区分を設定。保護者ゲートの位置（購入・外部リンク前）を審査メモに記載。
4. **Sandbox テスター**：「ユーザとアクセス」→「Sandbox」→テスター追加（未使用のメールアドレス）。
   iPhone の「設定 → App Store → Sandbox アカウント」でサインインしてテスト。TestFlight でも購入テスト可（課金されません）。
5. **オファーコード（塾向け）**：アプリ →「App内課金」→ 対象商品 →「オファーコード」→ オファー作成 → **ワンタイムコード**（CSV で発行、1 コード 1 回）または **カスタムコード**（例 `ARKJUKU2026`、利用回数上限あり）。価格は「無料」。
   - ✅ **2025年より非消耗型でもオファーコードが利用可能**（消耗型・非消耗型・非更新サブスクに拡大。iOS 18.4 で導入、**iOS 16.3 以降で利用可**）。
   - 引き換え方法：アプリ内の「コードを使う」（システムのコード入力シート）／App Store アプリのアカウント画面／引き換え URL `https://apps.apple.com/redeem?ctx=offercodes&id=<AppleID>&code=<CODE>`。
   - 引き換え結果は通常の購入としてアプリに届き、自動で解放されます（このモジュールが処理）。
   - 四半期ごとの発行上限・有効期限があるので、塾への配布計画とあわせて確認してください。Sandbox でのオファーコード検証は制約があるため、**TestFlight / 本番前の少量配布で動作確認**を推奨。

### ローカルテスト（StoreKit Configuration File）
`doc/ArkBusters.storekit` を Xcode プロジェクト（`ios/Runner`）にドラッグして追加 →
Xcode の *Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration* で選択 → Xcode から実行。
App Store Connect 未設定でも購入・キャンセル・Ask to Buy（承認待ち）・エラーを試せます
（Xcode の *Debug → StoreKit → Manage Transactions* で返金・削除も可能）。
ファイルが読み込めない場合は Xcode の *File → New → File → StoreKit Configuration File* で作り直し、同じ製品IDを入れてください。

---

## 3. Google Play Console の設定（クライアント作業）

1. **お支払いプロファイル**（販売者アカウント）を作成し、銀行口座・税務情報を登録。
2. アプリに **`com.android.vending.BILLING` 権限を含む AAB を内部テストトラックにアップロード**（Flutter の `in_app_purchase` を入れると自動で含まれます）。これをしないと商品を作れません。
3. **収益化 → 商品 → アプリ内アイテム**（一回限りの商品）→ 作成。
   - 商品ID：iOS と**同じ ID** を推奨（`com.ark.kids.full_unlock`）。価格・名前・説明を入力し「有効」にする。
4. **ライセンス テスター**：「設定 → ライセンス テスト」にテスト用 Google アカウントを追加（テストカードで課金されずに購入可）。内部テストのテスター登録も行い、Play ストア経由でインストールしてテスト。
   - 「テスト用カード（承認が遅れる）」で**保留中 (PENDING)** の動作も確認できます。
5. **プロモーションコード（塾向け）**：収益化 →「プロモーション」→ プロモーションコードを作成 → 対象をアプリ内アイテムに。
   - 1 四半期あたり最大 500 コード（Google の上限、変更される可能性あり）。
   - ユーザーは Play ストアの「お支払いと定期購入 → コードを利用」または `https://play.google.com/redeem?code=<CODE>` で引き換え。アプリの「コードを使う」はコード入力欄つきでこの URL を開きます（`openUrl` 未指定時は URL をコピーし、手順を表示）。
   - 引き換えた購入はアプリ復帰時／次回起動時に検出・確認（acknowledge）され解放されます。
6. **ファミリー ポリシー**（KIDS）：対象年齢・広告・データ取扱いを申告。

---

## 4. 実装メモ / Behaviour notes (English)

- **Entitlements**: products map to entitlement keys; an app unlocks when it owns `requiredEntitlement`. A future series pass is just another product granting several entitlements. **Note:** store purchases belong to one app (bundle ID / package). Sharing one purchase across the KIDS and TEEN apps requires either a single app or an account-based server entitlement (login) — see open questions.
- **Offline**: owned products are cached in SharedPreferences (`PurchaseConfig.storageKey`) after a verified purchase/restore and loaded before the store is contacted. Network errors never revoke. On Android, Play's owned-purchase list is authoritative and refunded items are revoked (`revokeWhenStoreSaysNotOwned`). On iOS, a restore that finds nothing does **not** revoke.
- **Transactions**: every update with `pendingCompletePurchase` is completed (iOS `finishTransaction`, Android acknowledge — Play refunds unacknowledged purchases after 3 days). Purchases rejected by `PurchaseConfig.verifier` are left unfinished so the store re-delivers them.
- **Pending** (Ask to Buy / Play pending payments): `buy()` returns `pending`; the unlock happens automatically when the store later reports it.
- **Errors**: mapped to Japanese messages (`PurchaseStrings`) with a retry button. `ITEM_ALREADY_OWNED` → re-sync and treat as owned.
- **Security**: v1 trusts the on-device plugins (StoreKit 2 signed transactions / Play Billing). For server verification later, set `PurchaseConfig.verifier` (e.g. a Cloud Function calling the App Store Server API / Google Play Developer API).
- **Parent gate**: random adult-level question (5-digit number written in kanji with 万, or 2-digit × 2-digit multiplication), shuffled on-screen keypad, no "remember me", can't be dismissed by tapping outside, 30 s lockout after 3 wrong answers that persists across reopening.

## 5. クライアントへの確認事項 / Open questions
1. KIDS と TEEN を別売りにするか、1 回の購入で両方を解放するか（両方解放にはログイン連携＝サーバー側の権利管理が必要。v1 方針と要調整）。
2. 価格（価格帯）、無料範囲（各レベルの何問まで無料か / `free` 列で個別指定するか）。
3. ファミリー共有を ON にするか。
4. 塾への配布方法（Apple ワンタイムコード CSV / カスタムコード、Play プロモーションコードの四半期上限）。
5. 利用規約・プライバシーポリシーの URL。

## 無料・有料の範囲と課金のオン／オフ（Googleスプレッドシート `pricing` タブ）

課金を有効にするかどうか、どこまで無料で遊べるかは、問題データと同じスプレッドシートの
**`pricing` タブ**で決めます。アプリの更新は不要で、アプリの次回起動時（オンライン時）に反映されます。

| app | item | value | 意味 |
|---|---|---|---|
| kids / teen | `enabled` | `true` / `false` | 課金を有効にする。`false` のあいだは全部無料（カギなし） |
| kids / teen | `defaultFreeCount` | 数字 | ゲーム（ステージ）ごとに無料で遊べるモード（レベル）の数。`0` = 全部有料 |
| kids / teen | `freeCounts.<タブ名>` | 数字 | そのタブだけ別の数（例 `freeCounts.vocab` = `2`、`freeCounts.listening/g5` = `3`） |
| kids / teen | `freePacks` | タブ名（カンマ区切り） | 全部無料にするタブ |
| kids / teen | `lockedPacks` | タブ名（カンマ区切り） | 全部有料にするタブ |

- 行が無い／タブが無い場合、アプリは内蔵のデフォルト（課金オフ・各ゲーム最初のモードを無料）で動きます。
- 購入済みの端末では、設定に関係なく全部遊べます。
- 開発者向け: `ark_core/lib/src/content/pricing_sheet.dart` が行を `ContentAccessRules.fromJson` の形に変換し、
  `ArkContent.instance.pricing` に入ります。各アプリの `KidsStore` / `TeenStore` がそれを `ContentAccess.updateRules` に渡します。
  デバッグビルドでは `enabled` に関係なく購入 UI が表示され、ストアが無い環境では購入がシミュレーションされます。
