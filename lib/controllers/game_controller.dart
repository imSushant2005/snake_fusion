// lib/controllers/game_controller.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snake_fusion/core/constants/app_colors.dart';
import 'package:snake_fusion/models/leaderboard_entry.dart';

import '../ai/ai_controller.dart';
import '../ai/ai_enemy.dart';
import '../core/enums/game_enums.dart';
import '../core/constants/game_constants.dart';
import '../models/game_state.dart';
import '../models/power_up.dart';
import '../models/particle.dart';
import '../models/level_layout.dart';
import '../services/level_generator.dart';
import '../services/particle_system.dart';
import '../services/collision_detector.dart';
import '../core/utils/storage_manager.dart';
import '../core/utils/sound_manager.dart';
import '../services/settings_service.dart';

// NEW: import the UltimateInputController
import 'ultimate_input_controller.dart';

class GameController extends ChangeNotifier {
  GameStateModel _gameState = GameStateModel.initial();
  Timer? _gameTimer;

  final Random _random = Random();
  final ParticleSystem _particleSystem = ParticleSystem();
  final CollisionDetector _collision = CollisionDetector();
  final AIController _aiController = AIController();
  final LevelGeneratorV2 _levelGenerator = LevelGeneratorV2();

  int verticalGridSize = GameConstants.gridSize;

  AIEnemy? _enemy;
  List<Offset> _staticObstacles = [];
  List<Offset> _movingObstacles = [];
  Offset? _portal;
  bool _waitingForPortal = false;
  Offset? _lastTailPos;
  
  // Notifier for screen shake
  final ValueNotifier<bool> shakeNotifier = ValueNotifier<bool>(false);

  int _maxCombo = 0;
  DateTime? _lastFoodTime;

  // Fusion Mode & Currency
  double _fusionGauge = 0.0;
  bool _isFusionMode = false;
  int _fusionCoins = 0;
  
  DateTime? _sessionStartTime;
  Duration get totalDuration => _sessionStartTime == null 
      ? Duration.zero 
      : DateTime.now().difference(_sessionStartTime!);

  double get fusionGauge => _fusionGauge;
  bool get isFusionMode => _isFusionMode;
  int get fusionCoins => _fusionCoins;

  GameStateModel get gameState => _gameState;
  ParticleSystem get particleSystem => _particleSystem;
  bool get isPlaying => _gameState.state == GameState.playing;

  // Smoothness / Interpolation
  DateTime _lastMoveTime = DateTime.now();
  int _currentMoveInterval = GameConstants.baseSpeed;
  
  double get moveProgress {
    if (!isPlaying) return 0.0;
    final now = DateTime.now();
    final elapsed = now.difference(_lastMoveTime).inMilliseconds;
    return (elapsed / _currentMoveInterval).clamp(0.0, 1.0);
  }

  List<Offset> get enemySnake => _enemy?.body ?? <Offset>[];
  List<Offset> get staticObstacles => List.unmodifiable(_staticObstacles);
  List<Offset> get movingObstacles => List.unmodifiable(_movingObstacles);
  Offset? get portal => _portal;
  bool get waitingForPortal => _waitingForPortal;
  Offset? get lastTailPos => _lastTailPos;
  
  bool get reverseControls => _gameState.reverseControls; 

  // --- NEW: Input controller attached by GameScreen
  UltimateInputController? _inputController;

  void attachInputController(UltimateInputController controller) {
    _inputController = controller;
    // sync lastApplied so controller validation works
    _inputController!.lastApplied = _gameState.direction;
  }

  void updateDimensions(Size screenSize) {
    final double cellWidth = screenSize.width / GameConstants.gridSize;
    this.verticalGridSize = (screenSize.height / cellWidth).floor();
    
    if (this.verticalGridSize < GameConstants.gridSize) {
      this.verticalGridSize = GameConstants.gridSize;
    }
  }

  void initGame() {
    _gameState = GameStateModel.initial();
    _particleSystem.clear();
    _lastFoodTime = null;
    _maxCombo = 0;
    _enemy = null;
    _staticObstacles = [];
    _movingObstacles = [];
    _portal = null;
    _waitingForPortal = false;
    _fusionGauge = 0.0;
    _isFusionMode = false;
    _fusionCoins = 0;

    _spawnFood();
    _spawnEnemyAtSafe();
    _generateObstacles();
    
    _updateSnakeColor();

    _gameState = _gameState.copyWith(
      staticObstacles: List.unmodifiable(_staticObstacles),
      movingObstacles: List.unmodifiable(_movingObstacles),
      enemySnake: List.unmodifiable(enemySnake),
      portal: _portal,
      waitingForPortal: _waitingForPortal,
    );

    notifyListeners();
  }
  
