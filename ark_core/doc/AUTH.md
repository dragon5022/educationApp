# ログイン & 進捗同期 / Login & progress sync (`package:ark_core/auth.dart`)

ARK BUSTERS シリーズ（KIDS / TEEN / 今後のアプリ）共通のログインモジュールです。
Shared login module for the ARK BUSTERS series (KIDS, TEEN and future apps).

- **ログイン方法 / Login**: 塾が発行する **ID + パスワード**（新規登録・SNSログインなし）
  School-issued **ID + password** only (no sign-up, no social login).
- **目的 / Purpose (v1)**: 学習記録をクラウドに保存し、機種変更・再インストール後も復元し、シリーズのアプリ間で1つのアカウントを共有する。
  Save progress to the cloud, survive device changes/reinstalls, share one account across the series.
- **ログインで有料コンテンツは解放しません / Login never unlocks paid content** (App Store 3.1.3(b)). 購入は別モジュール（`purchase.dart`）です。
- **ログインしなくても全部遊べます / Fully playable without login** — オフラインファースト。
- バックエンド: Firebase Auth（メール/パスワード）+ Cloud Firestore。サーバーコードなし。

---

## 1. 日本語ガイド

### 1.1 クライアント（塾）が行う Firebase のセットアップ

1. **プロジェクト作成**: https://console.firebase.google.com →「プロジェクトを追加」
   （例: `ark-busters`）。Google アナリティクスは **無効** にしてください（子ども向けのため）。
2. **Authentication を有効化**: 構築 → Authentication → 始める →「ログイン方法」→ **メール / パスワード** を有効
   （「メールリンク」は無効のまま）。
   - 設定 →「ユーザー アクション」→ **「作成（登録）を有効にする」をオフ**、**「削除を有効にする」をオフ**
     （アプリからのアカウント作成・削除を禁止し、塾のツールからのみ管理する）。
   - 設定 →「パスワード ポリシー」: 必要なら最小文字数を設定（ツールは6文字以上を要求）。
3. **Firestore を作成**: 構築 → Firestore Database → データベースを作成 →「本番環境モード」、
   ロケーションは `asia-northeast1`（東京）を推奨。
4. **セキュリティルールのデプロイ**（ark_core フォルダで）:
   ```
   npx firebase-tools login
   npx firebase-tools deploy --only firestore:rules --project <プロジェクトID>
   ```
   （または Firestore →「ルール」タブに `firestore.rules` の内容を貼り付けて公開）
5. **各アプリを登録**（アプリごとに1回。KIDS と TEEN は **同じプロジェクト** に登録します）:
   ```
   dart pub global activate flutterfire_cli
   cd ark_busters_kids
   flutterfire configure --project=<プロジェクトID> --platforms=android,ios
   ```
   → `lib/firebase_options.dart` と `android/app/google-services.json`、`ios/Runner/GoogleService-Info.plist` が作られます。
   アプリ側で `DefaultFirebaseOptions.currentPlatform` を `ArkAuth.instance.init` に渡せば有効になります（2章）。
6. **生徒アカウントの作成**: `tool/students/README.md` の手順で CSV から作成します。
7. **(任意) App Check**: 不正なクライアントからのアクセスを防ぐため、後から有効化を検討してください（v1 では未使用）。

> `firebase_options.dart` がまだ無い間は、`firebaseOptions: null` を渡してください。
> モジュールは「利用不可」になり、ログイン欄は非表示（またはやさしいメッセージ）になり、アプリは通常どおりオフラインで動きます。

### 1.2 パスワードを忘れたとき
メールアドレスは実在しないため、**メールでの再設定はできません**。
アプリには「じゅくの せんせいに きいてね」と表示されます。塾は `tool/students` の `upsert` で新しいパスワードを設定します。

### 1.3 アカウント削除の依頼
アカウントはアプリ内で **作成できない**（塾が発行する）ため、Apple の「アプリ内アカウント削除」義務（App Store Review Guideline 5.1.1(v)）の対象外と考えられますが、
利用者が削除を依頼できる経路をアプリ内に用意しています。
- ログイン画面の「アカウントを けしたいときは」に、塾へ依頼する方法を表示します
  （`ArkAuthConfig.supportContact` / `accountDeletionUrl` で連絡先・案内ページを表示可能）。
- 塾は `node students.mjs delete <csv> --yes` で **ログインアカウントとクラウド上の記録をすべて削除** します。
- App Store Connect の審査メモ・プライバシーポリシーにも同じ手順を記載してください。
- アプリ内の記録（端末内）はアプリの削除で消えます。

