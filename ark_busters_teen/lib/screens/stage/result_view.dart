import 'dart:math' as math;

import 'package:ark_core/ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'stage_widgets.dart';

/// Web endGame() rank table (independent of the number of questions).
(String, String) rankFor(int score) {
  if (score >= 1800) return ('S', '天才かも！');
  if (score >= 1400) return ('A', 'よくできました！');
  if (score >= 900) return ('B', 'その調子！');
  if (score >= 500) return ('C', 'もう一度チャレンジ！');
  return ('D', 'まだまだ伸びる！');
}

/// `#end-overlay`: win/lose art, rank, comment, SCORE / MAX COMBO, buttons.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.score,
    required this.maxCombo,
    required this.image,
    required this.newBest,
    required this.onMenu,
    required this.onRetry,
  });

  final int score;
  final int maxCombo;
  final String? image;
  final bool newBest;
  final VoidCallback onMenu;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (rank, comment) = rankFor(score);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final rankSize = (size.width * .22).clamp(72.0, 112.0);
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16 + pad.top, 16, 16 + pad.bottom),
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    arkTag('RESULT', color: TeenColors.goldBright),
                    const SizedBox(height: 2),
                    if (image != null)
                      Reveal(
                        duration: const Duration(milliseconds: 650),
                        dy: 14,
                        fromScale: .92,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(size.width * .84, 340),
                              maxHeight: size.height * .46,
                            ),
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (r) => RadialGradient(
                                center: const Alignment(0, -.08),
                                radius: .72,
                                colors: const [Colors.black, Colors.black, Colors.transparent],
                                stops: const [0, .58, 1],
                                transform: _EllipseScale(r.height / r.width),
                              ).createShader(r),
                              child: Image.asset(image!, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    _RankStamp(rank: rank, size: rankSize),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      child: Reveal(
                        delay: const Duration(milliseconds: 380),
                        dy: 8,
                        child: Text(comment,
                            textAlign: TextAlign.center,
                            style: ts(
                                family: TeenFonts.zen,
                                size: 18,
                                weight: FontWeight.w700,
                                color: TeenColors.creamSoft)),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Row(
                        children: [
                          Expanded(child: _Stat(label: 'SCORE', value: score, badge: newBest ? 'NEW BEST' : null)),
                          const SizedBox(width: 12),
                          Expanded(child: _Stat(label: 'MAX COMBO', value: maxCombo)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18 + 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PaperButton(text: 'メニュー', onTap: onMenu),
                        const SizedBox(width: 10),
                        ShineSweep(
                          period: const Duration(milliseconds: 3200),
                          delay: const Duration(milliseconds: 900),
                          child: GoldButton(
                            text: 'もう一度',
                            onTap: onRetry,
                            fontSize: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            extraShadow: cssShadow(0, 10, 25, TeenColors.gold.withValues(alpha: .4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 8 + pad.bottom, child: arkFooter()),
      ],
    );
  }
}

/// Scales a radial gradient vertically about the paint box centre, turning
/// Flutter's circle into CSS `radial-gradient(ellipse 72% 72% …)`.
class _EllipseScale extends GradientTransform {
  const _EllipseScale(this.sy);
  final double sy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = bounds.center;
    // radius .72 is relative to the shortest side (width here).
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, sy, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

/// Rank letter; app polish: stamps in with a spin and a gold flare.
class _RankStamp extends StatelessWidget {
  const _RankStamp({required this.rank, required this.size});
  final String rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Text(rank,
        style: ts(
          family: TeenFonts.bungee,
          size: size,
          color: TeenColors.goldBright,
          height: .85,
          shadows: [
            cssTextShadow(3, 3, 0, const Color(0xFF4C1D95)),
            cssTextShadow(0, 0, 24, TeenColors.goldBright.withValues(alpha: .6)),
          ],
        ));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, t, child) {
        final e = Curves.easeOutBack.transform(math.min(1, t * 1.15));
        return Opacity(
          opacity: math.min(1, t * 3),
          child: Transform.rotate(
            angle: (1 - e) * -.5,
            child: Transform.scale(scale: 2.2 - 1.2 * e, child: child),
          ),
        );
      },
      child: ShineSweep(
        period: const Duration(milliseconds: 2800),
        delay: const Duration(milliseconds: 700),
        opacity: .7,
        child: text,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.badge});
  final String label;
  final int value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: TeenColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TeenColors.navy, width: 2),
            boxShadow: [cssShadow(0, 3, 0, TeenColors.navy)],
          ),
          child: Column(
            children: [
              Text(label,
                  style: ts(
                      family: TeenFonts.zen,
                      size: 10,
                      weight: FontWeight.w900,
                      color: TeenColors.gold,
                      ls: .15)),
              const SizedBox(height: 4),
              // app polish: count up
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.toDouble()),
                duration: Duration(milliseconds: value == 0 ? 1 : 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text('${v.round()}',
                    style: ts(
                        family: TeenFonts.russo,
                        size: 26,
                        color: TeenColors.navyDeep,
                        height: 1.2,
                        fallback: TeenFonts.sansFallback)),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            top: -9,
            child: Reveal(
              delay: const Duration(milliseconds: 900),
              fromScale: .5,
              dy: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [TeenColors.red, TeenColors.redDeep],
                  ),
                  border: Border.all(color: TeenColors.goldBright, width: 1.5),
                ),
                child: Text(badge!,
                    style: ts(
                        family: TeenFonts.bungee,
                        size: 9,
                        color: Colors.white,
                        ls: .08,
                        height: 1.3)),
              ),
            ),
          ),
      ],
    );
  }
}
