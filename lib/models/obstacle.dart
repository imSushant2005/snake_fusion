import 'package:flutter/material.dart';

class Obstacle {
  final Offset position;
  final bool moving;

  Obstacle({required this.position, this.moving = false});

  Obstacle copyWith({Offset? position, bool? moving}) => Obstacle(position: position ?? this.position, moving: moving ?? this.moving);
}
