// lib/widgets/game/game_header.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GameHeader extends StatelessWidget {
  final int score;
  final int level;
  final int combo;
  final double fusionGauge;
  final bool isFusionMode;
  final VoidCallback onMenuPressed;

  const GameHeader({
    Key? key,
    required this.score,
    required this.level,
    required this.combo,
    required this.fusionGauge,
    required this.isFusionMode,
    required this.onMenuPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Column for Stats
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Score: $score',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),

            // Combo Display
            Text('Combo: $combo',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),

            Text('Level $level',
                style: const TextStyle(color: AppColors.textSecondary)),
            
            const SizedBox(height: 8),
            // Fusion Gauge
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(isFusionMode ? 'FUSION MODE!' : 'FUSION', 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: isFusionMode ? AppColors.accent : AppColors.textSecondary
                        )),
                   const SizedBox(height: 2),
                   LinearProgressIndicator(
                     value: fusionGauge,
                     backgroundColor: AppColors.backgroundSecondary,
                     color: isFusionMode ? AppColors.accent : AppColors.snakeHead,
                     minHeight: 4,
                   ),
                ],
              ),
            ),
          ]),

          // Right - ONLY the Menu Button
          IconButton(
            icon: const Icon(Icons.pause_circle, color: Colors.white, size: 32),
            onPressed: onMenuPressed,
          )
        ],
      ),
    );
  }
}