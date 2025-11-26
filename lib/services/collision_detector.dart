// lib/services/collision_detector.dart
import 'package:flutter/material.dart';

class CollisionDetector {
  bool check(Offset position, List<Offset> obstacles) {
    return obstacles.contains(position);
  }

  bool checkSelf(List<Offset> body) {
    if (body.length <= 1) {
      return false;
    }
    
    final head = body.first;
    return body.skip(1).contains(head);
  }
  
  bool checkBodies(List<Offset> bodyA, List<Offset> bodyB) {
    for (final partA in bodyA) {
      if (bodyB.contains(partA)) {
        return true;
      }
    }
    return false;
  }
}