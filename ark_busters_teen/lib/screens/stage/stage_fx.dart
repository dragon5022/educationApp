import 'dart:math' as math;

import 'package:ark_core/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';

/// CSS @keyframes sampling: [times] are keyframe offsets (0..1), [values]
/// the property at each; [curve] is the animation-timing-function, which
/// CSS applies per keyframe segment.
double kf(double t, List<double> times, List<double> values,
    {Curve curve = Curves.ease}) {
  if (t <= times.first) return values.first;
  for (var i = 1; i < times.length; i++) {
    if (t <= times[i]) {
      final local = (t - times[i - 1]) / (times[i] - times[i - 1]);
      final e = curve.transform(local.clamp(0.0, 1.0));
      return values[i - 1] + (values[i] - values[i - 1]) * e;
    }
  }
  return values.last;
}

/// Ping-pong 0 → 1 → 0 with [curve] per half (keyframes 0%, 50%, 100%).
double pingPong(double t, [Curve curve = Curves.easeInOut]) =>
    t < .5 ? curve.transform(t * 2) : 1 - curve.transform((t - .5) * 2);

const _deg = math.pi / 180;

/// Colour matrix for CSS `saturate(s) brightness(b)`.
ColorFilter cssSaturateBrightness(double s, double b) {
  const lr = .2126, lg = .7152, lb = .0722;
  final m = <double>[
    (lr + (1 - lr) * s) * b, (lg - lg * s) * b, (lb - lb * s) * b, 0, 0,
    (lr - lr * s) * b, (lg + (1 - lg) * s) * b, (lb - lb * s) * b, 0, 0,
    (lr - lr * s) * b, (lg - lg * s) * b, (lb + (1 - lb) * s) * b, 0, 0,
    0, 0, 0, 1, 0,
  ];
  return ColorFilter.matrix(m);
}

const grayscale = ColorFilter.matrix(<double>[
  .2126, .7152, .0722, 0, 0,
  .2126, .7152, .0722, 0, 0,
  .2126, .7152, .0722, 0, 0,
  0, 0, 0, 1, 0,
]);

// ===================================================================
// Energy orb (`.balloon`): Zerodius' purple energy shot that grows over
// the 5 s timer and explodes on a miss.
// ===================================================================

enum OrbState { normal, danger, exploded }

class EnergyOrb extends StatefulWidget {
  const EnergyOrb({
    super.key,
    required this.scale,
    required this.state,
    required this.explodeSerial,
    this.width = 200,
    this.height = 230,
  });

  /// `--scale`: 1 + 0.6 × elapsed / TIME_LIMIT.
  final ValueListenable<double> scale;
  final OrbState state;

  /// Bumped every time the orb explodes (restarts the animation).
  final int explodeSerial;
  final double width;
  final double height;

  @override
  State<EnergyOrb> createState() => _EnergyOrbState();
}

class _EnergyOrbState extends State<EnergyOrb> with TickerProviderStateMixin {
  // bobble 2.5s (danger 0.3s), auraSpin 3s, coreGlow 1.1s, explode 0.6s
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
        ..repeat();
  late final AnimationController _aura =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final AnimationController _core =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();
  late final AnimationController _boom =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  double _scaleAtBoom = 1;

