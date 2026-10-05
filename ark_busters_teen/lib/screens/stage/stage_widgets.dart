import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ark_core/purchase.dart';
import 'package:ark_core/ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/teen_store.dart';
import '../../widgets/common.dart';
import 'stage_fx.dart';

/// Layout constants of the stage page, incl. `@media (max-height:680px)`.
class StageMetrics {
  const StageMetrics(this.compact);
  final bool compact;

  double get stageH => compact ? 230 : 280;
  Size get orb => compact ? const Size(170, 195) : const Size(200, 230);
  Size get fighter => compact ? const Size(140, 170) : const Size(165, 200);
  Size get titleStage => compact ? const Size(200, 200) : const Size(240, 230);
  Size get titleOrb => compact ? const Size(140, 160) : const Size(170, 195);
  double get titleLabel => compact ? 34 : 42;
  Size get titleFighter => compact ? const Size(110, 135) : const Size(130, 160);
  double get gameTitle => compact ? 38 : 46;
  double get countdown => compact ? 120 : 160;
}

// ------------------------------------------------------------------ HUD

class HudBox extends StatelessWidget {
  const HudBox({super.key, required this.label, required this.value, this.alignEnd = false});
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TeenColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TeenColors.navy, width: 2),
        boxShadow: [cssShadow(0, 3, 0, TeenColors.navy)],
      ),
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: ts(
                  family: TeenFonts.zen,
                  size: 9,
                  weight: FontWeight.w900,
                  color: TeenColors.gold,
                  ls: .15,
                  height: 1.45)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 1.25, end: 1.0).animate(a), child: c),
            ),
            layoutBuilder: (cur, prev) => Stack(
              alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
              children: [...prev, ?cur],
            ),
            child: Text(value,
                key: ValueKey(value),
                style: ts(
                    family: TeenFonts.russo,
                    size: 22,
                    color: TeenColors.navyDeep,
                    height: 1,
                    fallback: TeenFonts.sansFallback)),
          ),
        ],
      ),
    );
  }
}

/// `#lives .heart` ×3 (lost: opacity .2, grayscale, scale .85 over .3s).
class Hearts extends StatelessWidget {
  const Hearts({super.key, required this.lives});
  final int lives;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          SizedBox(
            width: 24,
            height: 24,
            child: AnimatedScale(
              scale: i >= lives ? .85 : 1,
              duration: const Duration(milliseconds: 300),
              child: AnimatedOpacity(
                opacity: i >= lives ? .2 : 1,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: i >= lives
                      ? const ColorFiltered(colorFilter: grayscale, child: HeartIcon(size: 20))
                      : const HeartIcon(size: 20),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `.back-btn` (dark theme): "← メニュー".
class BackPill extends StatelessWidget {
  const BackPill({super.key, required this.onTap, this.text = '← メニュー'});
  final VoidCallback onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PressDown(
      onTap: onTap,
      builder: (context, pressed) => Transform.translate(
        offset: Offset(0, pressed ? 2 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TeenColors.goldBright.withValues(alpha: .6), width: 2),
            boxShadow: [cssShadow(0, pressed ? 1 : 3, 0, Colors.black.withValues(alpha: .4))],
          ),
          child: Text(text,
              style: ts(
                  family: TeenFonts.zen,
                  size: 12,
                  weight: FontWeight.w900,
                  color: TeenColors.creamSoft,
                  height: 1.3)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- question

class QuestionArea extends StatelessWidget {
  const QuestionArea({
    super.key,
    required this.text,
    required this.comboSerial,
    required this.combo,
    this.maxHeight = double.infinity,
  });

  final String text;
  final int comboSerial;
  final int combo;

  /// App deviation: e-choubun passages can be taller than the screen (on
  /// the web they push the choices out of view); the text scrolls instead.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final style = ts(
      family: TeenFonts.russo,
      size: 20,
      color: TeenColors.navyDeep,
      height: 1.5,
      fallback: TeenFonts.jpFallback,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: TeenColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TeenColors.navy, width: 3),
            boxShadow: [
              cssShadow(0, 5, 0, TeenColors.navy),
              cssShadow(0, 10, 20, TeenColors.navy.withValues(alpha: .15)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: _ScrollFade(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(text, key: ValueKey(text), textAlign: TextAlign.center, style: style),
              ),
            ),
          ),
        ),
        // ::before '問題' tag
        Positioned(
          top: -10,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: TeenColors.goldBright,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TeenColors.navy, width: 2),
            ),
            child: Text('問題',
                style: ts(
                    family: TeenFonts.zen,
                    size: 11,
                    weight: FontWeight.w900,
                    color: TeenColors.navyDeep,
                    ls: .15,
                    height: 1.3)),
          ),
        ),
        Positioned(
          top: -10,
          right: 14,
          child: ComboBadge(serial: comboSerial, n: combo),
        ),
      ],
    );
  }
}

