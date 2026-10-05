import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../services/audio_service.dart';

/// Page background: `linear-gradient(180deg,#1a2742,#0d1626)` fixed, plus the
/// `body::before` dust (three tiled radial dots). The dots twinkle very
/// slowly (app polish; the web dots are static).
class ArkBackground extends StatefulWidget {
  const ArkBackground({super.key, required this.child});
  final Widget child;

  @override
  State<ArkBackground> createState() => _ArkBackgroundState();
}

class _ArkBackgroundState extends State<ArkBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TeenColors.bgTop, TeenColors.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _DustPainter(_c)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // (tile, x%, y%, color)
  static const _layers = [
    (80.0, .20, .30, Color(0x0FFFC83D)),
    (100.0, .70, .60, Color(0x0DD8B4FF)),
    (60.0, .40, .80, Color(0x0DFFC83D)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    var k = 0;
    for (final (tile, fx, fy, color) in _layers) {
      for (var y = 0.0; y < size.height; y += tile) {
        for (var x = 0.0; x < size.width; x += tile) {
          k++;
          // ~1 in 7 dots breathes up to 4x brighter.
          var a = color.a;
          if (k % 7 == 0) {
            final w = math.sin((t.value + k * 0.137) * 2 * math.pi);
            a = (a * (1 + 3 * math.max(0, w))).clamp(0, 1);
          }
          p.color = color.withValues(alpha: a);
          canvas.drawCircle(Offset(x + tile * fx, y + tile * fy), 1.5, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => false;
}

/// Tap target that sinks like the web `:active` rules (translateY + a
/// shorter hard shadow), passing the pressed state to [builder].
class PressDown extends StatefulWidget {
  const PressDown({
    super.key,
    required this.builder,
    this.onTap,
    this.haptic = true,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<PressDown> createState() => _PressDownState();
}

class _PressDownState extends State<PressDown> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: widget.builder(context, _down),
    );
  }
}

/// The ❤️ emoji of the HUD, drawn so it looks the same on every platform.
class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _HeartPainter());
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(w * .5, h * .93)
      ..cubicTo(w * .18, h * .70, -w * .02, h * .48, w * .04, h * .27)
      ..cubicTo(w * .10, h * .05, w * .38, h * .02, w * .5, h * .24)
      ..cubicTo(w * .62, h * .02, w * .90, h * .05, w * .96, h * .27)
      ..cubicTo(w * 1.02, h * .48, w * .82, h * .70, w * .5, h * .93)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          radius: 1.0,
          colors: [Color(0xFFFF6B7A), Color(0xFFF2263B), Color(0xFFC40F25)],
          stops: [0, .45, 1],
        ).createShader(Offset.zero & s),
    );
    canvas.drawOval(
      Rect.fromLTWH(w * .17, h * .17, w * .2, h * .13),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🔊 / 🔇 emoji of the music button.
class SpeakerIcon extends StatelessWidget {
  const SpeakerIcon({super.key, required this.on, this.size = 20});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SpeakerPainter(on));
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter(this.on);
  final bool on;

  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 20;
    final body = Path()
      ..moveTo(2 * u, 7.2 * u)
      ..lineTo(5.6 * u, 7.2 * u)
      ..lineTo(10.4 * u, 3 * u)
      ..lineTo(10.4 * u, 17 * u)
      ..lineTo(5.6 * u, 12.8 * u)
      ..lineTo(2 * u, 12.8 * u)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3E7EB), Color(0xFF9AA4AE)],
        ).createShader(Offset.zero & s),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9 * u
        ..color = const Color(0xFF59636D),
    );
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5 * u;
    if (on) {
      wave.color = const Color(0xFF3FA9F5);
      for (final r in [3.4, 6.2]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(11 * u, 10 * u), radius: r * u),
          -0.9,
          1.8,
          false,
          wave,
        );
      }
    } else {
      wave.color = const Color(0xFF9AA4AE);
      canvas.drawLine(Offset(13 * u, 7.5 * u), Offset(18 * u, 12.5 * u), wave);
      canvas.drawLine(Offset(18 * u, 7.5 * u), Offset(13 * u, 12.5 * u), wave);
    }
  }

  @override
  bool shouldRepaint(_SpeakerPainter old) => old.on != on;
}

/// `.bgm-btn`: fixed round speaker button (top 10, right 10, 42×42),
/// shown on every screen like the web.
class BgmButton extends StatelessWidget {
  const BgmButton({super.key});

  @override
  Widget build(BuildContext context) {
    final a = AudioService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: a.bgmOn,
      builder: (context, on, _) => Semantics(
        button: true,
        label: 'music',
        child: PressDown(
          haptic: false,
          onTap: a.toggleBgm,
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
                boxShadow: [cssShadow(0, 2, 8, Colors.black.withValues(alpha: .4))],
              ),
              child: SpeakerIcon(on: on, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `radial-gradient(ellipse, …)` (farthest-corner) filling [rect]:
/// paints an elliptical glow whose stops are relative to the half-diagonal.
void paintEllipseGradient(
  Canvas canvas,
  Rect rect,
  List<Color> colors,
  List<double> stops,
) {
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  final sy = rect.height / rect.width;
  canvas.scale(1, sy);
  // farthest-corner ellipse keeps the box aspect and passes through the
  // corner: radius = half-width * sqrt(2).
  final r = rect.width / 2 * math.sqrt2;
  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = RadialGradient(colors: colors, stops: stops)
          .createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
  );
  canvas.restore();
}

/// Paints a CSS `inset` box-shadow inside an ellipse [rect].
void paintInsetShadow(
  Canvas canvas,
  Rect rect,
  Offset offset,
  double blur,
  Color color,
) {
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  final outer = rect.inflate(blur * 2 + offset.distance + 10);
  final hole = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(outer)
    ..addOval(rect.shift(offset));
  canvas.drawPath(
    hole,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
  );
  canvas.restore();
}

/// CSS `box-shadow: 0 0 blur color` around an ellipse.
void paintOuterGlow(Canvas canvas, Rect rect, double blur, Color color) {
  canvas.drawOval(
    rect,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blur / 2),
  );
}
