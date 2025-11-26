// lib/controllers/gesture_controller.dart
import 'package:flutter/material.dart';
import '../core/enums/game_enums.dart';

class GestureController {
  Offset? _last;
  Direction? lastDirection;

  // ultra sensitive: 1 pixel
  final double threshold;

  GestureController({this.threshold = 1.0});

  void onPointerDown(PointerDownEvent e) {
    _last = e.localPosition;
  }

  Direction? onPointerMove(PointerMoveEvent e) {
    if (_last == null) return null;

    final dx = e.localPosition.dx - _last!.dx;
    final dy = e.localPosition.dy - _last!.dy;

    // Not enough movement
    if (dx.abs() < threshold && dy.abs() < threshold) {
      return null;
    }

    Direction dir;

    // Determine dominant axis
    if (dx.abs() > dy.abs()) {
      dir = dx > 0 ? Direction.right : Direction.left;
    } else {
      dir = dy > 0 ? Direction.down : Direction.up;
    }

    // Store this direction as last detected
    lastDirection = dir;

    // Update last point only after deciding
    _last = e.localPosition;

    return dir;
  }

  void onPointerUp(PointerUpEvent e) {
    _last = null;
  }

  void onPointerCancel(PointerCancelEvent e) {
    _last = null;
  }
}
