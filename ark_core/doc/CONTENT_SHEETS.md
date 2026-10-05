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

- **新しい絵や音声は、ここだけでは追加できません。** 絵や録音が必要な問題は、ファイルを開発者に送ってください（アプリの更新が必要です）。文字だけの追加・修正はスプレッドシートだけでできます。
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

## 開発者向け：最初の1回だけの準備

1. **CSVを作る**（アプリに入っている問題をそのまま書き出します）

   ```
   cd ark_core
   dart run tool/sheets/export_sheets.dart ../ark_busters_kids/assets/data ../ark_busters_kids/tools/sheets
   ```

   `manifest.csv` と、問題ごとの CSV（`vocab.csv` など）ができます。
2. 学院のGoogleアカウントで新しいスプレッドシートを作り、
   - 最初のタブ名を `manifest` にして `manifest.csv` をインポート（ファイル → インポート → 現在のシートを置換）。
   - 問題ごとに新しいタブを作り、タブ名を `vocab` などにして各 CSV をインポート。
3. 各問題タブのURL末尾の `gid=数字` を、`manifest` の `gid` 列に書き込みます（`manifest` 自身の gid も控えておく）。
4. 共有 → 一般的なアクセス → **「リンクを知っている全員」・閲覧者** にします。
   （または ファイル → 共有 → ウェブに公開。こちらは反映まで数分かかります）
5. アプリの `assets/data/content_source.json` に ID を書きます：
   - 共有リンクの場合：URL `https://docs.google.com/spreadsheets/d/<ここ>/edit` の部分を `spreadsheetId` に
   - ウェブに公開の場合：公開URL `/d/e/<ここ>/pub` の部分を `publishedId` に
   - `manifestGid` に `manifest` タブの gid
6. この設定でアプリを1回リリースすれば、以後は問題の更新にアプリの更新は不要です。

## How it works (developers)

- `ArkContent` (`lib/src/content/ark_content.dart`): `loadPack(id)` returns the last downloaded pack that passes the app's validator, otherwise the bundled JSON — the app always works offline.
- `checkForUpdates()` reads the `manifest` tab (`pack, version, gid, minAppBuild`). For each pack whose remote `version` is higher than the local one it downloads that tab as CSV, rebuilds the pack with `rebuildPack` (bundled pack = template for settings, structure and value types), validates it (no empty question groups + the app's parser) and stores it in SharedPreferences. Failures keep the current questions; network errors are reported as offline. Throttled to every 30 min unless `force: true`.
- Sheet format (`lib/src/content/sheet_codec.dart`): one row per question; `_path` = the question array the row belongs to; nested fields as dotted columns (`answer.0.w`); empty cell = absent/null; lists compacted. Round-trip tested on all KIDS packs (`test/content`).
- `minAppBuild`: if a release changes the pack format, bump the app's content format build and set `minAppBuild` so older installs ignore the new data.
- New packs/apps (TEEN, future series) work the same way: register packs in `ArkContent.configure`, export CSVs with the tool, add tabs + manifest rows.