  @override
  void didUpdateWidget(EnergyOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      if (widget.state == OrbState.danger) {
        _setBob(300);
      } else if (old.state == OrbState.danger) {
        _setBob(2500);
      }
    }
    if (widget.explodeSerial != old.explodeSerial && widget.state == OrbState.exploded) {
      _scaleAtBoom = widget.scale.value;
      _boom.forward(from: 0);
    }
  }

  void _setBob(int ms) {
    // CSS keeps the elapsed time when only the duration changes.
    final v = _bob.value;
    _bob.duration = Duration(milliseconds: ms);
    _bob.repeat();
    _bob.value = v;
  }

  @override
  void dispose() {
    _bob.dispose();
    _aura.dispose();
    _core.dispose();
    _boom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _aura, _core, _boom, widget.scale]),
        builder: (context, _) {
          final exploded = widget.state == OrbState.exploded;
          final danger = widget.state == OrbState.danger;
          final p = pingPong(_bob.value);
          double sc, ty, rot, opacity = 1, bright = 1, sat = 1, flash = 0;
          if (exploded) {
            final t = _boom.value;
            if (!_boom.isAnimating && t >= 1) return const SizedBox.shrink();
            sc = kf(t, [0, .25, 1], [_scaleAtBoom, 2.3, .1]);
            opacity = kf(t, [0, .25, 1], [1, .95, 0]);
            bright = kf(t, [0, .25, 1], [1, 2, 2.5]);
            sat = kf(t, [0, .25, 1], [1, 1.6, 1.6]);
            flash = kf(t, [0, .25, 1], [0, 1, 1]);
            ty = 0;
            rot = 0;
          } else {
            sc = widget.scale.value;
            ty = -6 * p;
            rot = (-2 + 4 * p) * _deg;
            if (danger) {
              sat = 1.5;
              bright = 1.12;
            }
          }
          final origin = Offset(w / 2, h * .92);
          Widget orb = CustomPaint(
            size: Size(w, h),
            painter: _OrbPainter(
              glow: exploded ? 0 : p,
              aura: _aura.value,
              danger: danger,
              flash: flash,
            ),
          );
          orb = Stack(
            clipBehavior: Clip.none,
            children: [
              orb,
              // ::before '∞' core with coreGlow 1.1s
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: .7 + .3 * pingPong(_core.value),
                    child: Transform.scale(
                      scale: .96 + .10 * pingPong(_core.value),
                      child: Text(
                        '∞',
                        textAlign: TextAlign.center,
                        style: ts(
                          family: TeenFonts.russo,
                          size: 84,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: .9),
                          fallback: TeenFonts.sansFallback,
                          shadows: [
                            cssTextShadow(0, 0, 16, const Color(0xF2D8B4FF)),
                            cssTextShadow(0, 0, 34, const Color(0xD9A855F7)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (bright != 1 || sat != 1) {
            orb = ColorFiltered(colorFilter: cssSaturateBrightness(sat, bright), child: orb);
          }
          final m = Matrix4.identity()
            ..translateByDouble(origin.dx, origin.dy + ty, 0, 1)
            ..rotateZ(rot)
            ..scaleByDouble(sc, sc, 1, 1)
            ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform(transform: m, child: orb),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.glow,
    required this.aura,
    required this.danger,
    required this.flash,
  });

  /// bobble phase 0..1 (box-shadow glow keyframes).
  final double glow;
  final double aura;
  final bool danger;

  /// explode 25%: drop-shadow(0 0 40px rgba(192,132,252,1)).
  final double flash;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    final c = r.center;

    // ::after aura: inset -16px, conic gradient, blur(7px), spinning.
    final auraRect = r.inflate(16);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(aura * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawOval(
      auraRect,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..shader = const SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            Color(0x00A855F7),
            Color(0x99D8B4FF),
            Color(0x00A855F7),
            Color(0x8C7C3AED),
            Color(0x00D8B4FF),
            Color(0x00D8B4FF),
          ],
          stops: [0, 55 / 360, 140 / 360, 220 / 360, 320 / 360, 1],
        ).createShader(auraRect),
    );
    canvas.restore();

    // outer glows (bobble keyframes 0%↔50%)
    final g1 = 26 + 14 * glow, g2 = 50 + 30 * glow;
    final c1 = Color.lerp(const Color(0xB3A855F7), const Color(0xF2C084FC), glow)!;
    final c2 = Color.lerp(const Color(0x807C3AED), const Color(0xB3A855F7), glow)!;
    paintOuterGlow(canvas, r, g2, c2);
    paintOuterGlow(canvas, r, g1, c1);
    if (danger) {
      // drop-shadow(0 0 14px rgba(236,72,153,.9))
      paintOuterGlow(canvas, r, 14, const Color(0xE6EC4899));
    }
    if (flash > 0) {
      paintOuterGlow(canvas, r, 40, const Color(0xFFC084FC).withValues(alpha: flash));
    }

    // body: radial-gradient(circle at 50% 45%, …) farthest-corner
    final bc = Offset(s.width * .5, s.height * .45);
    final far = Offset(s.width - bc.dx, s.height - bc.dy).distance;
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.1),
          radius: far / s.shortestSide,
          colors: const [
            Color(0xFFF0E0FF), Color(0xFFC79BFF), Color(0xFFA855F7),
            Color(0xFF7C3AED), Color(0xFF4C1D95),
          ],
          stops: const [0, .22, .5, .74, 1],
        ).createShader(r),
    );
    // highlight: radial-gradient(circle at 30% 26%, rgba(255,255,255,.85) 0, transparent 18%)
    final hc = Offset(s.width * .30, s.height * .26);
    final hfar = Offset(s.width - hc.dx, s.height - hc.dy).distance;
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    canvas.drawCircle(
      hc,
      hfar * .18,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: .85), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: hc, radius: hfar * .18)),
    );
    canvas.restore();
    paintInsetShadow(canvas, r, const Offset(-12, -18), 30, const Color(0x73280050));
    paintInsetShadow(canvas, r, const Offset(10, 12), 26, Colors.white.withValues(alpha: .45));
  }

  @override
  bool shouldRepaint(_OrbPainter o) =>
      o.glow != glow || o.aura != aura || o.danger != danger || o.flash != flash;
}

