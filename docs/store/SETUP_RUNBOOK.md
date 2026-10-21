# Setup runbook (developer side)

The school (藤井先生) is not technical, so **we operate every account**. The client only
(a) forwards 2-factor codes when asked and (b) accepts the agreements that only an
account owner can accept. Do the steps in order; each one says what it needs from the client.

Credentials the client gave us stay in a password manager, never in this repo or in chat logs.
Ask the client to change the passwords when the setup is finished.

| Step | Needs from the client | Result |
|---|---|---|
| 1. School Google account | nothing (uses the contact@ mailbox) | owner identity for Firebase + Sheet |
| 2. Google Sheet | nothing | questions editable without an app update |
| 3. Firebase | nothing | login, progress sync, paid voice clips |
| 4. Apple | 2FA code from 藤井先生's iPhone, once | App Store Connect access on our own Apple ID |
| 5. Google Play | login + 2FA code once, after 法人審査 | Play Console access on our account |
| 6. Builds | nothing | Android AAB from this VM; iOS via CI (Mac) |

---

## 1. A Google account for the school

Firebase, the question Sheet and the service-account keys should be owned by the school, not by
a personal account. Create a Google account **with the school mailbox** (no Gmail needed):

1. https://accounts.google.com/signup → 「代わりに現在のメールアドレスを使用」→ `contact@arkacademy.top`
2. Google sends a verification code to that mailbox → read it in ムームーメール webmail
   (https://muumuu-mail.com/ → login with the contact@ address).
3. Set a new password (ours, in the password manager) and **turn on 2-step verification with our own
   phone** so later logins do not depend on the client.

Use this account for steps 2 and 3. Add your personal Google account as an editor/owner too, so you
are never locked out.

## 2. Google Sheet (question updates)

Sheet: https://docs.google.com/spreadsheets/d/1hgSc4wg00QQhS-qJt7qhRSU5kuShRwj9UZXt9vjFyOE/edit

1. Regenerate the workbook from the imported bank (already done after the import; rerun if packs changed):
   ```
   cd ark_core
   dart run tool/sheets/export_sheets.dart ../ark_busters_kids/assets/data ../ark_busters_kids/tools/sheets
   dart run tool/sheets/export_sheets.dart ../ark_busters_teen/assets/data ../ark_busters_teen/tools/sheets
   python tool/sheets/make_workbook.py ../ARK_BUSTERS_questions.xlsx KIDS=../ark_busters_kids TEEN=../ark_busters_teen
   ```
2. In the Sheet: ファイル → インポート → アップロード → `ARK_BUSTERS_questions.xlsx` → **スプレッドシートを置換**.
3. Add a tab named `pricing` with the header row `app,item,value` and, for now, these rows
   (purchases stay off until the store products exist):
   ```
   kids,enabled,false
   teen,enabled,false
   ```
   To go live later: set both to `true`. TEEN additionally locks Lv2/3 by default; KIDS only hides paid questions.
4. 共有 → 一般的なアクセス → **リンクを知っている全員・閲覧者**. If the Sheet is owned by your personal
   account, also share it with the school account as editor (or move ownership).
5. Verify the apps read it as expected (the tab gids may change after a replace; the tool prints them):
   ```
   cd ark_core
   dart run tool/sheets/verify_sheet.dart ../ark_busters_kids/assets/data/content_source.json ../ark_busters_kids/assets/data
   dart run tool/sheets/verify_sheet.dart ../ark_busters_teen/assets/data/content_source.json ../ark_busters_teen/assets/data
   ```
   If it reports new gids, copy them into each app's `assets/data/content_source.json` (`manifestGid`, `tabs`).

## 3. Firebase (login, progress sync, paid voice clips)

One project shared by KIDS and TEEN. Do this logged in as the school account from step 1.

### 3.1 Create the project (console)

1. https://console.firebase.google.com → プロジェクトを追加 → name `ARK BUSTERS` → project id e.g. `ark-busters-app`
   (write the id down) → Google Analytics **off** → create.
2. 構築 → **Authentication** → 始める → ログイン方法 → **メール / パスワード** → 有効（メールリンクは無効）→ 保存.
3. 構築 → **Firestore Database** → データベースを作成 → ロケーション `asia-northeast1`（東京）→ **本番環境モード** → 作成.
4. 構築 → **Storage** → 始める → ロケーション `asia-northeast1` → 本番環境モード → 完了.
   Note the bucket name shown at the top (`gs://<name>`; new projects get `<project-id>.firebasestorage.app`).
5. ⚙ プロジェクトの設定 → サービス アカウント → **新しい秘密鍵を生成** → save the JSON as
   `ark_core/tool/students/service-account.json` (gitignored). This key is used by the student and media tools.

### 3.2 Register the apps and generate `firebase_options.dart`

On this VM (no browser): `firebase login --no-localhost` prints a URL; open it on any machine logged in
as the school account, paste the code back.

```
npm install -g firebase-tools
firebase login --no-localhost
dart pub global activate flutterfire_cli

cd ark_busters_kids
flutterfire configure --project=<project-id> --platforms=android,ios --android-package-name=top.arkacademy.kids --ios-bundle-id=top.arkacademy.kids --yes
cd ../ark_busters_teen
flutterfire configure --project=<project-id> --platforms=android,ios --android-package-name=top.arkacademy.teen --ios-bundle-id=top.arkacademy.teen --yes
```

This overwrites each app's `lib/firebase_options.dart` (currently a null stub) and adds
`android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`. The stores already pass
`DefaultFirebaseOptions.currentPlatform`, so **no code change is needed**: login appears in the apps
on the next build.

### 3.3 Rules, bucket, media

**Done 2026-10-21:** project `ark-busters` (Spark plan), Email/Password auth, Firestore (asia-northeast1), both apps
registered (Android + iOS), `firebase_options.dart` generated, Firestore rules deployed. Storage needs the Blaze plan,
so the paid clips are served by **Firebase Hosting** instead (`https://ark-busters.web.app`, set as `mediaBaseUrl`
in both apps). Deploy them with:

```
cd content/kids_voice
firebase deploy --only hosting
```

The rest of this section applies only after an upgrade to Blaze.


```
cd ark_core
firebase use <project-id>
firebase deploy --only firestore:rules,storage
```

Put the bucket name into both `assets/data/content_source.json`:

```json
"firebaseBucket": "<project-id>.firebasestorage.app",
"mediaFolder": "media"
```

Upload the paid-question voice clips (2,500 files, ~86 MB; skips files already there):

```
cd ark_core/tool/media
npm install
node upload_media.mjs ../../../content/kids_voice/paid --key ../students/service-account.json --bucket <project-id>.firebasestorage.app --dry-run
node upload_media.mjs ../../../content/kids_voice/paid --key ../students/service-account.json --bucket <project-id>.firebasestorage.app
```

Check one URL in a browser: `https://firebasestorage.googleapis.com/v0/b/<bucket>/o/media%2Faudio%2Fvoice%2Fvoca%2FKIDS_V_0201.mp3?alt=media` should play.

### 3.4 Student IDs

`ark_core/tool/students/README.md`: `node students.mjs create students.csv --key service-account.json`.
Create a few test IDs (e.g. `test001` / `test-2026`) for the store reviewers.

## 4. Apple (App Store Connect)

Apple Developer Program is in the organisation's name (enrolment was in review on 2026-10-14; check
https://developer.apple.com/account with the client's Apple ID). Logging in with the client's Apple ID
triggers a **6-digit code on 藤井先生's iPhone**: agree a time, log in, ask for the code in chat.
Do everything below in that one session so you never need the client's Apple ID again:

1. **Add yourself**: App Store Connect → ユーザとアクセス → ＋ → your own Apple ID, role **Admin**
   (Admin can create bundle IDs, certificates, apps, in-app purchases, offer codes and upload builds).
   Accept the invitation e-mail on your side. From here on, use your own Apple ID.
2. **Certificates, Identifiers & Profiles** (developer.apple.com/account): Identifiers → ＋ → App IDs
   → `top.arkacademy.kids` (ARK BUSTERS KIDS) and `top.arkacademy.teen`. Capabilities: In-App Purchase
   (on by default), Push off.
3. **Apps**: App Store Connect → マイApp → ＋ → 新規App → iOS, name `ARK BUSTERS KIDS – 英語バトル`,
   primary language 日本語, bundle id from step 2, SKU `arkbusters-kids`. Same for TEEN. Fill in the
   fields from `STORE_SETUP.md` (category, age rating, privacy labels, URLs).
4. **In-App Purchase**: each app → App内課金 → ＋ → 非消耗型, reference name `Full unlock`, product id
   `top.arkacademy.kids.full_unlock` / `top.arkacademy.teen.full_unlock`, price tier (client decides;
   ask them for a yen amount), localized name 「ぜんぶ解放」/「全ステージ解放」, review screenshot later.
5. **Offer codes** (for 塾生): the IAP → オファーコード → カスタムコード, e.g. `ARKJUKU2026`, 価格: 無料.
6. **Only the Account Holder can do**: 契約/税金/口座 → **有料Appの契約** (Paid Apps Agreement) → accept,
   bank account and tax forms. Walk the client through it on a call, or do it while logged in as the
   client (the Account Holder role cannot be transferred to you). Products cannot go live before this.
7. **Builds** need macOS: see step 6.

## 5. Google Play

Wait for the 法人書類審査 e-mail. Then, with the client's Play Console Google account (2FA code from the
client once):