  Color _snakeColor = AppColors.snakeHead;
  Color get snakeColor => _snakeColor;

  void _updateSnakeColor() {
    final skinId = SettingsService.equippedSkinId;
    switch (skinId) {
      case 'plasma_pink':
        _snakeColor = Colors.pinkAccent;
        break;
      case 'cyber_lime':
        _snakeColor = Colors.limeAccent;
        break;
      case 'golden_glitch':
        _snakeColor = Colors.amber;
        break;
      case 'neon_cyan':
      default:
        _snakeColor = AppColors.snakeHead;
        break;
    }
  }

  void startGame() {
    if (_gameState.state == GameState.playing) return;
    if (_sessionStartTime == null) _sessionStartTime = DateTime.now();
    _gameState = _gameState.copyWith(state: GameState.playing);
    _startGameLoop();
    notifyListeners();
  }

  void togglePause() {
    if (_gameState.state == GameState.playing) {
      _gameTimer?.cancel();
      _gameState = _gameState.copyWith(state: GameState.paused);
    } else if (_gameState.state == GameState.paused) {
      _gameState = _gameState.copyWith(state: GameState.playing);
      _startGameLoop();
    }
    notifyListeners();
  }

  int _calculateGameSpeed() {
    int base;
    switch (SettingsService.difficulty) {
      case Difficulty.easy:
        base = (GameConstants.baseSpeed * 1.2).toInt(); // 20% slower
        break;
      case Difficulty.hard:
        base = (GameConstants.baseSpeed * 0.8).toInt(); // 20% faster
        break;
      case Difficulty.normal:
      default:
        base = GameConstants.baseSpeed;
        break;
    }

    base = base - (_gameState.level - 1) * GameConstants.speedIncrement;
    
    if (_gameState.activePowerUps.containsKey(PowerUpType.speedBoost)) {
      base = (base * GameConstants.speedBoostMultiplier).toInt();
    }
    if (_gameState.activePowerUps.containsKey(PowerUpType.slowMotion)) {
      base = (base * GameConstants.slowMotionMultiplier).toInt();
    }
    
    if (_isFusionMode) {
      base = (base * 0.6).toInt(); // Super fast in Fusion Mode
    }
    
    return base.clamp(GameConstants.minSpeed, GameConstants.maxSpeed);
  }

  void _startGameLoop() {
    _gameTimer?.cancel();
    _currentMoveInterval = _calculateGameSpeed();
    _lastMoveTime = DateTime.now();
    
    _gameTimer = Timer.periodic(Duration(milliseconds: _currentMoveInterval), (timer) {
      if (_gameState.state != GameState.playing) {
        timer.cancel();
        return;
      }

      _lastMoveTime = DateTime.now();

      // Direction is now applied immediately on input (no tick polling needed)
      _updateDirection();
      _moveSnake();
      _moveEnemy();
      _moveObstacles();
      _updatePowerUpTimers();
      _particleSystem.update();

      if (_lastFoodTime != null && 
        DateTime.now().difference(_lastFoodTime!).inSeconds > 3) {

        // Reset the combo if it's been too long
        _gameState = _gameState.copyWith(combo: 0);
        _lastFoodTime = null; // Stop checking
      }

      if (_random.nextDouble() < 0.01) _spawnPowerUp();

      _gameState = _gameState.copyWith(
        staticObstacles: List.unmodifiable(_staticObstacles),
        movingObstacles: List.unmodifiable(_movingObstacles),
        enemySnake: List.unmodifiable(enemySnake),
        portal: _portal,
        waitingForPortal: _waitingForPortal,
        reverseControls: _gameState.reverseControls, 
      );

      notifyListeners();
    });
  }

  // Called by GameController tick when controller popped a direction
  void applyQueuedDirection(Direction direction) {
    if (_gameState.state != GameState.playing) return;
    
    // Apply reverse controls if active
    final actualDirection = _gameState.reverseControls ? _reverseDir(direction) : direction;
    
    // Update game state direction
    // Additional safety: prevent direct reverse if somehow invoked incorrectly
    if (_isOppositeDirection(actualDirection, _gameState.direction)) {
      // ignore reverse - keep current direction
      return;
    }

    _gameState = _gameState.copyWith(direction: actualDirection);
  }