### 1.4 プライバシー（キッズカテゴリー向け）
- 収集するのは **ログインID** と、アプリが指定した **進捗キーの値**（友だちになったモンスター、カード、ベストスコア、ニックネーム等）だけです。
- 本名・メールアドレス・端末ID・位置情報は収集しません。`display_name` は塾の管理用で Auth にのみ保存され、アプリには送られません。
- アナリティクス・広告 SDK は使用しません（Firebase Analytics も追加しないでください）。
- データは Firestore の `users/{uid}/apps/{appId}` に保存され、セキュリティルールで **本人だけ** が読み書きできます。
- App Store の「App のプライバシー」: 「ユーザー ID」「その他のユーザーコンテンツ（ゲームの進行状況）」を **App の機能** 目的・トラッキングなしとして申告してください。

---

## 2. Integration (English)

### 2.1 App code (~10 lines)

```dart
import 'package:ark_core/auth.dart';
// import 'firebase_options.dart'; // after `flutterfire configure`

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ArkAuth.instance.init(
    appId: 'kids',                  // 'teen' for ARK BUSTERS TEEN
    firebaseOptions: null,          // DefaultFirebaseOptions.currentPlatform
    sync: kidsSyncSpec,             // see 2.2
    config: const ArkAuthConfig(supportContact: 'ARK BUSTERS 事務局'),
  );
  ArkAuth.instance.sync?.onPulled = (_) => refreshProgressUi(); // optional
  runApp(const App());
}

// Settings / profile panel:
const ArkAccountRow();                       // hidden when unavailable
// Anywhere:  ArkLoginSheet.show(context);    // TEEN: texts: ArkAuthTexts.teen
// After saving progress (optional, debounced): ArkAuth.instance.notifyProgressChanged();
```

`init` never throws. Without options (or if Firebase fails to start) `status == ArkAuthStatus.unavailable`,
`ArkAccountRow` renders nothing, `ArkLoginSheet` shows “いまは ログインできないよ。ログインしなくても ぜんぶ あそべるよ！”
and the app keeps using SharedPreferences exactly as before.

### 2.2 Which keys sync (KIDS example)

```dart
const kidsSyncSpec = ProgressSyncSpec([
  SyncKey('ark_name', MergeRule.lastWriteWins),      // nickname
  SyncKey('ark_friends', MergeRule.union),           // '["vocamon",...]'
  SyncKey('ark_story_seen', MergeRule.max),          // '0'/'1' – sticky once seen
  SyncKey('ark_story2_seen', MergeRule.max),
  SyncKey.prefix('ark_cards_', MergeRule.union),     // '[1,5,9]'
  SyncKey.prefix('ark_s_', MergeRule.max),           // S-rank counters (int)
  SyncKey.prefix('ark_best_', MergeRule.max),        // best scores (int)
  SyncKey.prefix('lb2_', MergeRule.max),             // listening bests ('120')
  SyncKey.prefix('eb2_', MergeRule.max),             // sentence bests ('40')
]);
// Not synced on purpose: ark_se, ark_voice, ark_bgm (per-device sound settings).
```

Rules: an exact `SyncKey` beats a prefix; the longest prefix wins. Keys starting with `ark_core_` are reserved.
`SyncKey(...)` without a rule uses `MergeRule.auto`.

### 2.3 API summary

| API | |
|---|---|
| `ArkAuth.instance` / `ArkAuth()` | `ChangeNotifier`. `status` (`initializing`/`unavailable`/`signedOut`/`signedIn`), `isAvailable`, `isSignedIn`, `isBusy`, `currentId` (`'ark001'`), `user`, `sync`, `config` |
| `init({appId, firebaseOptions, sync, config, switchPolicy})` | Optional Firebase; enables Firestore offline persistence |
| `initWithBackends({appId, backend, remote, sync, ...})` | Custom/fake backends (tests, emulator). `backend: null` = unavailable |
| `login(id, password)` → `ArkLoginResult` | `ok` / `error` (`ArkAuthError.wrongIdOrPassword`, `disabled`, `network`, `tooManyAttempts`, `invalidId`, `unavailable`, `unknown`) |
| `logout()` | Final sync (≤10 s), then sign out. Device progress is kept |
| `notifyProgressChanged()` / `syncNow()` | Debounced (3 s) / immediate sync |
| `emailForId(id)` / `idForEmail(email)` / `ArkAuth.normalizeId` | `ark001` ↔ `ark001@<idDomain>`; full-width input accepted |
| `ArkAuthConfig(idDomain, supportContact, accountDeletionUrl)` | Default domain `students.ark-busters.app` |
| `ArkLoginSheet` / `ArkLoginSheet.show(context, theme:, texts:)` | Login / account sheet |
| `ArkAccountRow(theme:, texts:, showWhenUnavailable:, onTap:)` | Settings/profile row |
| `ArkAuthTheme` (`.kids`, `copyWith`) / `ArkAuthTexts` (`.kids`, `.teen`) | Look & Japanese strings |
| `ProgressSync` | `state` (`idle`/`syncing`/`synced`/`pendingOffline`/`error`), `lastSyncedAt`, `lastError`, `onPulled` |
| `ProgressSyncSpec`, `SyncKey`, `MergeRule` (`max`, `union`, `lastWriteWins`, `auto`, `custom`) , `planMerge` | Merge engine (pure Dart) |
| `ProgressRemote`, `ArkAuthBackend`, `LocalProgressStore` | Interfaces for fakes / other backends |

