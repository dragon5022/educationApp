import 'package:flutter/material.dart';

import '../ui/pressable.dart';

/// Look of the paywall, parent gate and lock badges. Defaults match the
/// KIDS app (white sheet, 4px gold border, radius 22, purple buttons,
/// 'M PLUS Rounded 1c'). Apps pass their own for TEEN etc.
@immutable
class PurchaseTheme {
  const PurchaseTheme({
    this.sheetColor = Colors.white,
    this.borderColor = const Color(0xFFFFCF3D),
    this.borderWidth = 4,
    this.radius = 22,
    this.accent = const Color(0xFF8B5CF6),
    this.accentDeep = const Color(0xFF5B21B6),
    this.onAccent = Colors.white,
    this.ink = const Color(0xFF2B2350),
    this.muted = const Color(0xFF7A7396),
    this.secondaryButton = const Color(0xFFB9B3C9),
    this.panelColor = const Color(0xFFF5F0FF),
    this.errorColor = const Color(0xFFE5484D),
    this.successColor = const Color(0xFF22A06B),
    this.lockColor = const Color(0xCC1A1147),
    this.barrierColor = const Color(0x99140C2D),
    this.fontFamily = 'M PLUS Rounded 1c',
    this.fontFamilyFallback = const ['Zen Maru Gothic'],
    this.maxWidth = 400,
  });

  /// KIDS default.
  static const kids = PurchaseTheme();

  /// A calmer navy/blue variant for TEEN (override freely).
  static const teen = PurchaseTheme(
    borderColor: Color(0xFF3B82F6),
    accent: Color(0xFF1F3864),
    accentDeep: Color(0xFF0F1E3D),
    ink: Color(0xFF1B2333),
    muted: Color(0xFF5E6B80),
    panelColor: Color(0xFFEFF4FF),
    radius: 18,
    borderWidth: 3,
    fontFamily: null,
    fontFamilyFallback: null,
  );

  final Color sheetColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final Color accent;
  final Color accentDeep;
  final Color onAccent;
  final Color ink;
  final Color muted;
  final Color secondaryButton;
  final Color panelColor;
  final Color errorColor;
  final Color successColor;
  final Color lockColor;
  final Color barrierColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double maxWidth;

  TextStyle text({
    double size = 15,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink,
    height: height,
  );

  ShapeBorder get sheetShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(color: borderColor, width: borderWidth),
  );
}

/// Pop-in dialog used by the gate and paywall.
Future<T?> showPurchaseDialog<T>({
  required BuildContext context,
  required PurchaseTheme theme,
  required WidgetBuilder builder,
  bool dismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'close',
    barrierColor: theme.barrierColor,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(
          begin: 0.88,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

/// White, gold-bordered sheet that centres and scrolls on small screens.
class PurchaseSheet extends StatelessWidget {
  const PurchaseSheet({super.key, required this.theme, required this.child});

  final PurchaseTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: theme.maxWidth),
            child: Material(
              color: theme.sheetColor,
              shape: theme.sheetShape,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded button in the KIDS dialog style.
class PurchaseButton extends StatelessWidget {
  const PurchaseButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.theme,
    this.color,
    this.textColor,
    this.big = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final PurchaseTheme theme;
  final Color? color;
  final Color? textColor;
  final bool big;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? theme.accent;
    final fg = textColor ?? theme.onAccent;
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.5,
        child: Pressable(
          onTap: enabled ? onTap : null,
          pressedScale: 0.96,
          child: Container(
            constraints: BoxConstraints(minWidth: 96, minHeight: big ? 54 : 44),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: big ? 14 : 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(big ? 18 : 14),
              boxShadow: big
                  ? [
                      BoxShadow(
                        color: Color.lerp(bg, Colors.black, 0.35)!,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3, color: fg),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.text(size: big ? 18 : 15, color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}
