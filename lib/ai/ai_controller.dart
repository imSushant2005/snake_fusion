// lib/ai/ai_controller.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class AIController {
  Offset getNextMove({
    required Offset from,
    required Offset target,
    required List<Offset> obstacles,
    required List<Offset> enemyBody,
    required int verticalGridSize,
    required int horizontalGridSize,
  }) {
    final allObstacles = {...obstacles, ...enemyBody};
    final openSet = PriorityQueue<_Node>((a, b) => a.fCost.compareTo(b.fCost));
    final closedSet = <Offset>{}; 
    final startNode = _Node(from, 0, _distance(from, target));
    openSet.add(startNode);
    final cameFrom = <Offset, Offset>{};

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();
      
      if (current.position == target) {
        return _reconstructPath(cameFrom, current.position);
      }
      
      closedSet.add(current.position);

      for (final neighbor in _getNeighbors(current.position, horizontalGridSize, verticalGridSize)) {
        if (closedSet.contains(neighbor) || allObstacles.contains(neighbor)) {
          continue;
        }
        
        final gCost = current.gCost + 1;
        final hCost = _distance(neighbor, target);
        final newNode = _Node(neighbor, gCost, hCost);

        if (!openSet.contains(newNode)) {
          cameFrom[neighbor] = current.position;
          openSet.add(newNode);
        }
      }
    }
    
    return _getGreedyFallback(from, target, allObstacles, horizontalGridSize, verticalGridSize);
  }

  Offset _reconstructPath(Map<Offset, Offset> cameFrom, Offset current) {
    while (cameFrom.containsKey(current)) {
      final prev = cameFrom[current]!;
      if (!cameFrom.containsKey(prev)) {
        return current;
      }
      current = prev;
    }
    return current;
  }
  
  List<Offset> _getNeighbors(Offset pos, int hGrid, int vGrid) {
    final neighbors = <Offset>[
      Offset(pos.dx, pos.dy - 1), // Up
      Offset(pos.dx, pos.dy + 1), // Down
      Offset(pos.dx - 1, pos.dy), // Left
      Offset(pos.dx + 1, pos.dy), // Right
    ];
    return neighbors.map((p) => _wrap(p, hGrid, vGrid)).toList();
  }
  
  double _distance(Offset a, Offset b) {
    return (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
  }

  Offset _wrap(Offset p, int hGrid, int vGrid) {
    final x = (p.dx + hGrid) % hGrid;
    final y = (p.dy + vGrid) % vGrid;
    return Offset(x.toDouble(), y.toDouble());
  }

  Offset _getGreedyFallback(Offset from, Offset target, Set<Offset> allObstacles, int hGrid, int vGrid) {
    double dx = target.dx - from.dx;
    double dy = target.dy - from.dy;

    List<Offset> priorities = [];
    if (dx.abs() > dy.abs()) {
      priorities.add(Offset(from.dx + (dx > 0 ? 1 : -1), from.dy));
    } else {
      priorities.add(Offset(from.dx, from.dy + (dy > 0 ? 1 : -1)));
    }
    
    final wrapped = _wrap(priorities.first, hGrid, vGrid);
    if (!allObstacles.contains(wrapped)) return wrapped;
    
    return from;
  }
}

/// Helper class for A*
class _Node {
  final Offset position;
  final double gCost;
  final double hCost;
  double get fCost => gCost + hCost;

  _Node(this.position, this.gCost, this.hCost);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Node &&
          runtimeType == other.runtimeType &&
          position == other.position;

  @override
  int get hashCode => position.hashCode;
}