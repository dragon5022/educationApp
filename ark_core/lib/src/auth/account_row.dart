import 'package:flutter/material.dart';

import 'ark_auth.dart';
import 'auth_theme.dart';
import 'login_sheet.dart';

/// One line for a settings/profile panel: “アカウント   ark001  [かくにん]”
/// or “アカウント   ログインしていない  [ログイン]”. Tapping opens
/// [ArkLoginSheet]. Hidden when login is unavailable unless
/// [showWhenUnavailable] is true.
class ArkAccountRow extends StatelessWidget {
  const ArkAccountRow({
    super.key,
    this.auth,
    this.theme = ArkAuthTheme.kids,
    this.texts = ArkAuthTexts.kids,
    this.showWhenUnavailable = false,
    this.onTap,
    this.signedInButton = 'かくにん',
  });

  final ArkAuth? auth;
  final ArkAuthTheme theme;
  final ArkAuthTexts texts;
  final bool showWhenUnavailable;
  final String signedInButton;

  /// Overrides opening [ArkLoginSheet].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = auth ?? ArkAuth.instance;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) {
        if (!a.isAvailable && !showWhenUnavailable) {
          return const SizedBox.shrink();
        }
        final open =
            onTap ??
            () => ArkLoginSheet.show(
              context,
              auth: a,
              theme: theme,
              texts: texts,
            );
        final String value;
        final String button;
        if (a.isSignedIn) {
          value = a.currentId ?? '';
          button = signedInButton;
        } else if (a.isAvailable) {
          value = texts.rowSignedOut;
          button = texts.loginButton;
        } else {
          value = texts.rowSignedOut;
          button = texts.unavailableTitle;
        }
        final style = theme.text(size: 14, color: const Color(0xFF444444));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(texts.rowLabel, style: style),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  key: const ValueKey('ark-account-row-value'),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              ArkAuthButton(
                label: button,
                theme: theme,
                compact: true,
                onTap: open,
              ),
            ],
          ),
        );
      },
    );
  }
}
