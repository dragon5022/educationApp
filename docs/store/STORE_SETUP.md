# ストア登録メモ（ARK BUSTERS KIDS / TEEN）

クライアント（アーク総合学院合同会社）の登録情報と、両ストアに入力する内容の下書き。
Apple Developer Program は組織名義で申請済み（2026-10-14 時点で審査中）。

## 会社情報（Apple に登録した内容）

| 項目 | 値 |
|---|---|
| 法人名 | ARK SOGO GAKUIN LIMITED LIABILITY COMPANY（アーク総合学院合同会社） |
| D-U-N-S | 739625265 |
| 住所 | 〒721-0963 広島県福山市南手城町2-13-19 |
| 電話 | +81 80-3899-7071 |
| Web | https://arkacademy.top/index.html |
| 連絡先メール | contact@arkacademy.top |

## アプリの識別子（確定：初回アップロード後は変更不可）

| | KIDS | TEEN |
|---|---|---|
| Bundle ID / Android package | `top.arkacademy.kids` | `top.arkacademy.teen` |
| ホーム画面の名前 | ARKキッズ | ARKティーン |
| ストアでの名前（30文字以内） | ARK BUSTERS KIDS – 英語バトル | ARK BUSTERS TEEN – 5教科バトル |
| アプリ内課金 商品ID（非消耗型） | `top.arkacademy.kids.full_unlock` | `top.arkacademy.teen.full_unlock` |
| 学習用IDのドメイン（Firebase） | `students.arkacademy.top` | 同左（同じFirebaseプロジェクト） |
| 利用規約 | https://arkacademy.top/arkbusters/terms.html | 同左 |
| プライバシーポリシー | https://arkacademy.top/arkbusters/privacy.html | 同左 |
| サポートURL | https://arkacademy.top/index.html | 同左 |
| 著作権表記 | © 2026 アーク総合学院合同会社 | 同左 |

`docs/store/site/arkbusters/` の `terms.html` / `privacy.html` を、サイトの `/arkbusters/` に**そのままの名前で**アップロードしてください（アプリ内のリンク先がこのURLです）。
文面は下書きです。公開前に内容の確認（できれば専門家のチェック）をおすすめします。

## App Store Connect に入力するもの

- **カテゴリ**：教育（KIDS は「子ども向け（6〜8歳 / 9〜11歳）」を選ぶか要判断。子ども向けカテゴリは審査が厳しくなる代わりに、保護者ゲートなどの対応はすでに実装済み）
- **年齢制限**：すべて「なし」→ 4+
- **App のプライバシー**（ニュートリションラベル）
  - 収集するデータ：「ユーザーID」「ゲームプレイのコンテンツ」（購入履歴はストアが扱うため不要）
  - 用途：「App の機能」のみ／ユーザーにリンク：はい（ログイン時）／トラッキングに使用：いいえ
  - マイク：トークバスターの発音チェックのみ。音声は端末外に送信しない（Info.plist に説明文あり）
- **App 内課金**：非消耗型、上記の商品ID、価格はクライアント決定。「購入を復元」は実装済み
- **オファーコード**：塾生向け。App Store Connect → App 内課金 → オファーコード
- **審査メモ**：ログインは任意（進み具合の保存のみ）、有料コンテンツの解放はApp内課金のみ、テスト用の学習用IDを記載

## Google Play Console に入力するもの

- **カテゴリ**：教育／コンテンツのレーティング：全ユーザー対象（アンケートに回答）
- **データセーフティ**：ユーザーID・アプリのアクティビティ（学習の進み具合）を収集、アプリ機能のため、暗号化して送信、削除依頼可（プライバシーポリシーの削除手順）
- **ファミリー向け**：KIDS を「ファミリー ポリシー」対象にするか要判断（広告なし・トラッキングなしなので要件は満たす）
- **アプリ内アイテム**：上記の商品ID（非消耗型）、価格
- **プロモーション コード**：塾生向け（四半期ごとに上限あり）

## 残りの作業（クライアント側）

1. Apple の組織審査の完了 → `tiger5247` を App Manager で招待
2. Google Play Console の作成（組織）→ 招待
3. 両ストアで有料App契約・税務情報・銀行口座
4. 価格、無料範囲（`pricing` タブ）、ファミリー共有の可否を決める
5. 有料版の問題データ
6. `terms.html` / `privacy.html` をサイトに設置
7. Firebase プロジェクト（ログイン・音声アップロード用）を学院の Google アカウントで作成 → 招待
8. 正式なアプリアイコン（現在は仮アイコン：KIDS = ボキャモン、TEEN = 星ロゴ）