/// Static title balloon of the plain start screen (`.title-balloon`) with
/// its label kanji; titlePulse 1.5s.
class TitleOrb extends StatefulWidget {
  const TitleOrb({super.key, required this.label, required this.width, required this.height, required this.labelSize});
  final String label;
  final double width;
  final double height;
  final double labelSize;

  @override
  State<TitleOrb> createState() => _TitleOrbState();
}

class _TitleOrbState extends State<TitleOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  late final AnimationController _aura =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    _aura.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _aura]),
      builder: (context, _) {
        final p = pingPong(_pulse.value);
        final origin = Offset(w / 2, h * .92);
        final sc = 1 + .05 * p;
        final m = Matrix4.identity()
          ..translateByDouble(origin.dx, origin.dy - 8 * p, 0, 1)
          ..rotateZ((-3 + 6 * p) * _deg)
          ..scaleByDouble(sc, sc, 1, 1)
          ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
        return Transform(
          transform: m,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(size: Size(w, h), painter: _TitleOrbPainter(_aura.value)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: h * .38 - widget.labelSize * .7,
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: ts(
                      family: TeenFonts.zen,
                      size: widget.labelSize,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.4,
                      shadows: [cssTextShadow(2, 2, 4, Colors.black.withValues(alpha: .3))],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleOrbPainter extends CustomPainter {
  _TitleOrbPainter(this.aura);
  final double aura;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    final c = r.center;
    final auraRect = r.inflate(14);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(aura * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawOval(
      auraRect,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..shader = const SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            Color(0x00A855F7), Color(0x99D8B4FF), Color(0x00A855F7),
            Color(0x8C7C3AED), Color(0x00D8B4FF), Color(0x00D8B4FF),
          ],
          stops: [0, 55 / 360, 140 / 360, 220 / 360, 320 / 360, 1],
        ).createShader(auraRect),
    );
    canvas.restore();
    paintOuterGlow(canvas, r, 56, const Color(0x8C7C3AED));
    paintOuterGlow(canvas, r, 28, const Color(0xBFA855F7));
    final bc = Offset(s.width * .5, s.height * .45);
    final far = Offset(s.width - bc.dx, s.height - bc.dy).distance;
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.1),
          radius: far / s.shortestSide,
          colors: const [
            Color(0xFFF0E0FF), Color(0xFFC79BFF), Color(0xFFA855F7),
            Color(0xFF7C3AED), Color(0xFF4C1D95),
          ],
          stops: const [0, .22, .5, .74, 1],
        ).createShader(r),
    );
    paintInsetShadow(canvas, r, const Offset(-10, -16), 26, const Color(0x73280050));
    paintInsetShadow(canvas, r, const Offset(8, 10), 22, Colors.white.withValues(alpha: .45));
    // ::before highlight: top 16% left 20%, 30% × 32%
    paintEllipseGradient(
      canvas,
      Rect.fromLTWH(s.width * .2, s.height * .16, s.width * .3, s.height * .32),
      [Colors.white.withValues(alpha: .6), Colors.white.withValues(alpha: 0)],
      const [0, .7],
    );
  }

  @override
  bool shouldRepaint(_TitleOrbPainter o) => o.aura != aura;
}

// ===================================================================
// Character (`.stickman`): normal / danger / happy / shocked.
// ===================================================================

enum Mood { normal, danger, happy, shocked }

class Fighter extends StatefulWidget {
  const Fighter({
    super.key,
    required this.mood,
    required this.serial,
    required this.normal,
    required this.danger,
    required this.shocked,
    this.width = 165,
    this.height = 200,
  });

  final Mood mood;

  /// Bumped when happy/shocked should replay their one-shot animation.
  final int serial;
  final String normal;
  final String danger;
  final String shocked;
  final double width;
  final double height;

  @override
  State<Fighter> createState() => _FighterState();
}

