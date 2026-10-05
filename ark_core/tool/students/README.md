# 生徒アカウント管理ツール（ARK BUSTERS）

塾が生徒用のログインIDを **CSV からまとめて作成・更新・無効化・削除** するためのツールです。
サーバーは不要で、管理者のパソコンから Firebase に直接つなぎます。

- 生徒はアプリで **ID とパスワードだけ** を入力します（例: `ark001`）。
- 内部では `ark001@students.ark-busters.app` というメールアドレス形式のアカウントになりますが、
  **実在のメールではありません**。メールは一切送信されません。
- パスワードを忘れた生徒には、このツールで新しいパスワードを設定してください（メールでの再設定はできません）。

---

## 1. 準備（最初の1回だけ）

1. **Node.js 18 以上** をインストールします（https://nodejs.org/ja ）。
2. このフォルダでコマンドプロンプト / PowerShell を開き、次を実行します。
   ```
   npm install
   ```
3. **サービスアカウントの鍵**（JSON ファイル）を用意します。
   1. Firebase コンソール → ⚙ プロジェクトの設定 → 「サービス アカウント」タブ
   2. 「新しい秘密鍵を生成」→ JSON ファイルがダウンロードされます
   3. 例: `service-account.json` という名前でこのフォルダに置きます

> ⚠ **鍵ファイルは管理者パスワードと同じくらい大切です。**
> メールで送ったり、共有フォルダや Git に置いたりしないでください（`.gitignore` 済み）。
> 漏れた場合は Firebase コンソールでその鍵を削除してください。

---

## 2. CSV の書き方

Excel で作成し、「**CSV UTF-8（コンマ区切り）**」で保存してください。1行目は見出しです。

```csv
id,password,display_name
ark001,hoshi-2026,山田 たろう
ark002,,佐藤 はなこ
ark003,umi-sora-77,
```

| 列 | 内容 |
|---|---|
| `id`（または `ID`） | ログインID。**半角英小文字・数字** と `. _ -`、先頭は英数字、64文字まで。大文字・全角は自動で小文字・半角になります |
| `password`（または `パスワード`） | **6文字以上**（8文字以上を推奨）。空欄なら既存の生徒はパスワードを変更しません |
| `display_name`（または `名前` / `表示名`） | 管理用の名前（任意）。アプリには表示されません。空欄なら変更しません |

`students.sample.csv` が見本です。

---

## 3. 使い方

### 作成・更新（`upsert`）
```
node students.mjs upsert students.csv --key service-account.json
```
- まだない ID → **新規作成**
- すでにある ID → パスワード（記入時のみ）と名前を **更新**、無効になっていたら **有効に戻す**
- 新しい生徒のパスワードを自動で作りたいとき（パスワード欄を空欄にして）:
  ```
  node students.mjs upsert students.csv --key service-account.json --generate-passwords
  ```
  → 結果 CSV の `generated_password` 列に、まぎらわしい文字（0/O, 1/l）を除いた10文字のパスワードが出ます。
  **生徒に配ったら、結果 CSV は安全に削除してください。**

### 無効化（退塾・一時停止）（`disable`） / 再有効化（`enable`）
```
node students.mjs disable students.csv --key service-account.json
node students.mjs enable  students.csv --key service-account.json
```
無効にすると、その ID ではログインできなくなります（「この IDは いま つかえないよ」と表示）。
クラウドの記録は残るので、`enable` で元に戻せます。`id` 列だけの CSV で大丈夫です。

### 完全削除（`delete`）
```
node students.mjs delete students.csv --key service-account.json --yes
```
ログインアカウントと **クラウド上の学習記録をすべて削除** します（元に戻せません）。
保護者から「アカウント削除の依頼」があったときに使ってください。
（生徒の端末に残っている記録は、アプリを削除すると消えます。）

### 一覧（`list`）
```
node students.mjs list --key service-account.json
```
ID・名前・有効/無効・作成日時・最終ログイン日時の CSV を出力します。

### 共通オプション
| オプション | 説明 |
|---|---|
| `--out 結果.csv` | 結果 CSV の保存先（省略時 `result-<コマンド>-<日時>.csv`） |
| `--domain students.ark-busters.app` | ID の後ろに付くドメイン。**アプリの設定（`ArkAuthConfig.idDomain`）と同じにしてください** |
| `--project <ID>` | Firebase プロジェクト ID（通常は鍵ファイルから自動） |
| `--emulator` | 本番ではなくローカルのエミュレーターに接続（テスト用） |

---

## 4. 結果 CSV

画面にも表示され、ファイルにも保存されます（Excel でそのまま開けます）。

| 列 | 内容 |
|---|---|
| `line` | 入力 CSV の行番号 |
| `id` / `uid` | ログインID / Firebase の内部ID |
| `action` | `created` / `updated` / `updated(password)` / `disabled` / `enabled` / `deleted` |
| `status` | `ok` または `error` |
| `message` | エラーの理由（日本語） |
| `generated_password` | `--generate-passwords` で作ったパスワード（それ以外のパスワードは出力しません） |

エラーが1件でもあると終了コード 2 になります。エラーの行だけ直して、もう一度同じ CSV で実行して大丈夫です（何度実行しても同じ結果になります）。

---

## 5. 動作確認（開発者向け）

本番プロジェクトを使わずに、エミュレーターで一通り確認できます（Java 11 以上が必要）。
```
npm run emulator          # 別のウィンドウで起動したままにする
node emulator_check.mjs   # 作成・ログイン・無効化・削除・セキュリティルールを自動チェック
```