/// Scrolls overflowing text with a soft fade at the clipped edges.
class _ScrollFade extends StatefulWidget {
  const _ScrollFade({required this.child});
  final Widget child;

  @override
  State<_ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<_ScrollFade> {
  final _c = ScrollController();
  bool _top = true, _bottom = true;

  void _update() {
    if (!_c.hasClients) return;
    final p = _c.position;
    final top = p.pixels <= 1, bottom = p.pixels >= p.maxScrollExtent - 1;
    if (top != _top || bottom != _bottom) setState(() { _top = top; _bottom = bottom; });
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(_ScrollFade old) {
    super.didUpdateWidget(old);
    if (_c.hasClients) _c.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      controller: _c,
      physics: const ClampingScrollPhysics(),
      child: widget.child,
    );
    if (_top && _bottom) return scroll;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _top ? Colors.black : Colors.transparent,
          Colors.black,
          Colors.black,
          _bottom ? Colors.black : Colors.transparent,
        ],
        stops: const [0, .08, .92, 1],
      ).createShader(r),
      child: scroll,
    );
  }
}

enum ChoiceMark { none, correct, wrong }

/// `.choice` button (correct: green + correctPulse; wrong: red + wrongShake).
class ChoiceButton extends StatefulWidget {
  const ChoiceButton({
    super.key,
    required this.text,
    required this.mark,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final ChoiceMark mark;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400), value: 1);

