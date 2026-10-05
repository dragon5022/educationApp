import 'package:flutter/material.dart';

import 'auth_backend.dart';
import 'progress_sync.dart';

/// Look of the login sheet and account row. Defaults match ARK BUSTERS KIDS
/// (`.ark-sheet`: white, 4px gold border, radius 22, purple buttons).
class ArkAuthTheme {
  const ArkAuthTheme({
    this.sheetColor = Colors.white,
    this.borderColor = const Color(0xFFFFCF3D),
    this.borderWidth = 4,
    this.radius = 22,
    this.buttonColor = const Color(0xFF8B5CF6),
    this.buttonTextColor = Colors.white,
    this.titleColor = const Color(0xFF5B21B6),
    this.textColor = const Color(0xFF444444),
    this.hintColor = const Color(0xFF7A7390),
    this.errorColor = const Color(0xFFD9325E),
    this.fieldFill = const Color(0xFFF5F1FF),
    this.barrierColor = const Color(0x99140C2D),
    this.fontFamily = 'M PLUS Rounded 1c',
  });

  /// ARK BUSTERS KIDS default.
  static const kids = ArkAuthTheme();

  final Color sheetColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final Color buttonColor;
  final Color buttonTextColor;
  final Color titleColor;
  final Color textColor;
  final Color hintColor;
  final Color errorColor;
  final Color fieldFill;
  final Color barrierColor;

  /// Must be a font the app bundles; null inherits the app theme's font.
  final String? fontFamily;

  ArkAuthTheme copyWith({
    Color? sheetColor,
    Color? borderColor,
    double? borderWidth,
    double? radius,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? titleColor,
    Color? textColor,
    Color? hintColor,
    Color? errorColor,
    Color? fieldFill,
    Color? barrierColor,
    String? fontFamily,
  }) => ArkAuthTheme(
    sheetColor: sheetColor ?? this.sheetColor,
    borderColor: borderColor ?? this.borderColor,
    borderWidth: borderWidth ?? this.borderWidth,
    radius: radius ?? this.radius,
    buttonColor: buttonColor ?? this.buttonColor,
    buttonTextColor: buttonTextColor ?? this.buttonTextColor,
    titleColor: titleColor ?? this.titleColor,
    textColor: textColor ?? this.textColor,
    hintColor: hintColor ?? this.hintColor,
    errorColor: errorColor ?? this.errorColor,
    fieldFill: fieldFill ?? this.fieldFill,
    barrierColor: barrierColor ?? this.barrierColor,
    fontFamily: fontFamily ?? this.fontFamily,
  );

  TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color ?? textColor,
    height: 1.4,
  );
}

/// All user-facing strings (Japanese). Defaults are written for elementary
/// students (mostly hiragana); TEEN can pass [ArkAuthTexts.teen] or its own.
class ArkAuthTexts {
  const ArkAuthTexts({
    this.title = 'ログイン',
    this.lead =
        'じゅくで もらった IDと パスワードを いれてね。\n'
        'ログインすると、きろくが クラウドに セーブされるよ。',
    this.idLabel = 'ID',
    this.idHint = 'れい: ark001',
    this.passwordLabel = 'パスワード',
    this.showPassword = 'みる',
    this.hidePassword = 'かくす',
    this.loginButton = 'ログイン',
    this.playWithoutLogin = 'ログインしなくても あそべるよ',
    this.emptyFields = 'IDと パスワードを いれてね。',
    this.forgotTitle = 'パスワードを わすれたら？',
    this.forgotBody =
        'じゅくの せんせいに きいてね。\n'
        'メールで パスワードを おくることは できないよ。',
    this.deleteTitle = 'アカウントを けしたいときは',
    this.deleteBody =
        'アカウントと クラウドの きろくを けしたいときは、'
        'おうちの人から じゅくに つたえてね。じゅくが けしてくれるよ。\n'
        '（このアプリの なかの きろくは、アプリを けすと きえるよ）',
    this.signedInTitle = 'アカウント',
    this.signedInAs = 'ログインちゅうの ID',
    this.logoutButton = 'ログアウト',
    this.logoutNote = 'ログアウトしても、この たんまつの きろくは のこるよ。',
    this.closeButton = 'とじる',
    this.unavailableTitle = 'ログイン',
    this.unavailableBody =
        'いまは ログインできないよ。\n'
        'ログインしなくても ぜんぶ あそべるよ！',
    this.rowLabel = 'アカウント',
    this.rowSignedOut = 'ログインしていない',
    this.syncIdle = '',
    this.syncing = 'セーブちゅう…',
    this.synced = 'クラウドに セーブしたよ',
    this.syncPending = 'つながったら セーブするよ',
    this.syncError = 'あとで もういちど セーブするよ',
    this.errors = const {
      ArkAuthError.wrongIdOrPassword: 'IDか パスワードが ちがうみたい。もういちど たしかめてね。',
      ArkAuthError.disabled: 'この IDは いま つかえないよ。じゅくの せんせいに きいてね。',
      ArkAuthError.network: 'インターネットに つながっていないみたい。つながる ところで もういちど ためしてね。',
      ArkAuthError.tooManyAttempts: 'なんども まちがえたので、すこし まってから ためしてね。',
      ArkAuthError.invalidId: 'IDは えいご（ABC）と すうじ（123）で いれてね。',
      ArkAuthError.unavailable: 'いまは ログインできないよ。ログインしなくても あそべるよ！',
      ArkAuthError.unknown: 'うまく ログインできなかったよ。すこし まってから ためしてね。',
    },
  });

