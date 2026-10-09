import 'package:ark_core/auth.dart';
import 'package:ark_core/content.dart';
import 'package:ark_core/purchase.dart';
import 'package:ark_core/ui.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/teen_store.dart';
import '../widgets/common.dart';

/// Round gear button (same look as [BgmButton]) that opens the settings.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '設定',
      child: PressDown(
        haptic: false,
        onTap: () => showTeenSettings(context),
        builder: (context, pressed) => AnimatedScale(
          scale: pressed ? .92 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .45),
              shape: BoxShape.circle,
              border: Border.all(color: TeenColors.goldBright, width: 2),
              boxShadow: [
                cssShadow(0, 2, 8, Colors.black.withValues(alpha: .4)),
              ],
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: TeenColors.goldBright,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Account (login), full unlock and question updates.
Future<void> showTeenSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _updating = false;
  String _updateMsg = '';

  Future<void> _update() async {
    setState(() {
      _updating = true;
      _updateMsg = '確認中…';
    });
    final r = await ArkContent.instance.checkForUpdates(force: true);
    if (!mounted) return;
    setState(() {
      _updating = false;
      _updateMsg = _message(r);
    });
  }

  static String _message(ContentUpdateReport r) {
    if (r.notConfigured) return '問題の更新はまだ設定されていません';
    if (r.offline) return 'インターネットに接続すると更新できます';
    if (r.failed.isNotEmpty) return '更新できなかった問題があります';
    if (r.updated.isNotEmpty) return '${r.updated.length}ステージの問題を更新しました';
    return '問題は最新です';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + pad.bottom),
      decoration: const BoxDecoration(
        color: TeenColors.navyDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: TeenColors.goldBright, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '設定',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TeenFonts.dela,
                fontSize: 20,
                color: TeenColors.goldBright,
              ),
            ),
            const SizedBox(height: 16),
            // School-issued login; hidden until Firebase is configured.
            ArkAccountRow(theme: TeenStore.authTheme, texts: ArkAuthTexts.teen),
            // Shown once the sheet's pricing tab enables purchases.
            ValueListenableBuilder<bool>(
              valueListenable: TeenStore.monetizationEnabled,
              builder: (context, _, _) => !TeenStore.showPurchaseUi
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: PurchaseService.instance.isUnlocked,
                        builder: (context, unlocked, _) => unlocked
                            ? const _Note('✓ 全ステージ解放済み')
                            : _Button(
                                label: '全ステージを解放する',
                                color: TeenColors.goldBright,
                                textColor: TeenColors.navyDeep,
                                onTap: () => TeenStore.openPaywall(context),
                              ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _Button(
              label: _updating ? '確認中…' : '問題データを更新',
              color: TeenColors.navy,
              textColor: Colors.white,
              onTap: _updating ? null : _update,
            ),
            if (_updateMsg.isNotEmpty) _Note(_updateMsg),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: Pressable(
        onTap: onTap,
        pressedScale: .97,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: TeenColors.goldBright.withValues(alpha: .6),
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TeenFonts.zen,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TeenFonts.zen,
          fontSize: 13,
          color: TeenColors.text,
        ),
      ),
    );
  }
}
