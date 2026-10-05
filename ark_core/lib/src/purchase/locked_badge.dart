import 'package:flutter/material.dart';

import 'purchase_theme.dart';

/// Small round padlock (or padlock + label) for locked cards / list rows.
class LockedBadge extends StatelessWidget {
  const LockedBadge({
    super.key,
    this.label,
    this.size = 28,
    this.theme = PurchaseTheme.kids,
  });

  /// Optional text, e.g. 'ロック中'. Icon only when null.
  final String? label;
  final double size;
  final PurchaseTheme theme;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.lock_rounded,
      size: size * 0.58,
      color: theme.accentDeep,
    );
    return Semantics(
      label: label ?? 'ロック中',
      child: Container(
        height: size,
        // Icon-only badges are round; without a width, Center would stretch
        // the badge across the whole card.
        width: label == null ? size : null,
        constraints: BoxConstraints(minWidth: size),
        padding: label == null
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: size * 0.3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: theme.borderColor, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x403C2878), offset: Offset(0, 2)),
          ],
        ),
        child: label == null
            ? Center(child: icon)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 3),
                  Text(
                    label!,
                    style: theme.text(
                      size: size * 0.42,
                      color: theme.accentDeep,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Dims [child] and shows a padlock when [locked]. Taps go to [onLockedTap]
/// (typically: open the paywall) instead of the child.
class LockedOverlay extends StatelessWidget {
  const LockedOverlay({
    super.key,
    required this.locked,
    required this.child,
    this.onLockedTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.label,
    this.theme = PurchaseTheme.kids,
    this.badgeSize = 34,
    this.badgeAlignment = Alignment.center,
  });

  final bool locked;
  final Widget child;
  final VoidCallback? onLockedTap;
  final BorderRadius borderRadius;
  final String? label;
  final PurchaseTheme theme;
  final double badgeSize;

  /// Where the padlock sits, e.g. [Alignment.centerRight] so it doesn't
  /// cover a button's label.
  final AlignmentGeometry badgeAlignment;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onLockedTap,
      child: Stack(
        children: [
          AbsorbPointer(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.55, 0.25, 0.08, 0, 10, //
                0.18, 0.62, 0.08, 0, 10, //
                0.18, 0.25, 0.45, 0, 10, //
                0, 0, 0, 1, 0, //
              ]),
              child: child,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: theme.lockColor.withValues(alpha: 0.28),
                ),
                child: Align(
                  alignment: badgeAlignment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: LockedBadge(
                      label: label,
                      size: badgeSize,
                      theme: theme,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
