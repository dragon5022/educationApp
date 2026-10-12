# 音声・画像の追加（Firebase Storage）

文字だけの問題はスプレッドシートだけで追加・修正できます（`CONTENT_SHEETS.md`）。
**リスニングの音声（mp3）や新しい絵（webp / png）が必要な問題**は、ファイルを Firebase Storage に置くと、
アプリが自動でダウンロードして使います。アプリの更新・再申請は不要です。

---

## 藤井先生へ：音声や絵を追加する手順

1. ファイルを用意します。
   - 音声：mp3（例 `g5_0_17.mp3`）
   - 絵：webp か png（例 `211.webp`）
   - ファイル名は **半角英数字とアンダーバー**だけにしてください（日本語・スペース不可）。
2. Firebase コンソール（https://console.firebase.google.com）→ プロジェクト → **Storage** を開きます。
3. フォルダをたどって、ファイルをドラッグ＆ドロップします。置き場所はゲームごとに決まっています：

   | ゲーム | フォルダ | シートに書く値（例） |
   |---|---|---|
   | リスニングの音声 | `media/audio/voice/lis/` | `audio/voice/lis/g5_0_17.mp3` |
   | ボキャブラリーの音声 | `media/audio/voice/voca/` | `audio/voice/voca/211.mp3` |
   | ボキャブラリーの絵 | `media/images/vocab/` | `images/vocab/211.webp` |
   | トークの音声 | `media/audio/voice/talk/` | `audio/voice/talk/37.mp3` |
   | センテンスの音声 | `media/audio/voice/gram/` | `audio/voice/gram/43.mp3` |

   `media/` から下の道すじが、そのままシートの `voice` / `img` 列に書く値になります。
4. スプレッドシートの問題タブで、新しい行の `voice`（音声）や `img`（絵）の列に、上の「シートに書く値」を書きます。
5. `manifest` タブで、そのタブの `version` を 1 つ増やします。
6. アプリは次に開いたとき（インターネット接続時）に、新しい問題と一緒に音声・絵をダウンロードします。
   一度ダウンロードすれば、オフラインでも使えます。

### 注意
- 音声が無い問題は、アプリが英語を読み上げ音声で代用します（録音を用意するまでのつなぎにどうぞ）。
- 絵が無いボキャブラリーの問題は、絵の代わりに日本語が表示されます。
- 同じファイル名で置きかえても、すでにダウンロード済みの端末には反映されません。
  **直したいときは新しいファイル名にして、シートの値も変えてください。**
- ファイルが多いときは、開発者がまとめてアップロードすることもできます（下記）。

---

## 開発者向け

### 最初の1回の準備
1. Firebase プロジェクト（ログインと同じ）で **Storage** を有効にします（リージョン `asia-northeast1` 推奨）。
2. ルールを配信：`npx firebase-tools deploy --only storage`（`storage.rules`：`media/` は誰でも読める、書き込みはコンソール／管理ツールのみ）。
3. 各アプリの `assets/data/content_source.json` にバケット名を書きます：
   ```json
   "firebaseBucket": "<project-id>.appspot.com",
   "mediaFolder": "media"
   ```
   （Firebase 以外の置き場所なら `"mediaBaseUrl": "https://…/media"` でも可）
4. この設定でアプリを1回リリースします。

### まとめてアップロード
```
cd ark_core/tool/media
npm install
node upload_media.mjs <フォルダ> --key service-account.json [--dry-run]
```
`<フォルダ>/audio/voice/lis/x.mp3` → `media/audio/voice/lis/x.mp3`。同じ内容のファイルはスキップします。
サービスアカウントの鍵は `tool/students/README.md` と同じ手順で取得します（リポジトリに入れないこと）。

### 仕組み
- `ArkMedia`（`lib/src/content/ark_media.dart`）：パスを **同梱アセット → 端末キャッシュ → ダウンロード** の順に解決します。
  ダウンロードは Firebase SDK を使わず公開 URL への HTTPS なので、ログイン設定前でも動きます。
- 問題パックが更新されると、そのパックが参照する音声・絵のうち端末に無いものをバックグラウンドで先読みします
  （`ArkContent.configure(media: ArkMedia.instance)`）。起動時にも `ArkContent.prefetchMedia()` で取りこぼしを補います。
- アプリ側：`AudioService.playVoiceAsset()` が `ArkMedia.resolve()` を通して再生し、無ければ `fallbackText` を読み上げます。
  画像は `ArkMediaImage(path)` ウィジェットで表示します。
- キャッシュは `getApplicationSupportDirectory()/ark_media` 以下。`ArkMedia.clearCache()` で消せます。
