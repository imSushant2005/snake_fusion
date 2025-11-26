import 'package:flutter/material.dart';
import '../core/enums/game_enums.dart';

class Particle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final ParticleType type;
  double opacity = 1.0;
  DateTime createdAt = DateTime.now();
  Particle({required this.position, required this.velocity, required this.color, required this.size, required this.type});
  bool get isAlive => DateTime.now().difference(createdAt).inMilliseconds < 1000;
  void update(double dt) {
    position += velocity * dt;
    velocity = Offset(velocity.dx * 0.95, velocity.dy * 0.95);
    final t = DateTime.now().difference(createdAt).inMilliseconds / 1000.0;
    opacity = (1.0 - t).clamp(0.0, 1.0);
  }
}