1. ユーザーと権限 → ユーザーを招待 → your Google account → **管理者** permissions on all apps. Use your
   own account from then on.
2. アプリを作成 ×2: name, デフォルトの言語 日本語, アプリ, 無料 (purchases are in-app). Package names are
   fixed by the first upload (`top.arkacademy.kids` / `top.arkacademy.teen`).
3. **収益化の設定** → Google Payments マーチャント アカウントの作成: needs the business owner's details
   and bank account → do it with the client (owner-only, like Apple's agreement).
4. 収益化 → アプリ内アイテム → 作成: product ids as above, 非消耗型 (one-time), price.
5. プロモーション コード: 収益化 → プロモーション → one-time codes for 塾生 (quarterly limit applies).
6. 設定 → アプリの署名: keep **Play App Signing** on (upload key = our keystore from step 6).
7. Store listing / データセーフティ / コンテンツのレーティング from `STORE_SETUP.md`.
8. テスト → 内部テスト → upload the AAB, add tester e-mails (the client's Gmail) → share the link.

## 6. Builds

### Android (this VM)

```
keytool -genkey -v -keystore C:\keys\arkbusters-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Keep the .jks and its password in the password manager (losing it blocks future updates unless Play App
Signing resets it). Then in **each** app folder create `android/key.properties` (gitignored):

```
storeFile=C:/keys/arkbusters-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`android/app/build.gradle.kts` picks it up automatically (debug key when the file is absent).

```
cd ark_busters_kids && flutter build appbundle --release
cd ../ark_busters_teen && flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console → 内部テスト.
Bump `version:` in `pubspec.yaml` (`1.0.0+2`, `+3` …) before every upload.

### iOS (needs macOS)

No Mac here. Use **Codemagic** (free tier, Flutter workflow, App Store Connect integration via an API key
you create as Admin: ユーザとアクセス → 統合 → App Store Connect API → キーを生成, role App Manager) or any Mac
with Xcode: `flutter build ipa` → Transporter / `xcrun altool`. TestFlight → add the client as an
external tester (their Apple ID e-mail).

Before the first iOS build: `flutterfire configure` must have run (step 3.2) and
`ios/Runner/Info.plist` already contains the microphone / speech usage strings.

## 7. Turning purchases on

When the products exist on both stores and the agreements are accepted: set `pricing` →
`kids,enabled,true` / `teen,enabled,true` in the Sheet. No app update. Test with a sandbox tester (Apple)
/ license tester (Google) first; debug builds always show the purchase UI.
