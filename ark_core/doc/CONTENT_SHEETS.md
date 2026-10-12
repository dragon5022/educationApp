# もんだいの追加・修正（Googleスプレッドシート）

アプリを入れ直したり、ストアに再申請したりせずに、問題を追加・修正できます。
問題はGoogleスプレッドシートで管理し、アプリはインターネットにつながったときに新しい問題を自動で取り込みます。

---

## 藤井先生へ：いつもの手順

1. 問題のスプレッドシートを開きます。
2. 問題のタブ（`vocab`、`listening` など）で、セルを直したり行を追加したりします。
3. 最後に **`manifest` タブで、直したタブの `version` を 1 つ増やします**（例：`3` → `4`）。
   これが「新しい問題がありますよ」という合図です。増やさないとアプリは取り込みません。
4. 完了です。アプリは次に開いたとき（インターネット接続時、30分に1回まで）に新しい問題を取り込み、**次のゲームから**使います。
   すぐ確認したいときは、アプリの「せってい → もんだいデータを こうしん」を押してください。

### 行を追加するとき

- いちばん簡単なのは、**似ている行をコピーして下に貼り付け、中身を書きかえる**方法です。
- `_path` 列（どのグループの問題か）は、コピー元と同じままにします。例：`grades.g5` = 5級、`grades.g4.levels.2` = 4級のレベル2。
- `id` は、ほかの行と重ならない値にしてください。

### 気をつけること

| やってよいこと | やってはいけないこと |
|---|---|
| セルの文字を直す・行を追加する・行を削除する | **1行目（列の名前）やタブの名前を変える** |
| 空いているセルはそのまま（「なし」の意味） | `_path` を存在しない名前にする |
| `_path` を空にした行は無視されるので、メモに使える | 数字の列（`lv` など）に文字を入れる |

- **新しい絵や音声**は、ファイルを Firebase Storage に置けば追加できます（アプリの更新は不要）。手順は `MEDIA.md` を見てください。音声が無い問題は、アプリが英語を読み上げます。
- まちがいがあっても、アプリはこわれません。読み込めないデータのときは**前の問題のまま**動き、「せってい」の更新ボタンに「こうしん できなかった もんだいが あります」と表示されます。
- 列の意味がわからないときは、すでにある行を見るか、開発者に聞いてください。

### KIDS の列の意味

| タブ | 主な列 |
|---|---|
| `vocab`（ボキャブラリー） | `w` 英単語 / `ja` 日本語 / `lv` 級（5・4・3） / `img` 絵 / `voice` 音声 |
| `listening`（リスニング） | `t` 種類 / `en` 読み上げる英文 / `ja` 日本語 / `q` しつもん（レベル3） / `ans` 正解 / `opts.0`・`opts.1` ほかの選択肢 / `tip` ポイント / `voice` 音声 |
| `talk`（トーク） | `ja` 日本語 / `en` 言う英語 / `voice` 音声 |
| `sentence`（センテンス） | `ja.0.t`… 日本語のかたまり（`pick` = 色をつけるか） / `answer.0.w`… 正しい順の英語（`label` = 誰が・どうする…） / `tip` ポイント / `voice` 音声 |

---

### 課金（有料・無料）の設定

`pricing` タブで決めます（`enabled` / `defaultFreeCount` など）。詳しくは `PURCHASE.md` の「無料・有料の範囲と課金のオン／オフ」。
このタブは `manifest` の version を上げなくても、アプリの次回起動時に反映されます。

## 開発者向け：最初の1回だけの準備

KIDS と TEEN は **1つのスプレッドシート** を共有します（各アプリは自分のタブだけ読みます）。
現在のシート：`https://docs.google.com/spreadsheets/d/1OC1COiGu30Au26VWBFMJIOra_XtqE_MzJifFjKOaA6E/edit`

1. **ブックを作る**（アプリに入っている問題をそのまま書き出し、1つの .xlsx にまとめます）

   ```
   cd ark_core
   dart run tool/sheets/export_sheets.dart ../ark_busters_kids/assets/data ../ark_busters_kids/tools/sheets
   dart run tool/sheets/export_sheets.dart ../ark_busters_teen/assets/data ../ark_busters_teen/tools/sheets
   python tool/sheets/make_workbook.py ../ARK_BUSTERS_questions.xlsx KIDS=../ark_busters_kids TEEN=../ark_busters_teen
   ```

   できるもの：`使い方` タブ、共通の `manifest` タブ、問題タブ 25 枚（全セル書式なしテキスト、2行目は列の説明）。
2. Googleスプレッドシートで **ファイル → インポート → アップロード → 「スプレッドシートを置換」** で .xlsx を読み込みます。
3. 共有 → 一般的なアクセス → **「リンクを知っている全員」・閲覧者** にします。
4. 確認：

   ```
   dart run tool/sheets/verify_sheet.dart ../ark_busters_kids/assets/data/content_source.json ../ark_busters_kids/assets/data
   dart run tool/sheets/verify_sheet.dart ../ark_busters_teen/assets/data/content_source.json ../ark_busters_teen/assets/data
   ```

   全部 ✓「same as the app」なら完了です。
5. 各アプリの `assets/data/content_source.json` には `spreadsheetId` が入っています。タブは**名前**で探すので gid の入力は不要です
   （`tabs` / `manifestGid` に gid を入れると少し速く・確実になります。`manifest` の `gid` 列でも指定可）。
   この設定でアプリを1回リリースすれば、以後の問題更新にアプリの更新は不要です。

## How it works (developers)

- `ArkContent` (`lib/src/content/ark_content.dart`): `loadPack(id)` returns the last downloaded pack that passes the app's validator, otherwise the bundled JSON — the app always works offline.
- `checkForUpdates()` reads the `manifest` tab (`pack, version`, optional `gid, minAppBuild`). Tabs are located by manifest `gid` → config `tabs` map → tab name (gviz, `headers=1`); a tab without a `_path` column (e.g. Google falling back to the first tab) is rejected. For each pack whose remote `version` is higher than the local one it downloads that tab as CSV, rebuilds the pack with `rebuildPack` (bundled pack = template for settings, structure and value types), validates it (no empty question groups + the app's parser) and stores it in SharedPreferences. Failures keep the current questions; network errors are reported as offline. Throttled to every 30 min unless `force: true`.
- Sheet format (`lib/src/content/sheet_codec.dart`): one row per question; `_path` = the question array the row belongs to; nested fields as dotted columns (`answer.0.w`); empty cell = absent/null; lists compacted. Round-trip tested on all KIDS packs (`test/content`).
- `minAppBuild`: if a release changes the pack format, bump the app's content format build and set `minAppBuild` so older installs ignore the new data.
- New packs/apps (TEEN, future series) work the same way: register packs in `ArkContent.configure`, export CSVs with the tool, add tabs + manifest rows.
