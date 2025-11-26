// lib/core/constants/game_constants.dart
class GameConstants {
  static const int gridSize = 20;
  static const int baseSpeed = 200;
  static const int speedIncrement = 10;
  static const int minSpeed = 50;
  static const int maxSpeed = 200;
  static const int levelUpThreshold = 500;
  static const int foodPoints = 10;
  
  static const double speedBoostMultiplier = 0.7;
  static const double slowMotionMultiplier = 1.4;
  
  static const double powerUpSpawnChance = 0.15;
  
  static const int speedBoostDuration = 100;
  static const int shieldDuration = 150;
  static const int slowMotionDuration = 100;

  static const double snakeOffset = 0.12;

  // New constants
  static const int magnetDuration = 70;
  static const int ghostDuration = 50;
  static const int multiplierDuration = 60;

  static const int devilLevelFrequency = 5;
  static const int devilLevelReverseDuration = 5; // seconds
  
  static const int maxLevel = 10; // Game completion level
}