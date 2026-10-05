import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/pressable.dart';
import 'ark_auth.dart';
import 'auth_theme.dart';

/// The login / account sheet. Shows, depending on [ArkAuth.status]:
/// - unavailable → a friendly “ログインしなくても あそべるよ” message
/// - signed out  → ID + password form, “ログインしなくても あそべるよ”, help
/// - signed in   → the logged-in ID, sync state, ログアウト, help
class ArkLoginSheet extends StatefulWidget {
  const ArkLoginSheet({
    super.key,
    this.auth,
    this.theme = ArkAuthTheme.kids,
    this.texts = ArkAuthTexts.kids,
    this.onClose,
  });

  /// Defaults to [ArkAuth.instance].
  final ArkAuth? auth;
  final ArkAuthTheme theme;
  final ArkAuthTexts texts;

  /// Called by the close / “ログインしなくても” buttons. Defaults to popping.
  final VoidCallback? onClose;

  /// Opens the sheet as a dialog over the current screen (same transition as
  /// the KIDS `ArkPanel`).
  static Future<void> show(
    BuildContext context, {
    ArkAuth? auth,
    ArkAuthTheme theme = ArkAuthTheme.kids,
    ArkAuthTexts texts = ArkAuthTexts.kids,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: texts.closeButton,
      barrierColor: theme.barrierColor,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) =>
          ArkLoginSheet(auth: auth, theme: theme, texts: texts),
      transitionBuilder: (_, anim, _, child) {
        final t = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(t),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ArkLoginSheet> createState() => _ArkLoginSheetState();
}

class _ArkLoginSheetState extends State<ArkLoginSheet> {
  late final ArkAuth _auth = widget.auth ?? ArkAuth.instance;
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _pwFocus = FocusNode();
  bool _showPw = false;
  String? _error;
  _Help? _help;

  ArkAuthTheme get _t => widget.theme;
  ArkAuthTexts get _x => widget.texts;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _login() async {
    if (_auth.isBusy) return;
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = _x.emptyFields);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final r = await _auth.login(_id.text, _pw.text);
    if (!mounted) return;
    setState(() {
      _error = r.ok ? null : _x.error(r.error!);
      if (r.ok) _pw.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: (size.height - inset) * 0.86,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: _t.sheetColor,
                    borderRadius: BorderRadius.circular(_t.radius),
                    border: Border.all(
                      color: _t.borderColor,
                      width: _t.borderWidth,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        offset: Offset(0, 12),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      (_t.radius - _t.borderWidth).clamp(0, _t.radius),
                    ),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          child: ListenableBuilder(
                            listenable: Listenable.merge([_auth, ?_auth.sync]),
                            builder: (context, _) => AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              alignment: Alignment.topCenter,
                              child: _body(),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 8,
                          child: Semantics(
                            button: true,
                            label: _x.closeButton,
                            child: Pressable(
                              onTap: _close,
                              pressedScale: 0.9,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEEEEE),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '✕',
                                  style: TextStyle(
                                    color: _t.titleColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_auth.status) {
      ArkAuthStatus.signedIn => _signedIn(),
      ArkAuthStatus.signedOut => _form(),
      ArkAuthStatus.initializing || ArkAuthStatus.unavailable => _unavailable(),
    };
  }

  Widget _title(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
    child: Text(
      s,
      textAlign: TextAlign.center,
      style: _t.text(size: 20, weight: FontWeight.w900, color: _t.titleColor),
    ),
  );

  Widget _unavailable() {
    return Column(
      key: const ValueKey('unavailable'),
      children: [
        _title(_x.unavailableTitle),
        Text(
          _x.unavailableBody,
          textAlign: TextAlign.center,
          style: _t.text(size: 15),
        ),
        const SizedBox(height: 16),
        ArkAuthButton(label: _x.closeButton, theme: _t, onTap: _close),
      ],
    );
  }

  Widget _form() {
    final busy = _auth.isBusy;
    return AutofillGroup(
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(_x.title),
          Text(
            _x.lead,
            textAlign: TextAlign.center,
            style: _t.text(size: 13, color: _t.hintColor),
          ),
          const SizedBox(height: 14),
          _label(_x.idLabel),
          _field(
            key: const ValueKey('ark-login-id'),
            controller: _id,
            hint: _x.idHint,
            keyboardType: TextInputType.visiblePassword,
            autofill: const [AutofillHints.username],
            action: TextInputAction.next,
            onSubmitted: (_) => _pwFocus.requestFocus(),
            formatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          ),
          const SizedBox(height: 10),
          _label(_x.passwordLabel),
          _field(
            key: const ValueKey('ark-login-password'),
            controller: _pw,
            focusNode: _pwFocus,
            obscure: !_showPw,
            keyboardType: TextInputType.visiblePassword,
            autofill: const [AutofillHints.password],
            action: TextInputAction.done,
            onSubmitted: (_) => _login(),
            suffix: TextButton(
              onPressed: () => setState(() => _showPw = !_showPw),
              child: Text(
                _showPw ? _x.hidePassword : _x.showPassword,
                style: _t.text(size: 12, color: _t.buttonColor),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                key: const ValueKey('ark-login-error'),
                textAlign: TextAlign.center,
                style: _t.text(size: 13, color: _t.errorColor),
              ),
            ),
          const SizedBox(height: 14),
          ArkAuthButton(
            key: const ValueKey('ark-login-submit'),
            label: _x.loginButton,
            theme: _t,
            busy: busy,
            onTap: busy ? null : _login,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _close,
              child: Text(
                _x.playWithoutLogin,
                style: _t.text(
                  size: 14,
                  weight: FontWeight.w800,
                  color: _t.titleColor,
                ),
              ),
            ),
          ),
          _helpLinks(includeForgot: true),
        ],
      ),
    );
  }

  Widget _signedIn() {
    final sync = _auth.sync;
    final syncText = sync == null ? '' : _x.syncState(sync.state);
    return Column(
      key: const ValueKey('signedIn'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(_x.signedInTitle),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _t.fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                _x.signedInAs,
                style: _t.text(size: 12, color: _t.hintColor),
              ),
              const SizedBox(height: 2),
              Text(
                _auth.currentId ?? '',
                key: const ValueKey('ark-login-current-id'),
                style: _t.text(
                  size: 22,
                  weight: FontWeight.w900,
                  color: _t.titleColor,
                ),
              ),
              if (syncText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    syncText,
                    style: _t.text(size: 12, color: _t.hintColor),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ArkAuthButton(
          label: _x.logoutButton,
          theme: _t,
          busy: _auth.isBusy,
          onTap: _auth.isBusy ? null : () => _auth.logout(),
        ),
        Text(
          _x.logoutNote,
          textAlign: TextAlign.center,
          style: _t.text(size: 12, color: _t.hintColor),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: _close,
            child: Text(
              _x.closeButton,
              style: _t.text(size: 14, color: _t.titleColor),
            ),
          ),
        ),
        _helpLinks(includeForgot: false),
      ],
    );
  }

  Widget _helpLinks({required bool includeForgot}) {
    final contact = _auth.config.supportContact;
    final url = _auth.config.accountDeletionUrl;
    Widget link(_Help h, String label) => Center(
      child: TextButton(
        onPressed: () => setState(() => _help = _help == h ? null : h),
        child: Text(
          label,
          style: _t
              .text(size: 12, color: _t.hintColor)
              .copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
    Widget box(String body, {String? extra}) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _t.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: _t.text(size: 12)),
          if (contact != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(
                contact,
                style: _t.text(size: 12, weight: FontWeight.w800),
              ),
            ),
          if (extra != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(extra, style: _t.text(size: 12)),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeForgot) link(_Help.forgot, _x.forgotTitle),
        if (_help == _Help.forgot && includeForgot) box(_x.forgotBody),
        link(_Help.delete, _x.deleteTitle),
        if (_help == _Help.delete) box(_x.deleteBody, extra: url),
      ],
    );
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Text(s, style: _t.text(size: 13, weight: FontWeight.w800)),
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    String? hint,
    FocusNode? focusNode,
    bool obscure = false,
    TextInputType? keyboardType,
    Iterable<String>? autofill,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboardType,
      autofillHints: autofill,
      textInputAction: action,
      onSubmitted: onSubmitted,
      inputFormatters: formatters,
      maxLength: 64,
      style: _t.text(size: 18, weight: FontWeight.w800),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: _t.text(size: 16, color: _t.hintColor.withValues(alpha: .6)),
        filled: true,
        fillColor: _t.fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _t.buttonColor, width: 2),
        ),
      ),
    );
  }
}

enum _Help { forgot, delete }

/// `.ark-btn`-style purple pill used by the auth widgets.
class ArkAuthButton extends StatelessWidget {
  const ArkAuthButton({
    super.key,
    required this.label,
    required this.onTap,
    this.theme = ArkAuthTheme.kids,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final ArkAuthTheme theme;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : 6),
        child: Semantics(
          button: true,
          enabled: enabled,
          child: Pressable(
            onTap: onTap,
            pressedScale: 0.95,
            child: Container(
              constraints: BoxConstraints(minWidth: compact ? 0 : 160),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 22,
                vertical: compact ? 6 : 11,
              ),
              decoration: BoxDecoration(
                color: enabled
                    ? theme.buttonColor
                    : theme.buttonColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: busy
                  ? const Center(
                      widthFactor: 1,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.text(
                        size: compact ? 14 : 16,
                        weight: FontWeight.w800,
                        color: theme.buttonTextColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
