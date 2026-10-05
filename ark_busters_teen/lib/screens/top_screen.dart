import 'dart:math' as math;

import 'package:ark_core/ui.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/hub_catalog.dart';
import '../widgets/common.dart';
import 'settings_sheet.dart';
import 'stage/stage_screen.dart';

/// ark-top.html: hero art, brand, five subject tabs, enemy intro and the
/// stage cards of the selected subject.
class TopScreen extends StatefulWidget {
  const TopScreen({super.key});

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> {
  final _scroll = ScrollController();
  int _tab = 0; // web: 数学 is active on load

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    // web: window.scrollTo({top:0,behavior:'smooth'})
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _open(StageCard card) {
    final id = card.packId;
    if (id == null) return;
    Navigator.of(context).push(stageRoute(id));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final tab = subjectTabs[_tab];
    return Scaffold(
      body: Stack(
        children: [
          ArkBackground(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    minHeight: MediaQuery.sizeOf(context).height,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, pad.top, 16, pad.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Reveal(dy: 10, child: _Hero()),
                        const Reveal(
                          delay: Duration(milliseconds: 120),
                          dy: 10,
                          child: _Brand(),
                        ),
                        Reveal(
                          delay: const Duration(milliseconds: 200),
                          dy: 10,
                          child: _Tabs(active: _tab, onTap: _showTab),
                        ),
                        // web .panel.active{animation:fadeIn .25s ease}
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.ease,
                          layoutBuilder: (current, previous) =>
                              current ?? const SizedBox.shrink(),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: AnimatedBuilder(
                              animation: a,
                              builder: (context, c) => Transform.translate(
                                offset: Offset(0, 6 * (1 - a.value)),
                                child: c,
                              ),
                              child: child,
                            ),
                          ),
                          child: _Panel(
                            key: ValueKey(tab.id),
                            tab: tab,
                            onOpen: _open,
                          ),
                        ),
                        const _Footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // App extra: settings (account, unlock, question updates),
          // mirroring the fixed music button at the top right.
          Positioned(
            top: pad.top + 10,
            left: 10,
            child: const SettingsButton(),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: TeenColors.goldBright.withValues(alpha: .55),
          width: 3,
        ),
        gradient: const LinearGradient(
          begin: Alignment(-.35, -1),
          end: Alignment(.35, 1),
          colors: [Color(0xFF101A33), TeenColors.navy],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .3), spreadRadius: 1),
          cssShadow(0, 10, 30, Colors.black.withValues(alpha: .45)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: ShineSweep(
          period: const Duration(milliseconds: 6000),
          opacity: .28,
          child: AspectRatio(
            aspectRatio: 1448 / 1086,
            child: Image.asset(
              'assets/images/hub/top.webp',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final title = ts(
      family: TeenFonts.bungee,
      size: 30,
      color: TeenColors.goldBright,
      ls: .03,
      height: 1,
      shadows: [
        cssTextShadow(2, 2, 0, TeenColors.redDeep),
        cssTextShadow(0, 0, 18, TeenColors.goldBright.withValues(alpha: .55)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'ARK BUSTERS '),
                TextSpan(
                  text: 'TEEN',
                  style: title.copyWith(color: TeenColors.red),
                ),
              ],
            ),
            style: title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: .85,
            child: Text(
              'ARK SOGO GAKUIN PRESENTS',
              textAlign: TextAlign.center,
              style: ts(
                family: TeenFonts.bungee,
                size: 11,
                color: TeenColors.goldBright,
                ls: .35,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'アーク総合学院 バスターズ',
            textAlign: TextAlign.center,
            style: ts(
              family: TeenFonts.zen,
              size: 17,
              weight: FontWeight.w900,
              color: TeenColors.creamSoft,
              ls: .14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.onTap});
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (var i = 0; i < subjectTabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _Tab(
                tab: subjectTabs[i],
                active: i == active,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});
  final SubjectTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressDown(
      onTap: onTap,
      builder: (context, pressed) {
        final shadowY = pressed ? 1.0 : 3.0;
        return Transform.translate(
          offset: Offset(0, pressed ? 2 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active ? null : Colors.white.withValues(alpha: .06),
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [TeenColors.red, TeenColors.redDeep],
                    )
                  : null,
              border: Border.all(
                color: active
                    ? TeenColors.goldBright
                    : TeenColors.goldBright.withValues(alpha: .5),
                width: 2,
              ),
              boxShadow: active
                  ? [
                      cssShadow(0, shadowY, 0, TeenColors.redDeep),
                      cssShadow(0, 0, 16, TeenColors.red.withValues(alpha: .5)),
                    ]
                  : [
                      cssShadow(
                        0,
                        shadowY,
                        0,
                        Colors.black.withValues(alpha: .35),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.ja,
                  style: ts(
                    family: TeenFonts.zen,
                    size: 15,
                    weight: FontWeight.w900,
                    color: active ? Colors.white : TeenColors.creamSoft,
                    ls: .02,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Opacity(
                  opacity: active ? 1 : .8,
                  child: Text(
                    tab.en,
                    style: ts(
                      family: TeenFonts.bungee,
                      size: 7,
                      color: TeenColors.goldBright,
                      ls: .08,
                      height: 1.1,
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

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.tab, required this.onOpen});
  final SubjectTab tab;
  final ValueChanged<StageCard> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnemyIntro(enemy: tab.enemy),
        const _SectionTitle('テーマを選べ'),
        for (var i = 0; i < tab.cards.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == tab.cards.length - 1 ? 18 : 14,
            ),
            child: Reveal(
              delay: Duration(milliseconds: 60 + 55 * i),
              duration: const Duration(milliseconds: 420),
              dy: 14,
              child: _CardTile(
                card: tab.cards[i],
                onTap: () => onOpen(tab.cards[i]),
                index: i,
              ),
            ),
          ),
      ],
    );
  }
}

class _EnemyIntro extends StatelessWidget {
  const _EnemyIntro({required this.enemy});
  final Enemy enemy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: .45),
          width: 2,
        ),
        boxShadow: [cssShadow(0, 6, 18, Colors.black.withValues(alpha: .35))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final imgW = math.min(c.maxWidth * .42, 155.0);
          return Row(
            children: [
              SizedBox(
                width: imgW,
                child: _Float(
                  child: ArtShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: .6),
                    offset: const Offset(0, 4),
                    blur: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 941 / 1672,
                        child: Image.asset(enemy.image, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enemy.name,
                      style: ts(
                        family: TeenFonts.dela,
                        size: 20,
                        color: Colors.white,
                        height: 1.25,
                        shadows: [
                          cssTextShadow(
                            0,
                            0,
                            10,
                            const Color(0xFFA855F7).withValues(alpha: .75),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enemy.en,
                      style: ts(
                        family: TeenFonts.bungee,
                        size: 9,
                        color: TeenColors.goldBright,
                        ls: .16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      enemy.title,
                      style: ts(
                        family: TeenFonts.zen,
                        size: 12,
                        weight: FontWeight.w900,
                        color: TeenColors.goldBright,
                        ls: .03,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: .95,
                      child: Container(
                        padding: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: TeenColors.goldBright.withValues(
                                alpha: .55,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          enemy.quote,
                          style: ts(
                            family: TeenFonts.zen,
                            size: 12,
                            color: TeenColors.creamSoft,
                            height: 1.6,
                            style: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `@keyframes floatY` 2.8s ease-in-out: translateY 0 → -7px → 0.
class _Float extends StatefulWidget {
  const _Float({required this.child});
  final Widget child;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -7 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    Widget line() => Opacity(
      opacity: .8,
      child: Container(
        width: 30,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: TeenColors.goldBright,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line(),
          Text(
            text,
            style: ts(
              family: TeenFonts.zen,
              size: 15,
              weight: FontWeight.w900,
              color: TeenColors.creamSoft,
              ls: .15,
            ),
          ),
          line(),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.onTap,
    required this.index,
  });
  final StageCard card;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final enabled = card.packId != null;
    final tile = PressDown(
      onTap: enabled ? onTap : null,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, pressed ? 3 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TeenColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TeenColors.navy, width: 3),
          boxShadow: pressed
              ? [
                  cssShadow(0, 2, 0, TeenColors.navy),
                  cssShadow(0, 4, 10, Colors.black.withValues(alpha: .4)),
                ]
              : [
                  cssShadow(0, 5, 0, TeenColors.navy),
                  cssShadow(0, 8, 22, Colors.black.withValues(alpha: .4)),
                ],
        ),
        child: Row(
          children: [
            CardBalloon(letter: card.letter, color: card.color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: card.title),
                        if (card.isNew)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _NewBadge(),
                          ),
                      ],
                    ),
                    style: ts(
                      family: TeenFonts.zen,
                      size: 18,
                      weight: FontWeight.w900,
                      color: TeenColors.navyDeep,
                      ls: .05,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.sub,
                    style: ts(
                      family: TeenFonts.zen,
                      size: 11,
                      weight: FontWeight.w900,
                      color: TeenColors.gold,
                      ls: .1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CardAction(enabled: enabled, index: index),
          ],
        ),
      ),
    );
    return enabled ? tile : Opacity(opacity: .5, child: tile);
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TeenColors.redDeep, width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TeenColors.red, TeenColors.redDeep],
        ),
      ),
      child: Text(
        'NEW',
        style: ts(
          family: TeenFonts.zen,
          size: 10,
          weight: FontWeight.w900,
          color: Colors.white,
          ls: .06,
          height: 1.25,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.enabled, required this.index});
  final bool enabled;
  final int index;

  @override
  Widget build(BuildContext context) {
    final border = enabled ? TeenColors.navy : const Color(0xFF555555);
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 2),
        color: enabled ? null : const Color(0xFF7C7C7C),
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TeenColors.goldBright, TeenColors.gold],
              )
            : null,
        boxShadow: [cssShadow(0, 3, 0, border)],
      ),
      child: Text(
        enabled ? 'PLAY' : '準備中',
        style: ts(
          family: TeenFonts.russo,
          size: 13,
          color: Colors.white,
          ls: .1,
          fallback: TeenFonts.sansFallback,
        ),
      ),
    );
    if (!enabled) return box;
    return ShineSweep(
      delay: Duration(milliseconds: 300 * index),
      period: const Duration(milliseconds: 4600),
      opacity: .55,
      child: box,
    );
  }
}

/// `.card-balloon`: a glossy balloon with the stage's kanji and a tail.
class CardBalloon extends StatelessWidget {
  const CardBalloon({super.key, required this.letter, required this.color});
  final String letter;
  final BalloonColor color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 62,
      child: CustomPaint(
        painter: _CardBalloonPainter(color),
        child: Center(
          child: Text(
            letter,
            style: ts(
              family: TeenFonts.russo,
              size: 20,
              weight: FontWeight.w700,
              // `.card-balloon.red{color:var(--red-deep)}` overrides #fff
              color: color.tail,
              fallback: TeenFonts.sansFallback,
              shadows: [
                cssTextShadow(1, 1, 2, Colors.black.withValues(alpha: .3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBalloonPainter extends CustomPainter {
  _CardBalloonPainter(this.c);
  final BalloonColor c;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    // outer 0 4px 10px rgba(0,0,0,.15)
    canvas.drawOval(
      r.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: .15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // circle at 32% 30%, farthest-corner
    final center = Offset(s.width * .32, s.height * .30);
    final far = Offset(s.width - center.dx, s.height - center.dy).distance;
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(.32 * 2 - 1, .30 * 2 - 1),
          radius: far / s.shortestSide,
          colors: c.colors,
          stops: c.stops,
        ).createShader(r),
    );
    paintInsetShadow(
      canvas,
      r,
      const Offset(-5, -8),
      12,
      Colors.black.withValues(alpha: .2),
    );
    paintInsetShadow(
      canvas,
      r,
      const Offset(4, 5),
      10,
      Colors.white.withValues(alpha: .4),
    );
    // ::after tail: border-top 9px currentColor, filter brightness(.7)
    final t = c.tail;
    final tail = Color.from(
      alpha: 1,
      red: t.r * .7,
      green: t.g * .7,
      blue: t.b * .7,
    );
    final cx = s.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, s.height - 3)
        ..lineTo(cx + 6, s.height - 3)
        ..lineTo(cx, s.height + 6)
        ..close(),
      Paint()..color = tail,
    );
  }

  @override
  bool shouldRepaint(_CardBalloonPainter old) => old.c != c;
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 0),
      child: Opacity(
        opacity: .7,
        child: Text(
          'ARK SOGO GAKUIN',
          textAlign: TextAlign.center,
          style: ts(
            family: TeenFonts.zen,
            size: 10,
            weight: FontWeight.w700,
            color: TeenColors.goldBright,
            ls: .3,
          ),
        ),
      ),
    );
  }
}