  @override
  void didUpdateWidget(ChoiceButton old) {
    super.didUpdateWidget(old);
    if (widget.mark != old.mark && widget.mark != ChoiceMark.none) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = widget.mark;
    final colors = switch (mark) {
      ChoiceMark.none => const [Colors.white, TeenColors.lightBlue],
      ChoiceMark.correct => const [Color(0xFFA8E6CF), TeenColors.green],
      ChoiceMark.wrong => const [Color(0xFFFFB3B3), TeenColors.red],
    };
    return PressDown(
      onTap: widget.enabled ? widget.onTap : null,
      builder: (context, pressed) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          var sc = 1.0, dx = 0.0;
          if (mark == ChoiceMark.correct) {
            sc = kf(t, [0, .5, 1], [1, 1.08, 1]);
          } else if (mark == ChoiceMark.wrong) {
            dx = kf(t, [0, .25, .75, 1], [0, -8, 8, 0]);
          }
          return Transform.translate(
            offset: Offset(dx, pressed ? 3 : 0),
            child: Transform.scale(scale: sc, child: child),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TeenColors.navy, width: 3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: [cssShadow(0, pressed ? 2 : 5, 0, TeenColors.navy)],
          ),
          // Long answers (e-choubun) shrink to fit instead of clipping.
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: c.maxWidth,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: ts(
                    family: TeenFonts.russo,
                    size: 14,
                    height: 1.3,
                    color: mark == ChoiceMark.none ? TeenColors.navyDeep : Colors.white,
                    fallback: TeenFonts.jpFallback,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- explain

/// `.explain-box`: bottom sheet shown after a miss / timeout.
class ExplainSheet extends StatelessWidget {
  const ExplainSheet({
    super.key,
    required this.show,
    required this.answer,
    required this.body,
    required this.onNext,
  });

  final bool show;
  final String answer;
  final String body;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedSlide(
        offset: Offset(0, show ? 0 : 1.1),
        duration: const Duration(milliseconds: 350),
        curve: const Cubic(.2, .8, .2, 1),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottom),
              decoration: BoxDecoration(
                color: TeenColors.paper,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(
                  top: BorderSide(color: TeenColors.navy, width: 3),
                  left: BorderSide(color: TeenColors.navy, width: 3),
                  right: BorderSide(color: TeenColors.navy, width: 3),
                ),
                boxShadow: [cssShadow(0, -6, 24, TeenColors.navy.withValues(alpha: .25))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('かいせつ',
                      style: ts(
                          family: TeenFonts.bungee,
                          size: 13,
                          color: TeenColors.gold,
                          ls: .2,
                          fallback: TeenFonts.sansFallback)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '正解は '),
                      TextSpan(
                        text: answer,
                        style: ts(
                            family: TeenFonts.zen,
                            size: 26,
                            weight: FontWeight.w900,
                            color: TeenColors.red),
                      ),
                    ]),
                    style: ts(
                        family: TeenFonts.zen,
                        size: 20,
                        weight: FontWeight.w900,
                        color: TeenColors.navyDeep),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .42,
                    ),
                    child: SingleChildScrollView(
                      child: Text(body,
                          style: ts(
                              family: TeenFonts.zen,
                              size: 15,
                              weight: FontWeight.w700,
                              color: TeenColors.navyDeep,
                              height: 1.65)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GoldButton(
                    text: 'つぎへ ▶',
                    onTap: onNext,
                    expand: true,
                    fontSize: 18,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    radius: 30,
                    shadowY: 4,
                    ls: .1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- buttons

/// Gold gradient button (`.start-btn`, `.explain-next`, `.level-btn`).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
    this.radius = 50,
    this.shadowY = 6,
    this.glow = true,
    this.expand = false,
    this.ls = .08,
    this.family = TeenFonts.russo,
    this.trailing,
    this.extraShadow,
  });

  final String text;
  final VoidCallback onTap;
  final double fontSize;
  final EdgeInsets padding;
  final double radius;
  final double shadowY;
  final bool glow;
  final bool expand;
  final double ls;
  final String family;
  final Widget? trailing;
  final BoxShadow? extraShadow;

  @override
  Widget build(BuildContext context) {
    return PressDown(
      onTap: onTap,
      builder: (context, pressed) => Transform.translate(
        offset: Offset(0, pressed ? 3 : 0),
        child: Container(
          width: expand ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: TeenColors.navy, width: 3),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TeenColors.goldBright, TeenColors.gold],
            ),
            boxShadow: [
              cssShadow(0, pressed ? math.max(2, shadowY / 2) : shadowY, 0, TeenColors.navy),
              ?extraShadow,
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text,
                  style: ts(
                      family: family,
                      size: fontSize,
                      weight: FontWeight.w700,
                      color: TeenColors.navyDeep,
                      ls: ls,
                      height: 1.2,
                      fallback: TeenFonts.sansFallback)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// `.menu-btn`: paper pill.
class PaperButton extends StatelessWidget {
  const PaperButton({super.key, required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressDown(
      onTap: onTap,
      builder: (context, pressed) => Transform.translate(
        offset: Offset(0, pressed ? 2 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: TeenColors.paper,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: TeenColors.navy, width: 3),
            boxShadow: [cssShadow(0, pressed ? 3 : 5, 0, TeenColors.navy)],
          ),
          child: Text(text,
              style: ts(
                  family: TeenFonts.russo,
                  size: 16,
                  color: TeenColors.navyDeep,
                  ls: .05,
                  height: 1.2,
                  fallback: TeenFonts.sansFallback)),
        ),
      ),
    );
  }
}

/// Repeating scale pulse (startPulse 1.2s / artBtnPulse 1.3s / artPulse).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.ms = 1200, this.to = 1.05});
  final Widget child;
  final int ms;
  final double to;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: 1 + (widget.to - 1) * pingPong(_c.value),
          child: child,
        ),
        child: widget.child,
      );
}

// --------------------------------------------------------------- overlays

/// `.overlay` (dark theme): navy gradient at .97 with a light blur.
class OverlayPanel extends StatelessWidget {
  const OverlayPanel({super.key, required this.child, this.blur = 6, this.color});
  final Widget child;
  final double blur;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            gradient: color != null
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF71A2742), Color(0xF70D1626)],
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}

Widget arkTag(String text, {Color color = TeenColors.gold}) => Text(text,
    textAlign: TextAlign.center,
    style: ts(family: TeenFonts.zen, size: 10, weight: FontWeight.w900, color: color, ls: .3));

Widget arkFooter() => Text('ARK SOGO GAKUIN',
    textAlign: TextAlign.center,
    style: ts(family: TeenFonts.zen, size: 9, weight: FontWeight.w700, color: TeenColors.gold, ls: .3));

/// Start screen with a full-screen title illustration (`#start-overlay.artmode`).
class StartArt extends StatelessWidget {
  const StartArt({super.key, required this.art, required this.aspect, required this.onStart});
  final String art;
  final double aspect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final vw = MediaQuery.sizeOf(context).width;
      // width:100% (max 440) of the 6px-padded overlay; never taller than
      // the screen (app guard for short phones / tall art).
      var w = math.min(c.maxWidth, 440.0);
      w = math.min(w, c.maxHeight * aspect);
      final h = w / aspect;
      final orbFont = (vw * .065).clamp(26.0, 46.0);
      final startFont = (vw * .055).clamp(20.0, 30.0);
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(art, fit: BoxFit.fill, gaplessPlayback: true),
                ),
              ),
              // .art-orb: top 35.5%, width 24%
              Positioned(
                left: w / 2 - w * .12,
                top: h * .355 - w * .12,
                width: w * .24,
                height: w * .24,
                child: Pulse(
                  ms: 1600,
                  to: 1.06,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-.3, -.4),
                        radius: 1.13,
                        colors: [
                          Color(0xFFFFFFFF), Color(0xFFE9D5FF), Color(0xFFC79BFF),
                          Color(0xFFA855F7), Color(0xFF7C3AED),
                        ],
                        stops: [0, .18, .40, .66, 1],
                      ),
                      boxShadow: [
                        cssShadow(0, 0, 26, const Color(0xF2C084FC)),
                        cssShadow(0, 0, 60, const Color(0xB37C3AED)),
                      ],
                    ),
                    child: Text('∞',
                        style: ts(
                          family: TeenFonts.russo,
                          size: orbFont,
                          color: Colors.white,
                          height: 1.2,
                          fallback: TeenFonts.sansFallback,
                          shadows: [
                            cssTextShadow(0, 0, 12, const Color(0xF2D8B4FF)),
                            cssTextShadow(0, 0, 22, const Color(0xD9A855F7)),
                          ],
                        )),
                  ),
                ),
              ),
              // .art-start: top 84%, width 52%
              Positioned(
                left: w * .24,
                width: w * .52,
                top: h * .84 - startFont * .75,
                height: startFont * 1.5,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onStart,
                  child: Pulse(
                    ms: 1300,
                    to: 1.08,
                    child: Center(
                      child: Text('START',
                          softWrap: false,
                          style: ts(
                            family: TeenFonts.russo,
                            size: startFont,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            ls: .3,
                            height: 1.2,
                            shadows: [
                              cssTextShadow(0, 0, 6, const Color(0xF2000000)),
                              cssTextShadow(0, 0, 16, const Color(0xE67C3AED)),
                              cssTextShadow(0, 2, 4, Colors.black),
                            ],
                          )),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Start screen without illustration (m-kansu, m-zukei, s-chizu on live):
/// faint boss art, ark-tag link, title balloon + character, title, START.
class StartPlain extends StatelessWidget {
  const StartPlain({
    super.key,
    required this.metrics,
    required this.title,
    required this.label,
    required this.boss,
    required this.fighter,
    required this.onStart,
    required this.onBack,
  });

  final StageMetrics metrics;
  final String title;
  final String label;
  final String? boss;
  final String fighter;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return LayoutBuilder(builder: (context, c) {
      final bossW = math.min(c.maxWidth * 1.1, 560.0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (boss != null)
            Positioned(
              top: c.maxHeight * .01,
              left: (c.maxWidth - bossW) / 2,
              width: bossW,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .72,
                  child: ArtShadow(
                    color: const Color(0xBF7C3AED),
                    offset: Offset.zero,
                    blur: 28,
                    child: Image.asset(boss!, fit: BoxFit.fitWidth),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(onTap: onBack, child: arkTag('← ARK 数学バスターズ')),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: SizedBox(
                      width: m.titleStage.width,
                      height: m.titleStage.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: 0,
                            child: TitleOrb(
                              label: label,
                              width: m.titleOrb.width,
                              height: m.titleOrb.height,
                              labelSize: m.titleLabel,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: BouncingFighter(
                              image: fighter,
                              width: m.titleFighter.width,
                              height: m.titleFighter.height,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Transform.rotate(
                    angle: -2 * math.pi / 180,
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: ts(
                          family: TeenFonts.bungee,
                          size: m.gameTitle,
                          weight: FontWeight.w700,
                          color: TeenColors.red,
                          height: 1,
                          ls: .02,
                          fallback: TeenFonts.sansFallback,
                          shadows: [
                            cssTextShadow(4, 4, 0, TeenColors.goldBright),
                            cssTextShadow(8, 8, 0, TeenColors.navy),
                          ],
                        )),
                  ),
                  const SizedBox(height: 8),
                  Text('敵の攻撃を止めろ！',
                      style: ts(
                          family: TeenFonts.dela,
                          size: 18,
                          color: const Color(0xFFFF6B5A),
                          ls: .05 * 13 / 18)),
                  const SizedBox(height: 16),
                  Pulse(
                    child: GoldButton(
                      text: 'START',
                      onTap: onStart,
                      extraShadow: cssShadow(0, 10, 25, TeenColors.gold.withValues(alpha: .4)),
                    ),
                  ),
                  // .ark-footer becomes position:relative here (bottom:8px)
                  Transform.translate(offset: const Offset(0, -8), child: arkFooter()),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// `#level-overlay`: one gold button per level with its question count.
class LevelSelect extends StatelessWidget {
  const LevelSelect({
    super.key,
    required this.levels,
    required this.onPick,
    this.best = const {},
    this.isLocked,
    this.onLocked,
  });
  final Map<String, int> levels;
  final ValueChanged<String> onPick;

  /// App extra: purchase lock per level (index in [levels] order).
  final bool Function(int index, String level)? isLocked;
  final VoidCallback? onLocked;

  /// App extra: best rank per level (shown only after a game was played).
  final Map<String, String> best;

  @override
  Widget build(BuildContext context) {
    final entries = levels.entries.toList();
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                arkTag('レベルを選べ'),
                const SizedBox(height: 8 + 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 20 : 14),
                          child: Reveal(
                            delay: Duration(milliseconds: 70 * i),
                            duration: const Duration(milliseconds: 380),
                            dy: 16,
                            child: LockedOverlay(
                              locked: isLocked?.call(i, entries[i].key) ?? false,
                              borderRadius: BorderRadius.circular(18),
                              theme: TeenStore.purchaseTheme,
                              badgeAlignment: Alignment.centerRight,
                              onLockedTap: onLocked,
                              child: _LevelButton(
                                level: entries[i].key,
                                count: entries[i].value,
                                best: best[entries[i].key],
                                onTap: () => onPick(entries[i].key),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 8 + MediaQuery.paddingOf(context).bottom, child: arkFooter()),
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({required this.level, required this.count, required this.onTap, this.best});
  final String level;
  final int count;
  final String? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressDown(
      onTap: onTap,
      builder: (context, pressed) => Transform.translate(
        offset: Offset(0, pressed ? 3 : 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TeenColors.navy, width: 3),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TeenColors.goldBright, TeenColors.gold],
            ),
            boxShadow: pressed
                ? [cssShadow(0, 2, 0, TeenColors.navy)]
                : [
                    cssShadow(0, 5, 0, TeenColors.navy),
                    cssShadow(0, 8, 20, Colors.black.withValues(alpha: .4)),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(level,
                      style: ts(
                          family: TeenFonts.orbitron,
                          size: 26,
                          weight: FontWeight.w700,
                          color: TeenColors.navyDeep,
                          ls: .05,
                          height: 1.15)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: TeenColors.navyDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$count問',
                        style: ts(
                            family: TeenFonts.zen,
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3)),
                  ),
                ],
              ),
              if (best != null)
                Positioned(
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TeenColors.navyDeep.withValues(alpha: .85),
                      border: Border.all(color: TeenColors.paper.withValues(alpha: .7), width: 1.5),
                    ),
                    child: Text(best!,
                        style: ts(
                            family: TeenFonts.bungee,
                            size: 15,
                            color: TeenColors.goldBright,
                            height: 1.1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.countdown-num` with countPop .5s per step (3, 2, 1, GO!).
class CountdownNumber extends StatefulWidget {
  const CountdownNumber({super.key, required this.text, required this.size});
  final String text;
  final double size;

  @override
  State<CountdownNumber> createState() => _CountdownNumberState();
}

class _CountdownNumberState extends State<CountdownNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();

  @override
  void didUpdateWidget(CountdownNumber old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        const times = [0.0, .5, 1.0];
        return Opacity(
          opacity: kf(t, times, [0, 1, 1], curve: Curves.easeOut).clamp(0, 1),
          child: Transform.rotate(
            angle: kf(t, times, [-25, 8, 0], curve: Curves.easeOut) * math.pi / 180,
            child: Transform.scale(
              scale: kf(t, times, [0, 1.3, 1], curve: Curves.easeOut),
              child: child,
            ),
          ),
        );
      },
      child: OverflowBox(
        maxWidth: double.infinity,
        child: Text(widget.text,
            softWrap: false,
            style: ts(
              family: TeenFonts.orbitron,
              size: widget.size,
              weight: FontWeight.w700,
              color: TeenColors.red,
              height: 1.25,
              shadows: [
                cssTextShadow(6, 6, 0, TeenColors.goldBright),
                cssTextShadow(12, 12, 0, TeenColors.navy),
              ],
            )),
      ),
    );
  }
}