  /// ARK BUSTERS KIDS default.
  static const kids = ArkAuthTexts();

  /// Junior/senior high wording (kanji).
  static const teen = ArkAuthTexts(
    lead:
        '塾で配られたIDとパスワードを入力してください。\n'
        'ログインすると、記録がクラウドに保存されます。',
    idHint: '例: ark001',
    showPassword: '表示',
    hidePassword: '隠す',
    playWithoutLogin: 'ログインしなくても遊べます',
    emptyFields: 'IDとパスワードを入力してください。',
    forgotTitle: 'パスワードを忘れたら',
    forgotBody: '塾の先生に問い合わせてください。\nメールでの再設定はできません。',
    deleteTitle: 'アカウント削除の依頼',
    deleteBody:
        'アカウントとクラウド上の記録の削除を希望する場合は、'
        '保護者の方から塾へご連絡ください。塾が削除します。\n'
        '（端末内の記録はアプリを削除すると消えます）',
    signedInAs: 'ログイン中のID',
    logoutNote: 'ログアウトしても、この端末の記録は残ります。',
    closeButton: '閉じる',
    unavailableBody: '現在ログインは利用できません。\nログインしなくてもすべて遊べます。',
    rowSignedOut: '未ログイン',
    syncing: '保存中…',
    synced: 'クラウドに保存しました',
    syncPending: 'オンラインになったら保存します',
    syncError: 'あとで再度保存します',
    errors: {
      ArkAuthError.wrongIdOrPassword: 'IDかパスワードが違います。',
      ArkAuthError.disabled: 'このIDは現在使えません。塾の先生に問い合わせてください。',
      ArkAuthError.network: 'インターネットに接続できません。接続を確認してもう一度お試しください。',
      ArkAuthError.tooManyAttempts: '失敗が続いたため、しばらく待ってからお試しください。',
      ArkAuthError.invalidId: 'IDは半角英数字で入力してください。',
      ArkAuthError.unavailable: '現在ログインは利用できません。ログインしなくても遊べます。',
      ArkAuthError.unknown: 'ログインできませんでした。しばらく待ってからお試しください。',
    },
  );

  final String title;
  final String lead;
  final String idLabel;
  final String idHint;
  final String passwordLabel;
  final String showPassword;
  final String hidePassword;
  final String loginButton;
  final String playWithoutLogin;
  final String emptyFields;
  final String forgotTitle;
  final String forgotBody;
  final String deleteTitle;
  final String deleteBody;
  final String signedInTitle;
  final String signedInAs;
  final String logoutButton;
  final String logoutNote;
  final String closeButton;
  final String unavailableTitle;
  final String unavailableBody;
  final String rowLabel;
  final String rowSignedOut;
  final String syncIdle;
  final String syncing;
  final String synced;
  final String syncPending;
  final String syncError;
  final Map<ArkAuthError, String> errors;

  String error(ArkAuthError e) =>
      errors[e] ?? errors[ArkAuthError.unknown] ?? 'エラー';

  String syncState(SyncState s) => switch (s) {
    SyncState.idle => syncIdle,
    SyncState.syncing => syncing,
    SyncState.synced => synced,
    SyncState.pendingOffline => syncPending,
    SyncState.error => syncError,
  };
}