  void _updateDirection() {
    // Direction updates now handled by UltimateInputController integration
    // Kept for compatibility
  }

  bool _isOppositeDirection(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }

  Direction _reverseDir(Direction d) {
    switch (d) {
      case Direction.up: return Direction.down;
      case Direction.down: return Direction.up;
      case Direction.left: return Direction.right;
      case Direction.right: return Direction.left;
    }
  }

  void _moveSnake() {
    final head = _gameState.snake.first;
    Offset newHead = _getNextPosition(head, _gameState.direction);

    if (_gameState.reverseControls) {
      newHead = _getNextPosition(head, _reverseDir(_gameState.direction));
    }

    newHead = _wrapPosition(newHead);

    if (_waitingForPortal && _portal != null && newHead == _portal) {
      _portal = null;
      _waitingForPortal = false;
      _gameState = _gameState.copyWith(portal: null, waitingForPortal: false);
      SoundManager.playPortalEnter();
      HapticFeedback.mediumImpact();
      _advanceLevel();
      return;
    }

    if (_gameState.hasGhost) {
      if (_enemy != null && _collision.check(newHead, _enemy!.body)) {
        _endGame();
        return;
      }
    } else {
      if (_collision.check(newHead, _staticObstacles)) {
        if (_gameState.hasShield) {
          _deactivateShield();
          _particleSystem.createCollisionParticles(newHead, Colors.orange);
          SoundManager.playShieldHit();
          HapticFeedback.mediumImpact();
          _triggerShake();
          return;
        } else if (_isFusionMode) {
           // Smash through obstacles in Fusion Mode
           _particleSystem.createCollisionParticles(newHead, AppColors.accent);
           SoundManager.playShieldHit(); 
           HapticFeedback.heavyImpact();
           _triggerShake();
           return;
        } else {
          _endGame();
          return;
        }
      }
      
      if (_collision.check(newHead, _movingObstacles)) {
        if (_gameState.hasShield) {
          _deactivateShield();
          _particleSystem.createCollisionParticles(newHead, AppColors.warning);
          SoundManager.playShieldHit();
          HapticFeedback.mediumImpact();
          _triggerShake();
          _movingObstacles.remove(newHead);
          return;
        } else if (_isFusionMode) {
           // Smash moving obstacles
           _particleSystem.createCollisionParticles(newHead, AppColors.accent);
           SoundManager.playShieldHit();
           HapticFeedback.heavyImpact();
           _triggerShake();
           _movingObstacles.remove(newHead);
           return;
        } else {
          _endGame();
          return;
        }
      }

      // Check if newHead collides with current snake body (skip head which is index 0)
      if (_collision.check(newHead, _gameState.snake)) {
        _endGame();
        return;
      }

      if (_enemy != null && _collision.check(newHead, _enemy!.body)) {
        _endGame();
        return;
      }
    }

    final newSnake = List<Offset>.from(_gameState.snake)..insert(0, newHead);

    if (newHead == _gameState.food) {
      _onFoodCollected();
      _lastTailPos = null; // Grown, so tail didn't move (technically)
    } else {
      _lastTailPos = newSnake.last;
      newSnake.removeLast();
      if (_random.nextDouble() < 0.25) {
        _particleSystem.createTrailParticle(
          newSnake.last,
          _gameState.hasShield ? Colors.blue : Colors.cyan,
        );
      }
    }

    final remaining = <PowerUp>[];
    for (final p in _gameState.powerUps) {
      if (p.position == newHead) {
        _activatePowerUp(p);
        _particleSystem.createPowerUpParticles(p.position, p.color);
        SoundManager.playPowerUp();
        HapticFeedback.lightImpact();
      } else if (!p.isExpired) {
        remaining.add(p);
      }
    }

    _gameState = _gameState.copyWith(snake: newSnake, powerUps: remaining);
  }

  Offset _getNextPosition(Offset current, Direction direction) {
    switch (direction) {
      case Direction.up: return Offset(current.dx, current.dy - 1);
      case Direction.down: return Offset(current.dx, current.dy + 1);
      case Direction.left: return Offset(current.dx - 1, current.dy);
      case Direction.right: return Offset(current.dx + 1, current.dy);
    }
  }

  Offset _wrapPosition(Offset p) {
    final x = (p.dx + GameConstants.gridSize) % GameConstants.gridSize;
    final y = (p.dy + verticalGridSize) % verticalGridSize;
    return Offset(x.toDouble(), y.toDouble());
  }