### 2.4 Data model

```
users/{uid}                     reserved (clients cannot write it)
users/{uid}/apps/{appId}        appId: 'kids', 'teen', … ([a-z0-9_-]{1,32})
  schema:    1
  entries:   { "<prefs key>": { v: <value>, t: <ms since epoch, client clock> }, … }
  updatedAt: <server timestamp>
```
`v` keeps the SharedPreferences type (String, int, double, bool, List<String>).
Each app has its own document, so key names never collide between apps; the account (uid) is shared.
On the device, ark_core keeps one bookkeeping key `ark_core_sync_meta` (owner uid + last-seen value hash and time per key).

### 2.5 Merge rules (never lose progress)

| Rule | Behaviour | Typical keys |
|---|---|---|
| `max` | larger number wins; ints, doubles and numeric strings (`'120'`) | best scores, S-rank counters, `*_seen` flags |
| `union` | union of JSON arrays / `List<String>`; cloud order first, then device-only items | `ark_friends`, `ark_cards_*` |
| `lastWriteWins` | newest `t` wins (tie → device) | `ark_name` |
| `auto` (default) | arrays → union, numbers → max, else last-writer-wins | |
| `custom((local, remote) => …)` | your function | |

- A key present on only one side is copied to the other — **a missing key never deletes data**
  (so resetting progress locally is undone by the next sync; a reset must be done via the admin tool `delete`).
- `t` is the time this device *noticed* a change (value differs from the last sync) — good enough for LWW.
- The merged value is coerced to the device's existing type (cloud `120` → local `'120'`).
- Unparseable values fall back to last-writer-wins; the merge never throws.
- Limitation: `max` on counters (e.g. `ark_s_*`) cannot add increments made offline on two devices
  at the same time (5→7 and 5→6 merge to 7). Acceptable for v1.

### 2.6 When sync runs & offline behaviour

- **On login** (and when a saved session is restored at app start), **on app resume**, **on app pause**
  (flush), **3 s after `notifyProgressChanged()`**, and on `syncNow()`/`logout()`.
- Firestore offline persistence is on. Offline: reads come from the cache; writes are queued on the
  device and sent automatically. `ProgressSync.state` becomes `pendingOffline` (write queued) or `error`
  (cloud unreachable) and a **retry** is scheduled (30 s, 60 s, … up to 10 min). Device progress is
  never reduced by a failed sync.
- **Account switch**: if this device's progress was last synced with a *different* account, the new
  account's cloud progress replaces it (the old progress is already saved under the old account).
  Progress played as a guest (never synced) is merged into the first account that logs in.
  Use `switchPolicy: AccountSwitchPolicy.alwaysMerge` to always merge instead.
- **Logout** keeps device progress (the child keeps playing offline).

### 2.7 Admin tooling, rules, emulator

- `tool/students/` — Node + firebase-admin: `upsert` / `disable` / `enable` / `delete` / `list` from a CSV, result CSV, Japanese README.
- `firestore.rules` — own documents only; field whitelist; server `updatedAt`; no client delete; everything else closed.
- `firebase.json` — rules path + emulator ports (auth 9099, firestore 8080).
- Local end-to-end check (Java 11+): `cd tool/students && npm install && npm run emulator`, then `node emulator_check.mjs`.

### 2.8 Tests
`flutter test test/auth` — merge rules, `ProgressSync` against an in-memory remote and mocked
SharedPreferences (reinstall restore, two-device convergence, offline/retry, account switch, debounce),
`ArkAuth` with Firebase unavailable and with a fake auth backend, and widget tests for the login sheet.
