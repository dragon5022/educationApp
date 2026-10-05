/// Japanese UI / error text for the purchase module. Every field can be
/// overridden per app (e.g. more kanji for TEEN).
class PurchaseStrings {
  const PurchaseStrings({
    this.paywallTitle = 'ぜんぶの ステージを あそぼう！',
    this.paywallLead = '1回の おかいもので、ずっと ぜんぶ あそべるよ。',
    this.oneTimeNote = '買い切り（1回のお支払いのみ）・月額料金はかかりません',
    this.buy = '購入する',
    this.buyWithPrice = '{price} で購入',
    this.restore = '購入を復元',
    this.redeem = 'コードを使う',
    this.close = 'とじる',
    this.terms = '利用規約',
    this.privacy = 'プライバシーポリシー',
    this.loadingPrice = '価格を確認しています…',
    this.alreadyUnlocked = 'ぜんぶ あそべるように なっているよ！',
    this.purchased = 'ありがとう！ ぜんぶ あそべるように なったよ！',
    this.restored = '購入を復元しました。ぜんぶ あそべます。',
    this.nothingToRestore = '復元できる購入が見つかりませんでした。購入したときと同じ Apple ID / Google アカウントでログインしているか確認してください。',
    this.pending = '承認待ちです。おうちの方の承認（「承認と購入のリクエスト」など）やお支払いが完了すると、自動でロックが解除されます。',
    this.canceled = '購入をキャンセルしました。',
    this.timeout = '処理に時間がかかっています。完了すると自動でロックが解除されます。',
    this.storeUnavailable = 'ストアに接続できません。インターネット接続を確認して、もう一度お試しください。',
    this.productNotFound = '商品情報を取得できませんでした。しばらくしてからもう一度お試しください。',
    this.network = '通信できませんでした。電波のよい場所で、もう一度お試しください。',
    this.genericError = '購入を完了できませんでした。もう一度お試しください。',
    this.notAllowed = 'この端末では購入が制限されています（スクリーンタイム／ペアレンタルコントロールの設定を確認してください）。',
    this.retry = 'もう一度',
    this.redeemTitle = 'コードを使う',
    this.redeemAndroidHelp = '塾などで受け取ったコードを入力して「Google Play でひらく」を押してください。Google Play で引き換えたあと、このアプリに戻るとロックが解除されます。',
    this.redeemAndroidManual = 'Google Play ストアアプリ → 右上のプロフィールアイコン → 「お支払いと定期購入」→「コードを利用」からコードを入力してください。引き換え後、このアプリに戻ると自動でロックが解除されます。',
    this.redeemOpenPlay = 'Google Play でひらく',
    this.redeemCodeHint = 'コード',
    this.redeemUnsupported = 'この端末ではコードを使えません。',
    this.urlCopied = 'URL をコピーしました。ブラウザに貼り付けてひらいてください。',
    this.debugBanner = 'DEBUG：ストア未接続のため購入をシミュレートします（リリース版では無効）',
    this.locked = 'ロック中',
  });

  final String paywallTitle;
  final String paywallLead;
  final String oneTimeNote;
  final String buy;

  /// `{price}` is replaced with the store's localized price string.
  final String buyWithPrice;
  final String restore;
  final String redeem;
  final String close;
  final String terms;
  final String privacy;
  final String loadingPrice;
  final String alreadyUnlocked;
  final String purchased;
  final String restored;
  final String nothingToRestore;
  final String pending;
  final String canceled;
  final String timeout;
  final String storeUnavailable;
  final String productNotFound;
  final String network;
  final String genericError;
  final String notAllowed;
  final String retry;
  final String redeemTitle;
  final String redeemAndroidHelp;
  final String redeemAndroidManual;
  final String redeemOpenPlay;
  final String redeemCodeHint;
  final String redeemUnsupported;
  final String urlCopied;
  final String debugBanner;
  final String locked;
}