  void _onFoodCollected() {
    int points = _gameState.isGoldenFood ? 100 : GameConstants.foodPoints;
    if (_gameState.combo > 0) points += _gameState.combo * 2;

    final prevScore = _gameState.score;
    final newScore = prevScore + points;

    _gameState = _gameState.copyWith(
      score: newScore,
      combo: _gameState.combo + 1,
      lastFoodTime: DateTime.now(),
    );

    _lastFoodTime = DateTime.now();
    if (_gameState.combo > _maxCombo) _maxCombo = _gameState.combo;

    _particleSystem.createFoodParticles(_gameState.food);
    SoundManager.playEat();
    HapticFeedback.selectionClick();

    // Fusion Gauge Logic
    if (!_isFusionMode) {
      _fusionGauge += 0.1; // 10 food to fill
      if (_fusionGauge >= 1.0) {
        _activateFusionMode();
      }
    }
    
    // Currency Logic
    _fusionCoins += 1; // 1 coin per food
    if (_gameState.isGoldenFood) _fusionCoins += 5;

    // Check for level up by score
    final prevThreshold = prevScore ~/ GameConstants.levelUpThreshold;
    final newThreshold = newScore ~/ GameConstants.levelUpThreshold;
 
    // --- OR ---
    // Check for a 12-point combo
    final bool comboReached = _gameState.combo >= 12;

    if (newThreshold > prevThreshold || comboReached) {
      _spawnPortal();
      return;
   }

    _spawnFood();

    if (_random.nextDouble() < GameConstants.powerUpSpawnChance) {
      _spawnPowerUp();
    }
  }

  Offset? _findSafeSpawnPosition() {
    final reserved = <Offset>{
      ..._gameState.snake,
      ..._staticObstacles,
      ..._movingObstacles,
      ...(_enemy?.body ?? []),
    };
    if (_gameState.food != null) reserved.add(_gameState.food);
    if (_portal != null) reserved.add(_portal!);
    
    for (int i = 0; i < 500; i++) {
      final pos = Offset(
        _random.nextInt(GameConstants.gridSize).toDouble(),
        _random.nextInt(verticalGridSize).toDouble(),
      );
      
      if (!reserved.contains(pos)) {
        return pos;
      }
    }
    return null;
  }

  void _spawnPortal() {
    final pos = _findSafeSpawnPosition();
    if (pos != null) {
      _portal = pos;
      _waitingForPortal = true;
      _gameState = _gameState.copyWith(portal: pos, waitingForPortal: true);
      SoundManager.playPortalAppear();
      HapticFeedback.mediumImpact();
      notifyListeners();
    }
  }

  void _advanceLevel() {
    final nextLevel = _gameState.level + 1;
    
    if (nextLevel > GameConstants.maxLevel) {
      _gameTimer?.cancel();
      _gameState = _gameState.copyWith(state: GameState.completed);
      notifyListeners();
      return;
    }

    _portal = null;
    _waitingForPortal = false;

    final head = _gameState.snake.first;
    final newSnake = [
      head,
      _wrapPosition(head + const Offset(-1, 0)),
      _wrapPosition(head + const Offset(-2, 0)),
    ];

    _gameState = _gameState.copyWith(
      level: nextLevel,
      waitingForPortal: false,
      portal: null,
      staticObstacles: [],
      movingObstacles: [],
      snake: newSnake,
    );
    _maxCombo = 0;

    _spawnFood();
    _spawnEnemyAtSafe();
    _generateObstacles();
    
    SoundManager.playLevelUp();
    HapticFeedback.heavyImpact();
    notifyListeners();

    if (_isDevilLevel(nextLevel)) {
      _startDevilLevel();
    }

    _startGameLoop();
  }

  void _spawnFood() {
    final pos = _findSafeSpawnPosition();
    // 1 in 15 chance of being golden
    bool isGolden = _random.nextInt(15) == 0; 

    _gameState = _gameState.copyWith(
      food: pos ?? const Offset(0, 0),
      isGoldenFood: isGolden,
    );
  }

  void _spawnPowerUp() {
    final pos = _findSafeSpawnPosition();
    if (pos != null) {
      const List<PowerUpType> allowedPowerUps = [
        PowerUpType.shield,
        PowerUpType.ghost,
        PowerUpType.speedBoost,
        PowerUpType.slowMotion,
      ];
      
      final type = allowedPowerUps[_random.nextInt(allowedPowerUps.length)];
      
      final pu = PowerUp(position: pos, type: type, duration: _getDurationForPowerUp(type));
      final newList = List<PowerUp>.from(_gameState.powerUps)..add(pu);
      _gameState = _gameState.copyWith(powerUps: newList);
    }
  }

