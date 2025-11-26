import 'package:flutter/material.dart';
import '../core/enums/game_enums.dart';
import '../core/constants/app_colors.dart';

class PowerUp {
  final Offset position;
  final PowerUpType type;
  final int duration;
  PowerUp({required this.position, required this.type, required this.duration});
  Color get color {
    switch (type) {
      case PowerUpType.speedBoost: return AppColors.speedBoost;
      case PowerUpType.shield: return AppColors.shield;
      case PowerUpType.doubleScore: return AppColors.doubleScore;
      case PowerUpType.slowMotion: return AppColors.slowMotion;
      case PowerUpType.ghost: return Colors.deepPurple;
    }
  }
  bool get isExpired => false;
  PowerUp copyWith({Offset? position, double? rotation}) => PowerUp(position: position ?? this.position, type: type, duration: duration);
}
