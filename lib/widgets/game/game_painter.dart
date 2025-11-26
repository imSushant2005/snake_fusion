// lib/widgets/game/game_painter.dart
import 'dart:math';
import 'dart:ui' as ui; // For Path, Gradient, PathMetric, etc.
import 'package:flutter/material.dart';
import '../../core/constants/game_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/power_up.dart';
import '../../models/particle.dart';
import '../../core/enums/game_enums.dart';

class GamePainter extends CustomPainter {
  final int level;
  final int gridSize;
  final int verticalGridSize;
  final List<Offset> snake;

  final Offset food;
  final bool isGoldenFood;
  final List<PowerUp> powerUps;
  final List<Particle> particles;
  final List<Offset> staticObstacles;
  final List<Offset> movingObstacles;
  final Offset? portal;
  final List<Offset> enemySnake;
  final bool hasShield;
  final bool hasGhost;
  final Color snakeColor;

  final double animationValue;
  final double moveProgress;
  final Offset? lastTailPos;

  GamePainter({
    required this.level,
    required this.snake,
    required this.food,
    required this.isGoldenFood,
    required this.powerUps,
    required this.particles,
    required this.staticObstacles,
    required this.movingObstacles,
    required this.enemySnake,
    required this.portal,
    required this.hasShield,
    required this.hasGhost,
    required this.verticalGridSize,
    required this.snakeColor,
    this.gridSize = GameConstants.gridSize,
    this.animationValue = 0.0,
    this.moveProgress = 1.0,
    this.lastTailPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final theme = _getLevelTheme(level);
    final cell = size.width / gridSize;
    final gameHeight = cell * verticalGridSize;
    final offsetY = max(0.0, (size.height - gameHeight) / 2.0);
    final paint = Paint()..isAntiAlias = true;

    // Background
    _drawBackground(canvas, size, theme, cell);

    // Translate to center the game vertically and clip to game area
    canvas.save();
    canvas.translate(0, offsetY);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, gameHeight));

    // Draw Food
    final foodCenter = Offset(food.dx * cell + cell * 0.5, food.dy * cell + cell * 0.5);
    paint
      ..style = PaintingStyle.fill
      ..color = isGoldenFood ? AppColors.doubleScore : AppColors.food;
    canvas.drawCircle(foodCenter, cell * 0.4, paint);

    // Draw Static Obstacles
    paint.color = theme.staticObstacle;
    for (var o in staticObstacles) {
      canvas.drawRect(Rect.fromLTWH(o.dx * cell, o.dy * cell, cell, cell), paint);
    }

    // Draw Moving Obstacles
    paint.color = theme.movingObstacle;
    for (var o in movingObstacles) {
      canvas.drawRect(Rect.fromLTWH(o.dx * cell, o.dy * cell, cell, cell), paint);
    }

    // Draw Power-Ups (pulsing)
    for (var powerUp in powerUps) {
      final powerUpCenter = Offset(
        powerUp.position.dx * cell + cell * 0.5,
        powerUp.position.dy * cell + cell * 0.5,
      );
      switch (powerUp.type) {
        case PowerUpType.shield:
          paint.color = AppColors.shield;
          break;
        case PowerUpType.speedBoost:
          paint.color = AppColors.speedBoost;
          break;
        case PowerUpType.slowMotion:
          paint.color = AppColors.slowMotion;
          break;
        case PowerUpType.ghost:
          paint.color = Colors.white.withOpacity(0.85);
          break;
        default:
          paint.color = AppColors.warning;
      }

      final radius = cell * (0.35 + sin(animationValue * 3) * 0.05);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(powerUpCenter, radius, paint);

      paint
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 2.0;
      canvas.drawCircle(powerUpCenter, radius, paint);
    }

    // Draw Portal
    if (portal != null) {
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.purple;
      final c = Offset(portal!.dx * cell + cell * 0.5, portal!.dy * cell + cell * 0.5);
      canvas.drawCircle(c, cell * (0.45 + sin(animationValue * 2) * 0.05), paint);
    }