  int _getDurationForPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return GameConstants.speedBoostDuration;
      case PowerUpType.shield:
        return GameConstants.shieldDuration;
      case PowerUpType.slowMotion:
        return GameConstants.slowMotionDuration;
      case PowerUpType.ghost:
        return GameConstants.ghostDuration;
      default:
        // Fallback for any other types we might add
        return 100;
    }
  }

  void _generateObstacles() {
    final reserved = <Offset>[
      ..._gameState.snake,
      _gameState.food,
      ...(_enemy?.body ?? [])
    ];

    final layout = _levelGenerator.generateLevel(
      _gameState.level,
      hGrid: GameConstants.gridSize,
      vGrid: verticalGridSize,
      reserved: reserved,
    );

    _staticObstacles = layout.staticObstacles;
    _movingObstacles = layout.movingObstacles;
    
    _gameState = _gameState.copyWith(
        staticObstacles: List.unmodifiable(_staticObstacles),
        movingObstacles: List.unmodifiable(_movingObstacles));
  }
  
  void _moveObstacles() {
    if (_movingObstacles.isEmpty) return;
    
    final direction = _gameState.level % 2 == 0 ? 1.0 : -1.0;

    final moved = <Offset>[];
    for (final obs in _movingObstacles) {
      Offset next = obs + Offset(direction, 0);
      next = _wrapPosition(next);
      moved.add(next);
    }
    _movingObstacles = moved;
  }

  void _spawnEnemyAtSafe() {
    final pos = _findSafeSpawnPosition();
    _enemy = AIEnemy(head: pos ?? const Offset(0, 0));
    _gameState = _gameState.copyWith(enemySnake: List.unmodifiable(_enemy!.body));
  }

  void _moveEnemy() {
    if (_enemy == null) return;

    double moveChance;
    switch (SettingsService.difficulty) {
      case Difficulty.easy:
        moveChance = 0.4;
        break;
      case Difficulty.hard:
        moveChance = 0.8;
        break;
      case Difficulty.normal:
      default:
        moveChance = 0.6;
        break;
    }
    moveChance = (moveChance + (_gameState.level * 0.02)).clamp(0.4, 0.95);

    if (_random.nextDouble() > moveChance) return;

    final from = _enemy!.head;
    final target = _gameState.snake.first;
    final allObstacles = [..._staticObstacles, ..._movingObstacles];

    final nextRaw = _aiController.getNextMove(
      from: from,
      target: target,
      obstacles: allObstacles,
      enemyBody: _enemy!.body,
      verticalGridSize: verticalGridSize,
      horizontalGridSize: GameConstants.gridSize,
    );

    final next = _wrapPosition(nextRaw);

    if (next == _gameState.snake.first) {
      _endGame();
      return;
    }

    if (_collision.check(next, allObstacles) || _collision.check(next, _enemy!.body)) {
      final options = [
        _wrapPosition(Offset(from.dx + 1, from.dy)),
        _wrapPosition(Offset(from.dx - 1, from.dy)),
        _wrapPosition(Offset(from.dx, from.dy + 1)),
        _wrapPosition(Offset(from.dx, from.dy - 1)),
      ];
      final alt = options.firstWhere(
          (o) => !_collision.check(o, allObstacles) && !_collision.check(o, _enemy!.body),
          orElse: () => from);
      _enemy!.moveTo(alt);
    } else {
      _enemy!.moveTo(next);
    }

    if (_random.nextDouble() < 0.08) {
      final fut = _aiController.getNextMove(
        from: _enemy!.head, 
        target: target, 
        obstacles: allObstacles, 
        enemyBody: _enemy!.body, 
        verticalGridSize: verticalGridSize,
        horizontalGridSize: GameConstants.gridSize,
      );
      _enemy!.moveTo(_wrapPosition(fut));
    }

    _gameState = _gameState.copyWith(enemySnake: List.unmodifiable(_enemy!.body));

    final dist = _distance(_enemy!.head, _gameState.snake.first);
    if (dist < 4 && _random.nextDouble() < 0.2) {
      SoundManager.playEnemyNear();
      HapticFeedback.lightImpact();
    }
  }

  bool _isDevilLevel(int level) => level % GameConstants.devilLevelFrequency == 0;

  void _activatePowerUp(PowerUp pu) {
    final active = Map<PowerUpType, int>.from(_gameState.activePowerUps);
    active[pu.type] = pu.duration;

    var shield = _gameState.hasShield;
    var ghost = _gameState.hasGhost;

    if (pu.type == PowerUpType.shield) shield = true;
    if (pu.type == PowerUpType.ghost) ghost = true;

    _gameState = _gameState.copyWith(
        activePowerUps: active, hasShield: shield, hasGhost: ghost);

    if (pu.type == PowerUpType.slowMotion ||
        pu.type == PowerUpType.speedBoost) {
      _startGameLoop();
    }
  }

  void _updatePowerUpTimers() {
    final active = Map<PowerUpType, int>.from(_gameState.activePowerUps);
    final remove = <PowerUpType>[];
    var needsSpeedUpdate = false;
    var shield = _gameState.hasShield;
    var ghost = _gameState.hasGhost;

    active.forEach((type, timer) {
      if (timer <= 1) {
        remove.add(type);
        if (type == PowerUpType.speedBoost || type == PowerUpType.slowMotion) {
          needsSpeedUpdate = true;
        }
        if (type == PowerUpType.shield) shield = false;
        if (type == PowerUpType.ghost) ghost = false;
      } else {
        active[type] = timer - 1;
      }
    });

    for (final t in remove) active.remove(t);

    _gameState = _gameState.copyWith(
        activePowerUps: active, hasShield: shield, hasGhost: ghost);

    if (needsSpeedUpdate) _startGameLoop();
  }

  void _deactivateShield() {
    final active = Map<PowerUpType, int>.from(_gameState.activePowerUps);
    active.remove(PowerUpType.shield);
    _gameState = _gameState.copyWith(hasShield: false, activePowerUps: active);
  }

  Future<void> _endGame() async {
    print('[DEBUG] Game Over triggered!');
    print('[DEBUG] Snake head: ${_gameState.snake.first}');
    print('[DEBUG] Snake body: ${_gameState.snake.skip(1).toList()}');
    print('[DEBUG] Static obstacles count: ${_staticObstacles.length}');
    print('[DEBUG] Moving obstacles count: ${_movingObstacles.length}');
    print('[DEBUG] Enemy snake: ${_enemy?.body}');
    print('[DEBUG] Has Shield: ${_gameState.hasShield}');
    print('[DEBUG] Has Ghost: ${_gameState.hasGhost}');

    _gameTimer?.cancel();
    _particleSystem.createCollisionParticles(_gameState.snake.first, Colors.red);
    SoundManager.playGameOver();
    HapticFeedback.heavyImpact();
    _triggerShake();

    await StorageManager.incrementTotalGames();
    await StorageManager.addToTotalScore(_gameState.score);

    final newEntry = LeaderboardEntry(
      score: _gameState.score, 
      level: _gameState.level, 
      maxCombo: _maxCombo,
      date: DateTime.now(),
    );
    await StorageManager.addLeaderboardEntry(newEntry);

    final newHighScore = await StorageManager.getHighScore();
    final bool isNewRecord = (_gameState.score == newHighScore && _gameState.score > 0); 

    _gameState = _gameState.copyWith(
      state: GameState.gameOver,
      isNewHighScore: isNewRecord,
    );
    notifyListeners();
  }

  void _startDevilLevel() {
    SoundManager.playDevilGuffaw();

    _gameState = _gameState.copyWith(reverseControls: true);
    Timer(const Duration(seconds: GameConstants.devilLevelReverseDuration), () {
      _gameState = _gameState.copyWith(reverseControls: false);
      notifyListeners();
    });
  }

  double _distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return sqrt(dx * dx + dy * dy);
  }

  void _triggerShake() {
    shakeNotifier.value = !shakeNotifier.value; // Toggle to trigger listener
  }


  void _activateFusionMode() {
    _fusionGauge = 1.0;
    _isFusionMode = true;
    _startGameLoop(); // Update speed
    notifyListeners();
    
    // Lasts 5 seconds
    Timer(const Duration(seconds: 5), _deactivateFusionMode);
  }

  void _deactivateFusionMode() {
    if (!_isFusionMode) return;
    _isFusionMode = false;
    _fusionGauge = 0.0;
    _startGameLoop(); // Reset speed
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    shakeNotifier.dispose();
    super.dispose();
  }
}
