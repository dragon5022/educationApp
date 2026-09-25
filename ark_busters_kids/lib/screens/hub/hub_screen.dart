import 'package:flutter/material.dart';

import '../../core/constants/game_modes.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../widgets/page_background.dart';
import '../listening/listening_screens.dart';
import '../meta/meta_screens.dart';
import '../sentence/sentence_screens.dart';
import '../talk/talk_screens.dart';
import '../vocab/vocab_screens.dart';

/// Hub must be StatefulWidget so we can start BGM in [initState].
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  @override
  void initState() {
    super.initState();
    // Start hub music when this screen opens (web: startBGM on first interaction;
    // on mobile we can start immediately).
    AudioService.instance.playHubBgm();
  }

  Future<void> _toggleBgm() async {
    await AudioService.instance.toggleBgm();
    if (mounted) setState(() {}); // refresh 🔊 / 🔇 icon
  }

  void _openMode(BuildContext context, GameMode mode) {
    final Widget page = switch (mode.id) {
      GameModeId.vocab => const VocabHomeScreen(),
      GameModeId.listening => const ListeningHomeScreen(),
      GameModeId.talk => const TalkHomeScreen(),
      GameModeId.sentence => const SentenceHomeScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final bgmOn = AudioService.instance.isBgmOn;

    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        const _HeroBanner(),
                        const SizedBox(height: 10),
                        const _BrandHeader(),
                        const SizedBox(height: 8),
                        const _LeadBanner(),
                        const SizedBox(height: 18),
                        ...kGameModes.map(
                          (mode) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _ModeCard(
                              mode: mode,
                              onTap: () => _openMode(context, mode),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _BottomNav(),
                ],
              ),
              // Web .bgm-btn: white circle, gold border, emoji 🔊 / 🔇
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleBgm,
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          // Same characters as web &#128266; / &#128263;
                          bgmOn ? '🔊' : '🔇',
                          style: const TextStyle(fontSize: 16, height: 1),
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
    );
  }
}

/// Matches web `.hero`: one full PNG, width 100%, height auto — no overlays.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  // kidtop1.png is 666×375
  static const aspect = 666 / 375;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Image.asset(
            'assets/images/hub/kidtop1.png',
            fit: BoxFit.contain,
            width: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: Color(0xFFFFE9A8),
                child: Center(
                  child: Text(
                    'ARK English Busters',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Matches web `.brand` / `.brand-title` / `.kids`
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  // Web:
  // .brand-title { text-shadow: 2px 2px 0 purple, 3px 3px 0 blue-deep, 0 0 16px white60 }
  // .kids        { color: gold; text-shadow: 2px 2px 0 yellow-deep, 3px 3px 0 #fff }
  static const _titleShadows = <Shadow>[
    Shadow(offset: Offset(2, 2), color: AppColors.purple),
    Shadow(offset: Offset(3, 3), color: AppColors.blueDeep),
    Shadow(offset: Offset(0, 0), blurRadius: 16, color: Color(0x99FFFFFF)),
  ];

  static const _kidsShadows = <Shadow>[
    Shadow(offset: Offset(2, 2), color: AppColors.yellowDeep),
    Shadow(offset: Offset(3, 3), color: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: 'Bungee',
              fontSize: 34,
              height: 1,
              letterSpacing: 0.68, // ~0.02em at 34px
              color: Colors.white,
              shadows: _titleShadows,
            ),
            children: const [
              TextSpan(text: 'ARK BUSTERS '),
              TextSpan(
                text: 'KIDS',
                style: TextStyle(
                  color: AppColors.gold,
                  shadows: _kidsShadows,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        const Text(
          'アーク総合学院',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8, // ~0.12em
          ),
        ),
      ],
    );
  }
}

/// App-styled prompt (no white card / border — reads on purple hub bg).
class _LeadBanner extends StatelessWidget {
  const _LeadBanner();

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: AppColors.cream,
      fontSize: 16,
      height: 1.45,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w800,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '★',
            style: TextStyle(color: AppColors.gold, fontSize: 18, height: 1),
          ),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'たたかうモンスターを\nえらんでね',
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
          SizedBox(width: 10),
          Text(
            '★',
            style: TextStyle(color: AppColors.gold, fontSize: 18, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Matches web `.wcard`: single card PNG + drop-shadow only (frame is in the art).
class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  // card-*.png are 800×267
  static const aspect = 800 / 267;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: aspect,
              child: Image.asset(
                mode.cardAsset,
                fit: BoxFit.contain,
                width: double.infinity,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) =>
                    _CardFallback(mode: mode),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFallback extends StatelessWidget {
  const _CardFallback({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: Center(
        child: Text(
          mode.titleJa,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1147),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            asset: 'assets/images/hub/collection.png',
            label: 'コレクション',
            onTap: () => _open(context, const CollectionScreen()),
          ),
          _NavItem(
            asset: 'assets/images/hub/profile.png',
            label: 'プロフィール',
            onTap: () => _open(context, const ProfileScreen()),
          ),
          _NavItem(
            asset: 'assets/images/hub/setting.png',
            label: 'せってい',
            onTap: () => _open(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              asset,
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.star, color: AppColors.gold, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
