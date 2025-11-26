// lib/screens/game_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../controllers/ultimate_input_controller.dart';
import '../core/enums/game_enums.dart';
import '../core/constants/game_constants.dart';
import '../core/constants/app_colors.dart';

import '../widgets/game/game_painter.dart';
import '../widgets/game/game_header.dart';
import '../widgets/game/power_up_status.dart';
import '../widgets/screen_shake.dart';

import 'game_completion_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameController _gameController;
  late UltimateInputController _inputController;
  late AnimationController _animationController;
  final GlobalKey<ScreenShakeState> _shakeKey = GlobalKey<ScreenShakeState>();
  bool _isGameInitialized = false;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _inputController = UltimateInputController(
      threshold: 0.2,  // Ultra-fast: 0.5px
      queueLimit: 6,
    );

    // Attach input controller to game controller so the game loop polls it
    _gameController.attachInputController(_inputController);

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _gameController.shakeNotifier.addListener(_onShake);
  }

  void _onShake() {
    _shakeKey.currentState?.shake();
  }

  void _onState() {
    if (_gameController.gameState.state == GameState.gameOver) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _showGameOver();
      });
    } else if (_gameController.gameState.state == GameState.completed) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _showCompletion();
      });
    }
  }

  void _showCompletion() {
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameCompletionScreen(
          score: _gameController.gameState.score,
          duration: _gameController.totalDuration,
        ),
      ),
    );
  }

  Future<void> _showPauseMenu() async {
    _gameController.togglePause();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.backgroundSecondary,
                AppColors.background
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.warning,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause, color: AppColors.warning, size: 60),
              const SizedBox(height: 16),
              const Text(
                "PAUSED",
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _btn(
                      "Menu",
                      Icons.home,
                      AppColors.textSecondary,
                      () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _btn(
                      "Resume",
                      Icons.play_arrow,
                      AppColors.accent,
                      () {
                        Navigator.pop(context);
                        _gameController.togglePause();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameController.shakeNotifier.removeListener(_onShake);
    _gameController.removeListener(_onState);
    _gameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ChangeNotifierProvider.value(
        value: _gameController,
        child: Consumer<GameController>(
          builder: (context, controller, _) {
            return ScreenShake(
              key: _shakeKey,
              child: Stack(
                children: [
                  Positioned(
                    top: 100.0,
                    bottom: 80.0,
                    left: 0.0,
                    right: 0.0,
                    child: Listener(
                      onPointerDown: _inputController.onPointerDown,
                      onPointerMove: (e) {
                        _inputController.onPointerMove(e);
                        // Apply direction IMMEDIATELY for instant response
                        final dir = _inputController.popForTick();
                        if (dir != null) {
                          controller.applyQueuedDirection(dir);
                          // Sync controller with actual game direction after applying
                          _inputController.lastApplied = controller.gameState.direction;
                        }
                      },
                      onPointerUp: _inputController.onPointerUp,
                      onPointerCancel: _inputController.onPointerCancel,
                      behavior: HitTestBehavior.opaque,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest;

                          if (!_isGameInitialized) {
                            controller.updateDimensions(size); 
                            controller.initGame();
                            controller.startGame();
                            controller.addListener(_onState);
                            _isGameInitialized = true;
                          }

                          return CustomPaint(
                            size: size,
                            painter: GamePainter(
                              level: controller.gameState.level,
                              snake: controller.gameState.snake,
                              food: controller.gameState.food,
                              isGoldenFood: controller.gameState.isGoldenFood,
                              powerUps: controller.gameState.powerUps,
                              particles: controller.particleSystem.particles,
                              staticObstacles:
                                  controller.gameState.staticObstacles,
                              movingObstacles: controller.gameState.movingObstacles,
                              enemySnake: controller.enemySnake,
                              portal: controller.portal,
                              hasShield: controller.gameState.hasShield,
                              hasGhost: controller.gameState.hasGhost,
                              gridSize: GameConstants.gridSize,
                              verticalGridSize: controller.verticalGridSize,
                              snakeColor: controller.snakeColor,
                              moveProgress: controller.moveProgress,
                              lastTailPos: controller.lastTailPos,
                              animationValue:
                                  _animationController.value * 2 * pi,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 26,
                    left: 20,
                    right: 20,
                    child: GameHeader(
                      score: controller.gameState.score,
                      level: controller.gameState.level,
                      combo: controller.gameState.combo,
                      fusionGauge: controller.fusionGauge,
                      isFusionMode: controller.isFusionMode,
                      onMenuPressed: _showPauseMenu,
                    ),
                  ),
                  Positioned(
                    bottom: 25,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: PowerUpStatusBar(
                        activePowerUps:
                            controller.gameState.activePowerUps,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showGameOver() {
    final gs = _gameController.gameState;
    final isNew = gs.isNewHighScore;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.backgroundSecondary,
                AppColors.background
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNew ? AppColors.success : AppColors.error,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNew ? Icons.emoji_events : Icons.sports_esports,
                color: isNew ? AppColors.success : AppColors.error,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                isNew ? "NEW RECORD!" : "GAME OVER",
                style: TextStyle(
                  color: isNew ? AppColors.success : AppColors.error,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              _row("Score", "${gs.score}", AppColors.accent),
              const SizedBox(height: 8),
              _row("Level", "${gs.level}", AppColors.warning),
              const SizedBox(height: 8),
              _row("Max Combo", "${gs.combo}x", AppColors.success),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _btn("Menu", Icons.home, AppColors.textSecondary,
                        () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _btn("Play Again", Icons.refresh, AppColors.accent,
                        () {
                      Navigator.pop(context);
                      _gameController.initGame();
                      _gameController.startGame();
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
            )),

        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }

  Widget _btn(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(.2),
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
