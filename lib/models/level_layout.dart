// lib/models/level_layout.dart
import 'package:flutter/material.dart';

class LevelLayout {
  final List<Offset> staticObstacles;
  final List<Offset> movingObstacles;

  LevelLayout({
    this.staticObstacles = const [],
    this.movingObstacles = const [],
  });
}