    // Draw Enemy Snake (simple blocks)
    paint.style = PaintingStyle.fill;
    paint.color = Colors.red;
    for (var e in enemySnake) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            e.dx * cell + GameConstants.snakeOffset * cell,
            e.dy * cell + GameConstants.snakeOffset * cell,
            cell * (1 - 2 * GameConstants.snakeOffset),
            cell * (1 - 2 * GameConstants.snakeOffset),
          ),
          Radius.circular(max(2.0, cell * 0.12)),
        ),
        paint,
      );
    }

    // Draw Player Snake
    _drawSnake(canvas, paint, cell, theme);

    // Draw Particles
    for (var p in particles) {
      paint
        ..style = PaintingStyle.fill
        ..color = p.color.withOpacity(p.opacity);
      canvas.drawCircle(
        Offset(p.position.dx * cell + cell * 0.5, p.position.dy * cell + cell * 0.5),
        p.size,
        paint,
      );
    }

    canvas.restore();
  }

  void _drawSnake(Canvas canvas, Paint paint, double cell, _LevelTheme theme) {
    if (snake.isEmpty) return;

    final double opacity = hasGhost ? 0.45 : 1.0;

    // Convert grid coords to pixel centers with interpolation
    final pixelPoints = <Offset>[];
    
    for (int i = 0; i < snake.length; i++) {
      final current = snake[i];
      Offset prev;
      
      if (i < snake.length - 1) {
        prev = snake[i + 1];
      } else {
        prev = lastTailPos ?? current;
      }
      
      // Unwrap prev relative to current for smooth wrapping interpolation
      final unwrappedPrev = _unwrap(prev, current);
      
      final interpolated = Offset.lerp(unwrappedPrev, current, moveProgress)!;
      pixelPoints.add(Offset(interpolated.dx * cell + cell * 0.5, interpolated.dy * cell + cell * 0.5));
    }

    // 1. Split into segments when wrap occurs (grid movement >1)
    final segments = <List<Offset>>[];
    var current = <Offset>[];

    for (int i = 0; i < snake.length; i++) {
      final gridPoint = snake[i];
      final p = pixelPoints[i];

      if (i == 0) {
        current.add(p);
        continue;
      }

      final prev = snake[i - 1];
      final dxGrid = (gridPoint.dx - prev.dx).abs();
      final dyGrid = (gridPoint.dy - prev.dy).abs();

      // If the grid gap is >1 it's a wrap; start new segment
      if (dxGrid > 1 || dyGrid > 1) {
        if (current.isNotEmpty) segments.add(List<Offset>.from(current));
        current = [p];
      } else {
        current.add(p);
      }
    }
    if (current.isNotEmpty) segments.add(current);

    // 2. Draw segments as volumetric bodies
    for (final seg in segments) {
      if (seg.length < 2) continue;
      _drawSnakeSegment(canvas, paint, cell, theme, seg, opacity, animationValue);
    }

    // 3. Draw head (use full points list for direction if possible)
    if (pixelPoints.isNotEmpty) {
      _drawSnakeHead(canvas, paint, cell, pixelPoints, opacity, animationValue);
    }

    // 4. Draw shield around head when active
    if (hasShield && pixelPoints.isNotEmpty) {
      final headPos = pixelPoints.first;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.16
        ..color = AppColors.shield.withOpacity(0.45 + sin(animationValue * 3) * 0.15);
      canvas.drawCircle(headPos, cell * 0.65, paint);
    }
  }

  void _drawSnakeSegment(
    Canvas canvas,
    Paint paint,
    double cell,
    _LevelTheme theme,
    List<Offset> points,
    double opacity,
    double animationValue,
  ) {
    if (points.length < 2) return;
    if (points.any((p) => p.dx.isNaN || p.dy.isNaN || p.dx.isInfinite || p.dy.isInfinite)) {
      return;
    }

    // Build a simple Catmull-Rom-like smooth set of points
    final smooth = <Offset>[];

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // step smaller for smoother curve
      for (double t = 0.0; t < 1.0; t += 0.2) {
        final t2 = t * t;
        final t3 = t2 * t;
        final x = 0.5 *
            ((2 * p1.dx) +
                (-p0.dx + p2.dx) * t +
                (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);
        final y = 0.5 *
            ((2 * p1.dy) +
                (-p0.dy + p2.dy) * t +
                (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);
        final candidate = Offset(x, y);
        if (!candidate.dx.isNaN && !candidate.dy.isNaN) smooth.add(candidate);
      }
    }
    // add last point explicitly
    smooth.add(points.last);

    if (smooth.length < 2) return;

    // Build body path (left edge then right edge)
    final body = ui.Path();

    final maxWidth = cell * 0.9;
    final minWidth = cell * 0.25;

    // Precompute normals and left/right points
    final lefts = <Offset>[];
    final rights = <Offset>[];

    for (int i = 0; i < smooth.length; i++) {
      final cur = smooth[i];
      final nxt = i < smooth.length - 1 ? smooth[i + 1] : smooth[i];
      final angle = atan2(nxt.dy - cur.dy, nxt.dx - cur.dx);
      final normal = Offset(-sin(angle), cos(angle));

      final t = smooth.length <= 1 ? 0.0 : (i / (smooth.length - 1));
      final width = (maxWidth * (1 - t) + minWidth * t);

      // Ripple: smaller and clamped so we never invert geometry
      final rawRipple = sin(animationValue * 6 + i * 0.25) * (cell * 0.04);
      // clamp ripple to 70% of half-width so left/right don't cross
      final maxRipple = width * 0.5 * 0.7;
      final ripple = rawRipple.clamp(-maxRipple, maxRipple);

      final left = cur + normal * (width * 0.5 + ripple);
      final right = cur - normal * (width * 0.5 - ripple);

      lefts.add(left);
      rights.add(right);
    }

    // left edge
    for (int i = 0; i < lefts.length; i++) {
      if (i == 0) {
        body.moveTo(lefts[i].dx, lefts[i].dy);
      } else {
        body.lineTo(lefts[i].dx, lefts[i].dy);
      }
    }

    // right edge (reverse)
    for (int i = rights.length - 1; i >= 0; i--) {
      body.lineTo(rights[i].dx, rights[i].dy);
    }
    body.close();

    // Guard: empty bounds -> fallback
    final bounds = body.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      paint
        ..style = PaintingStyle.fill
        ..color = AppColors.snakeBody.withOpacity(opacity);
      for (final p in points) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: cell * 0.8, height: cell * 0.8),
            Radius.circular(cell * 0.2),
          ),
          paint,
        );
      }
      return;
    }

    // Gradient shading for body (3 colors with stops)
    paint.shader = ui.Gradient.linear(
      bounds.topLeft,
      bounds.bottomRight,
      [
        AppColors.snakeBody.withOpacity(opacity),
        snakeColor.withOpacity(opacity),
        AppColors.snakeBody.withOpacity(max(0.0, opacity * 0.7)),
      ],
      [0.0, 0.5, 1.0],
    );
    paint.style = PaintingStyle.fill;
    canvas.drawPath(body, paint);
    paint.shader = null;

    // Specular radial highlight
    final highlight = Paint()
      ..shader = ui.Gradient.radial(
        bounds.center,
        bounds.shortestSide * 0.6,
        [
          Colors.white.withOpacity(0.14 * opacity),
          Colors.transparent,
        ],
      )
      ..blendMode = BlendMode.lighten;
    canvas.drawPath(body, highlight);

    // Procedural scale pattern (subtle)
    final scalesPaint = Paint()..color = Colors.black.withOpacity(0.12 * opacity);

    for (final metric in body.computeMetrics()) {
      // step over the path; make sure we don't do too many points
      final step = max(6.0, metric.length / 30.0);
      for (double d = 0; d < metric.length; d += step) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final normalLen = normal.distance;
        if (normalLen == 0) continue;
        final n = normal / normalLen;

        // draw a short row of dots across the body
        for (double off = -cell * 0.6; off <= cell * 0.6; off += cell * 0.35) {
          final p = tangent.position + n * off;
          // quick bounds check
          if (p.dx.isFinite && p.dy.isFinite && bounds.contains(p)) {
            canvas.drawCircle(p, cell * 0.10, scalesPaint);
          }
        }
      }
    }
  }

  void _drawSnakeHead(
    Canvas canvas,
    Paint paint,
    double cell,
    List<Offset> points,
    double opacity,
    double animationValue,
  ) {
    if (points.isEmpty) return;

    final headPos = points.first;
    Offset neck = points.length > 1 ? points[1] : headPos;

    // Fix for wrap jump: if the pixel gap is large, assume wrap and set neck near head
    if ((headPos.dx - neck.dx).abs() > cell * 1.5) {
      neck = headPos + Offset((headPos.dx > neck.dx ? 1 : -1) * cell, 0);
    }
    if ((headPos.dy - neck.dy).abs() > cell * 1.5) {
      neck = headPos + Offset(0, (headPos.dy > neck.dy ? 1 : -1) * cell);
    }

    final angle = atan2(headPos.dy - neck.dy, headPos.dx - neck.dx);

    canvas.save();
    canvas.translate(headPos.dx, headPos.dy);
    canvas.rotate(angle);

    // Head shape (symmetric, stylized)
    final head = ui.Path()
      ..moveTo(cell * 0.8, 0)
      ..quadraticBezierTo(-cell * 0.28, -cell * 0.56, -cell * 0.68, 0)
      ..quadraticBezierTo(-cell * 0.28, cell * 0.56, cell * 0.8, 0)
      ..close();

    // Head shader (3 colors with stops)
    paint.shader = ui.Gradient.radial(
      Offset(0, 0),
      cell * 1.1,
      [
        snakeColor.withOpacity(opacity),
        AppColors.snakeBody.withOpacity(opacity),
        AppColors.snakeBody.withOpacity(max(0.0, opacity * 0.7)),
      ],
      [0.0, 0.4, 1.0],
    );
    paint.style = PaintingStyle.fill;
    canvas.drawPath(head, paint);
    paint.shader = null;

    // Eyes with blinking (driven by animationValue)
    final blink = sin(animationValue * 4) > 0.95;
    final eyeScale = blink ? 0.25 : 1.0;

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(opacity);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-cell * 0.22, -cell * 0.22), width: cell * 0.20, height: cell * 0.20 * eyeScale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-cell * 0.22, cell * 0.22), width: cell * 0.20, height: cell * 0.20 * eyeScale),
      paint,
    );

    paint.color = Colors.black.withOpacity(opacity);
    canvas.drawCircle(Offset(-cell * 0.18, -cell * 0.22), cell * 0.07, paint);
    canvas.drawCircle(Offset(-cell * 0.18, cell * 0.22), cell * 0.07, paint);

    // Animated forked tongue
    final flick = sin(animationValue * 25) * (cell * 0.16);
    final tonguePaint = Paint()..color = Colors.red.shade700.withOpacity(opacity);
    final tongue = ui.Path()
      ..moveTo(cell * 0.8, 0)
      ..lineTo(cell * 1.05, -cell * 0.08 + flick)
      ..lineTo(cell * 1.18, 0 + flick)
      ..lineTo(cell * 1.05, cell * 0.08 + flick)
      ..close();
    canvas.drawPath(tongue, tonguePaint);

    canvas.restore();
  }

  Offset _pointAlongPath(ui.PathMetric m, double distance, double offset) {
    if (distance < 0) distance = 0;
    if (distance > m.length) distance = m.length;
    final t = m.getTangentForOffset(distance);
    if (t == null) return Offset.zero;
    final normal = Offset(-t.vector.dy, t.vector.dx);
    final d = normal.distance;
    if (d == 0) return t.position;
    final normalizedNormal = normal / d;
    return t.position + normalizedNormal * offset;
  }

  void _drawBackground(Canvas canvas, Size size, _LevelTheme theme, double cell) {
    // Base color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = theme.background,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.05);

    // Biome-specific patterns
    switch (level % 4) {
      case 1: // Grid (Cyber)
        _drawGridBackground(canvas, size, cell, paint);
        break;
      case 2: // Digital Rain (Bio)
        _drawDigitalRain(canvas, size, cell);
        break;
      case 3: // Solar (Plasma)
        _drawSolarBackground(canvas, size, cell);
        break;
      case 0: // Glitch (Void)
        _drawGlitchBackground(canvas, size, cell);
        break;
    }
  }

  void _drawGridBackground(Canvas canvas, Size size, double cell, Paint paint) {
    // Moving grid
    final offset = (animationValue * cell * 2) % cell;
    
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = offset - cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDigitalRain(Canvas canvas, Size size, double cell) {
    final rainPaint = Paint()..color = Colors.green.withOpacity(0.1);
    final random = Random(level); // Consistent random per level
    
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.5 + random.nextDouble();
      final y = ((animationValue * 100 * speed) + random.nextDouble() * size.height) % (size.height + 100) - 100;
      
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 20 + random.nextDouble() * 30), rainPaint);
    }
  }

  void _drawSolarBackground(Canvas canvas, Size size, double cell) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.8;
    
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        Colors.orange.withOpacity(0.1 + sin(animationValue) * 0.05),
        Colors.transparent,
      ],
    );
    
    final p = Paint()..shader = gradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);
  }

  void _drawGlitchBackground(Canvas canvas, Size size, double cell) {
    final random = Random((animationValue * 10).floor()); // Changes 10 times per second
    if (random.nextDouble() > 0.8) return; // Flicker
    
    final paint = Paint()..color = Colors.red.withOpacity(0.05);
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final w = random.nextDouble() * 100;
    final h = random.nextDouble() * 10;
    
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  Offset _unwrap(Offset prev, Offset current) {
    double dx = prev.dx;
    double dy = prev.dy;
    
    if ((prev.dx - current.dx).abs() > 1.5) {
      if (prev.dx > current.dx) dx -= gridSize;
      else dx += gridSize;
    }
    
    if ((prev.dy - current.dy).abs() > 1.5) {
      if (prev.dy > current.dy) dy -= verticalGridSize;
      else dy += verticalGridSize;
    }
    
    return Offset(dx, dy);
  }

  @override
  bool shouldRepaint(covariant GamePainter old) {
    // Conservative compare: if references differ or animation changed, repaint
    return old.level != level ||
        !listEquals(old.snake, snake) ||
        old.food != food ||
        old.isGoldenFood != isGoldenFood ||
        !listEquals(old.powerUps, powerUps) ||
        !listEquals(old.particles, particles) ||
        !listEquals(old.staticObstacles, staticObstacles) ||
        !listEquals(old.movingObstacles, movingObstacles) ||
        !listEquals(old.enemySnake, enemySnake) ||
        old.portal != portal ||
        old.hasShield != hasShield ||
        old.hasGhost != hasGhost ||
        old.verticalGridSize != verticalGridSize ||
        old.animationValue != animationValue ||
        old.moveProgress != moveProgress;
  }
}

