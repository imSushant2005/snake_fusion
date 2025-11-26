// lib/ai/ai_enemy.dart
import 'package:flutter/material.dart';

class AIEnemy {
  List<Offset> body = [];

  AIEnemy({required Offset head}) {
    body = [
      head,
      Offset(head.dx - 1, head.dy),
      Offset(head.dx - 2, head.dy),
    ];
  }

  Offset get head => body.first;

  void moveTo(Offset next) {
    body.insert(0, next);
    body.removeLast();
  }
}