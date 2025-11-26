// lib/models/game_state.dart
import 'package:flutter/material.dart';
import '../core/enums/game_enums.dart';
import '../models/power_up.dart';

class GameStateModel {
  final List<Offset> snake;
  final Offset food;
  final bool isGoldenFood; // <-- ADDED
  final Direction direction;
  final Direction? nextDirection;
  final int score;
  final int level;
  final GameState state;
  final List<PowerUp> powerUps;
  final Map<PowerUpType, int> activePowerUps;
  final bool hasShield;
  final bool hasGhost;
  final int combo;
  final DateTime? lastFoodTime;
  final List<Offset> staticObstacles;
  final List<Offset> movingObstacles;
  final List<Offset> enemySnake;
  final Offset? portal;
  final bool waitingForPortal;
  final bool reverseControls;
  final bool isNewHighScore;

  int get scoreMultiplier =>
      activePowerUps.containsKey(PowerUpType.doubleScore) ? 2 : 1;

  GameStateModel({
    required this.snake,
    required this.food,
    this.isGoldenFood = false, // <-- ADDED
    this.direction = Direction.right,
    this.nextDirection,
    this.score = 0,
    this.level = 1,
    this.state = GameState.paused,
    this.powerUps = const [],
    this.activePowerUps = const {},
    this.hasShield = false,
    this.hasGhost = false,
    this.combo = 0,
    this.lastFoodTime,
    this.staticObstacles = const [],
    this.movingObstacles = const [],
    this.enemySnake = const [],
    this.portal,
    this.waitingForPortal = false,
    this.reverseControls = false,
    this.isNewHighScore = false,
  });

  factory GameStateModel.initial() {
    return GameStateModel(
      snake: const [Offset(5, 5), Offset(4, 5), Offset(3, 5)],
      food: const Offset(10, 10),
      state: GameState.paused,
      isGoldenFood: false, // <-- ADDED
    );
  }

  GameStateModel copyWith({
    List<Offset>? snake,
    Offset? food,
    bool? isGoldenFood, // <-- ADDED
    Direction? direction,
    Direction? nextDirection,
    int? score,
    int? level,
    GameState? state,
    List<PowerUp>? powerUps,
    Map<PowerUpType, int>? activePowerUps,
    bool? hasShield,
    bool? hasGhost,
    int? combo,
    DateTime? lastFoodTime,
    List<Offset>? staticObstacles,
    List<Offset>? movingObstacles,
    List<Offset>? enemySnake,
    Offset? portal,
    bool? waitingForPortal,
    bool? reverseControls,
    bool? isNewHighScore,
  }) {
    return GameStateModel(
      snake: snake ?? this.snake,
      food: food ?? this.food,
      isGoldenFood: isGoldenFood ?? this.isGoldenFood, // <-- ADDED
      direction: direction ?? this.direction,
      nextDirection: nextDirection,
      score: score ?? this.score,
      level: level ?? this.level,
      state: state ?? this.state,
      powerUps: powerUps ?? this.powerUps,
      activePowerUps: activePowerUps ?? this.activePowerUps,
      hasShield: hasShield ?? this.hasShield,
      hasGhost: hasGhost ?? this.hasGhost,
      combo: combo ?? this.combo,
      lastFoodTime: lastFoodTime ?? this.lastFoodTime,
      staticObstacles: staticObstacles ?? this.staticObstacles,
      movingObstacles: movingObstacles ?? this.movingObstacles,
      enemySnake: enemySnake ?? this.enemySnake,
      portal: portal ?? this.portal,
      waitingForPortal: waitingForPortal ?? this.waitingForPortal,
      reverseControls: reverseControls ?? this.reverseControls,
      isNewHighScore: isNewHighScore ?? this.isNewHighScore,
    );
  }
}