// Simple list equality helper (avoids importing collection package)
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Level theme helper
_LevelTheme _getLevelTheme(int level) {
  switch (level % 4) {
    case 1:
      return _LevelTheme(
        background: AppColors.background,
        staticObstacle: Colors.grey.shade700,
        movingObstacle: AppColors.warning,
      );
    case 2:
      return _LevelTheme(
        background: const Color(0xFF0A2712),
        staticObstacle: Colors.brown.shade700,
        movingObstacle: Colors.brown.shade400,
      );
    case 3:
      return _LevelTheme(
        background: const Color(0xFF0A1F27),
        staticObstacle: Colors.blue.shade200,
        movingObstacle: Colors.white,
      );
    case 0:
      return _LevelTheme(
        background: const Color(0xFF270A0A),
        staticObstacle: Colors.grey.shade900,
        movingObstacle: AppColors.error,
      );
    default:
      return _LevelTheme.defaultTheme();
  }
}

class _LevelTheme {
  final Color background;
  final Color staticObstacle;
  final Color movingObstacle;

  _LevelTheme({
    required this.background,
    required this.staticObstacle,
    required this.movingObstacle,
  });

  factory _LevelTheme.defaultTheme() {
    return _LevelTheme(
      background: AppColors.background,
      staticObstacle: Colors.grey,
      movingObstacle: AppColors.warning,
    );
  }
}