class _FighterState extends State<Fighter> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didUpdateWidget(Fighter old) {
    super.didUpdateWidget(old);
    if (widget.serial != old.serial &&
        (widget.mood == Mood.happy || widget.mood == Mood.shocked)) {
      _c.forward(from: 0);
    } else if (widget.mood != old.mood &&
        (widget.mood == Mood.normal || widget.mood == Mood.danger)) {
      _c.value = 0;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    final img = switch (widget.mood) {
      Mood.normal || Mood.happy => 0,
      Mood.danger => 1,
      Mood.shocked => 2,
    };
    final images = [widget.normal, widget.danger, widget.shocked];
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ::before glow behind the character (dark theme rule)
          Positioned(
            left: w / 2 - w * .75,
            top: h * .52 - h * .65,
            width: w * 1.5,
            height: h * 1.3,
            child: const CustomPaint(painter: _GlowPainter(Color(0x4DD8B4FF))),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = _c.value;
              var dx = 0.0, dy = 0.0, rot = 0.0, sc = 1.0;
              if (widget.mood == Mood.happy && _c.isAnimating) {
                dy = kf(t, [0, .3, .6, 1], [0, -35, -35, 0], curve: Curves.easeOut);
                rot = kf(t, [0, .3, .6, 1], [0, -5, 5, 0], curve: Curves.easeOut);
              } else if (widget.mood == Mood.shocked) {
                dx = kf(t, [0, .15, 1], [0, 0, 35], curve: Curves.easeOut);
                dy = kf(t, [0, .15, 1], [0, -10, -15], curve: Curves.easeOut);
                rot = kf(t, [0, .15, 1], [0, 0, 28], curve: Curves.easeOut);
                sc = kf(t, [0, .15, 1], [1, 1.1, .9], curve: Curves.easeOut);
              }
              final m = Matrix4.identity()
                ..translateByDouble(w / 2 + dx, h + dy, 0, 1)
                ..rotateZ(rot * _deg)
                ..scaleByDouble(sc, sc, 1, 1)
                ..translateByDouble(-w / 2, -h, 0, 1);
              return Transform(transform: m, child: child);
            },
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned.fill(
                    child: Opacity(
                      opacity: i == img ? 1 : 0,
                      child: ArtShadow(
                        color: const Color(0x2E1F3864),
                        offset: const Offset(0, 4),
                        blur: 6,
                        child: Image.asset(
                          images[i],
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintEllipseGradient(
        canvas,
        Offset.zero & size,
        [color, color.withValues(alpha: 0)],
        const [0, .7],
      );

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color;
}

/// Title-screen character with fighterBounce 1s (`.title-stickman`).
class BouncingFighter extends StatefulWidget {
  const BouncingFighter({super.key, required this.image, required this.width, required this.height});
  final String image;
  final double width;
  final double height;

  @override
  State<BouncingFighter> createState() => _BouncingFighterState();
}

class _BouncingFighterState extends State<BouncingFighter> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: w / 2 - w * .75,
            top: h * .52 - h * .65,
            width: w * 1.5,
            height: h * 1.3,
            child: const CustomPaint(painter: _GlowPainter(Color(0x4DD8B4FF))),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final p = pingPong(_c.value);
                return Transform.translate(
                  offset: Offset(0, -6 * p),
                  child: Transform.rotate(angle: (-2 + 4 * p) * _deg, child: child),
                );
              },
              child: ArtShadow(
                color: const Color(0x2E1F3864),
                offset: const Offset(0, 4),
                blur: 6,
                child: Image.asset(widget.image,
                    fit: BoxFit.contain, alignment: Alignment.bottomCenter),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Explosion: burst pieces + shockwave ring, BOOM! text, screen shake.
// ===================================================================

/// One-shot animation driven by [serial]: plays [duration] each time the
/// serial changes, then rests at t = 1 (invisible for all users here).
abstract class OneShot extends StatefulWidget {
  const OneShot({super.key, required this.serial});
  final int serial;
  Duration get duration;
  Widget buildAt(BuildContext context, double t);

  @override
  State<OneShot> createState() => _OneShotState();
}

class _OneShotState extends State<OneShot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration, value: 1);

  @override
  void didUpdateWidget(OneShot old) {
    super.didUpdateWidget(old);
    if (widget.serial != old.serial) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            _c.value >= 1 && !_c.isAnimating ? const SizedBox.shrink() : widget.buildAt(context, _c.value),
      );
}

/// `.burst.show`: 8 particles (pieceFly .7s) + shockwave ring.
class Burst extends OneShot {
  const Burst({super.key, required super.serial});

  @override
  Duration get duration => const Duration(milliseconds: 700);

  static const _pieces = [
    (-100.0, -80.0, false), (90.0, -90.0, false), (-110.0, 30.0, false), (100.0, 40.0, false),
    (-40.0, -130.0, true), (50.0, -120.0, true), (-130.0, -20.0, true), (120.0, -30.0, true),
  ];

  @override
  Widget buildAt(BuildContext context, double t) {
    final ring = Curves.easeOut.transform(t);
    return SizedBox(
      width: 1,
      height: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -20,
            top: -20,
            child: Opacity(
              opacity: (1 - ring).clamp(0, 1),
              child: Transform.scale(
                scale: 6 * ring,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xF2D8B4FF), width: 4),
                    boxShadow: [cssShadow(0, 0, 22, const Color(0xE6A855F7))],
                  ),
                ),
              ),
            ),
          ),
          for (final (tx, ty, light) in _pieces)
            Positioned(
              left: -7 + kf(t, [0, .3, 1], [0, tx * .5, tx], curve: Curves.easeOut),
              top: -7 + kf(t, [0, .3, 1], [0, ty * .5, ty + 60], curve: Curves.easeOut),
              child: Opacity(
                opacity: kf(t, [0, .3, 1], [1, 1, 0], curve: Curves.easeOut).clamp(0, 1),
                child: Transform.scale(
                  scale: kf(t, [0, .3, 1], [0, 1.2, .3], curve: Curves.easeOut),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: light ? const Color(0xFFE9D5FF) : const Color(0xFFA855F7),
                      boxShadow: [
                        light
                            ? cssShadow(0, 0, 12, const Color(0xFFD8B4FF))
                            : cssShadow(0, 0, 10, const Color(0xE6A855F7)),
                      ],
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

/// `.boom-text.show`: "BOOM!" boomPop .7s ease-out.
class BoomText extends OneShot {
  const BoomText({super.key, required super.serial});

  @override
  Duration get duration => const Duration(milliseconds: 700);

  @override
  Widget buildAt(BuildContext context, double t) {
    const times = [0.0, .4, .7, 1.0];
    final sc = kf(t, times, [0, 1.4, 1.1, 1], curve: Curves.easeOut);
    final rot = kf(t, times, [-25, 12, -3, 0], curve: Curves.easeOut);
    final op = kf(t, times, [1, 1, 1, 0], curve: Curves.easeOut);
    return Opacity(
      opacity: op.clamp(0, 1),
      child: Transform.rotate(
        angle: rot * _deg,
        child: Transform.scale(
          scale: sc,
          child: Text(
            'BOOM!',
            softWrap: false,
            style: ts(
              family: TeenFonts.bungee,
              size: 62,
              color: const Color(0xFFD8B4FE),
              height: 1.2,
              shadows: [
                cssTextShadow(0, 0, 22, const Color(0xFFC084FC)),
                cssTextShadow(0, 0, 44, const Color(0xE6A855F7)),
                cssTextShadow(4, 4, 0, const Color(0xFF7C3AED)),
                cssTextShadow(8, 8, 0, TeenColors.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.combo.show`: "COMBO ×n!" comboPop .8s ease-out.
class ComboBadge extends OneShot {
  const ComboBadge({super.key, required super.serial, required this.n});
  final int n;

  @override
  Duration get duration => const Duration(milliseconds: 800);

  @override
  Widget buildAt(BuildContext context, double t) {
    const times = [0.0, .3, .6, 1.0];
    final sc = kf(t, times, [0, 1.3, 1, 1], curve: Curves.easeOut);
    final rot = kf(t, times, [-15, 8, 0, 0], curve: Curves.easeOut);
    final op = kf(t, times, [1, 1, 1, 0], curve: Curves.easeOut);
    return Opacity(
      opacity: op.clamp(0, 1),
      child: Transform.rotate(
        angle: rot * _deg,
        child: Transform.scale(
          scale: sc,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: TeenColors.goldBright,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TeenColors.navy, width: 2),
              boxShadow: [cssShadow(0, 3, 0, TeenColors.navy)],
            ),
            child: Text('COMBO ×$n!',
                style: ts(
                    family: TeenFonts.russo,
                    size: 13,
                    color: TeenColors.navyDeep,
                    fallback: TeenFonts.sansFallback)),
          ),
        ),
      ),
    );
  }
}

/// `document.body.animate([...], {duration:400})` after an explosion.
Offset shakeOffset(double t) {
  const xs = [0.0, -8.0, 8.0, -5.0, 0.0];
  const ys = [0.0, 6.0, -6.0, 3.0, 0.0];
  const times = [0.0, .25, .5, .75, 1.0];
  return Offset(kf(t, times, xs, curve: Curves.linear), kf(t, times, ys, curve: Curves.linear));
}
