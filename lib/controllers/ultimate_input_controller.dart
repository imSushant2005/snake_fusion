import 'package:flutter/material.dart';
import '../core/enums/game_enums.dart';

class UltimateInputController {
  Offset? _last;
  final double threshold;

  // Direction queue for ultra-fast input
  final List<Direction> _queue = [];
  final int queueLimit;

  Direction lastApplied = Direction.right;

  UltimateInputController({
    this.threshold = 1.0,
    this.queueLimit = 6,
  });

  void onPointerDown(PointerDownEvent e) {
    _last = e.localPosition;
  }

  void onPointerUp(PointerUpEvent e) => _last = null;
  void onPointerCancel(PointerCancelEvent e) => _last = null;

  void onPointerMove(PointerMoveEvent e) {
    if (_last == null) return;

    final dx = e.localPosition.dx - _last!.dx;
    final dy = e.localPosition.dy - _last!.dy;

    if (dx.abs() < threshold && dy.abs() < threshold) return;

    Direction dir;

    if (dx.abs() > dy.abs()) {
      dir = dx > 0 ? Direction.right : Direction.left;
    } else {
      dir = dy > 0 ? Direction.down : Direction.up;
    }

    _last = e.localPosition;

    // IGNORE opposite direction
    if (_isOpposite(dir, lastApplied)) return;

    // Add to queue
    if (_queue.length < queueLimit) {
      _queue.add(dir);
    }
  }

  Direction? popForTick() {
    if (_queue.isEmpty) return null;
    final d = _queue.removeAt(0);
    lastApplied = d;
    return d;
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
           (a == Direction.down && b == Direction.up) ||
           (a == Direction.left && b == Direction.right) ||
           (a == Direction.right && b == Direction.left);
  }
}
