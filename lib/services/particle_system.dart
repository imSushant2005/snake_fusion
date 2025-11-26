import 'dart:math';
import 'package:flutter/material.dart';
import '../models/particle.dart';
import '../core/enums/game_enums.dart';
class ParticleSystem {
  final List<Particle> particles = [];
  final Random _r = Random();
  void update() {
    particles.removeWhere((p) => !p.isAlive);
    for (var p in particles) {
      p.update(0.016);
    }
  }
  void clear() => particles.clear();
  void createFoodParticles(Offset pos) {
    for (int i=0;i<12;i++){
      final a = (i/12)*2*pi;
      final s = 2+_r.nextDouble()*2;
      particles.add(Particle(position: pos, velocity: Offset(cos(a)*s, sin(a)*s), color: Colors.orange, size: 2.0, type: ParticleType.food));
    }
  }
  void createPowerUpParticles(Offset pos, Color c) { }
  void createCollisionParticles(Offset pos, Color c) { }
  void createTrailParticle(Offset pos, Color c) { }
}
