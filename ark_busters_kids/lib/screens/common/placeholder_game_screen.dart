import 'package:flutter/material.dart';

import '../../core/constants/game_modes.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/page_background.dart';

/// Temporary screen until each game mode is implemented.
class PlaceholderGameScreen extends StatelessWidget {
  const PlaceholderGameScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C33),
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                ),
              ),
              const Spacer(),
              Text(
                mode.titleJa,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mode.titleEn,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${mode.monsterName} バトル — Coming soon',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
