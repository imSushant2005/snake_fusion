// lib/services/level_generator.dart
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/level_layout.dart';
import '../core/enums/game_enums.dart';

enum BiomeV2 {
  grid,
  digitalRain,
  glitchCity,
  solarFlare,
}

/// High-level hazard types produced by the generator.
/// The generator returns hazard *metadata* which the game loop should
/// consume to animate / enable behaviors.
enum HazardType {
  rotatingBlade,   // rotating around a center
  snapLine,        // telegraphed horizontal/vertical instant line
  flickerWall,     // toggling wall tiles
  reverseZone,     // tiles that invert controls when stepped on
  gravityWell,     // pulls snake slightly (visual only unless implemented)
  lavaCrack,       // line that moves slowly across map
  teleportTile,    // when stepped, teleports snake (telegraph first)
  shadowSnake,     // mini enemy spawns list
  solarWave,       // expanding ring (telegraphed)
}

class Hazard {
  final HazardType type;
  final List<Offset> tiles; // tiles affected (initial)
  final Offset? center; // center for rotating blades / waves
  final int durationTicks; // how long hazard is active (ticks)
  final int warnTicks; // how many ticks of warning before activation
  final Map<String, dynamic>? meta; // freeform extra data (speed, dir, radius)

  Hazard({
    required this.type,
    required this.tiles,
    this.center,
    this.durationTicks = 40,
    this.warnTicks = 6,
    this.meta,
  });
}

/// Lightweight event schedule entry.
class LevelEvent {
  final int tickOffset; // ticks after level start to trigger
  final Hazard hazard;
  LevelEvent({required this.tickOffset, required this.hazard});
}

/// LevelGeneratorV2: Advanced hybrid generator with Devil mechanics.
class LevelGeneratorV2 {
  final Random _rnd;
  // last generated metadata (read by the GameController)
  List<Hazard> lastHazards = [];
  List<LevelEvent> lastEvents = [];

  LevelGeneratorV2({int? seed}) : _rnd = seed == null ? Random() : Random(seed);

  // PUBLIC API: identical signature to old generator for compatibility.
  LevelLayout generateLevel(
    int level, {
    required int hGrid,
    required int vGrid,
    required List<Offset> reserved,
  }) {
    // Prepare / copy reserved so we don't mutate caller's list.
    final reservedCopy = List<Offset>.from(reserved);
    final biome = _getBiomeForLevel(level);
    final targetReachPct = _getTargetReachability(level); // e.g., 0.35

    // Retry generation if flood-fill fails (keeps levels playable)
    for (int attempt = 0; attempt < 12; attempt++) {
      lastHazards = [];
      lastEvents = [];

      final layout = _generateForBiome(
        level,
        hGrid: hGrid,
        vGrid: vGrid,
        reserved: reservedCopy,
        biome: biome,
      );

      final reachable = _reachableAreaPct(
        hGrid,
        vGrid,
        layout.staticObstacles,
        layout.movingObstacles,
        reservedCopy,
        start: _guessPlayerStart(reservedCopy, hGrid, vGrid),
      );

      if (reachable >= targetReachPct || attempt == 11) {
        // success (or last attempt) -> return
        return layout;
      } else {
        // failed -> slightly reduce obstacle density and retry
        _relaxReserved(reservedCopy);
      }
    }

    // fallback: empty layout
    return LevelLayout(staticObstacles: [], movingObstacles: []);
  }

  // ------------------------------
  // BIOME / DIFFICULTY UTIL
  // ------------------------------
  BiomeV2 _getBiomeForLevel(int level) {
    if (level <= 5) return BiomeV2.grid;
    if (level <= 10) return BiomeV2.digitalRain;
    if (level <= 15) return BiomeV2.glitchCity;
    return BiomeV2.solarFlare;
  }

  double _getTargetReachability(int level) {
    // Hybrid curve: early easier, later allow tighter maps
    if (level <= 5) return 0.55;
    if (level <= 12) return 0.45;
    if (level <= 18) return 0.40;
    return 0.35;
  }

  double _getDensityModifier(int level) {
    // Increased density for more obstacles
    if (level <= 5) return 1.2;   // was 0.6
    if (level <= 12) return 1.8;  // was 1.0
    if (level <= 18) return 2.5;  // was 1.35
    return 3.2;                   // was 1.7
  }

  // ------------------------------
  // CORE GENERATION - per-biome
  // ------------------------------
  LevelLayout _generateForBiome(
    int level, {
    required int hGrid,
    required int vGrid,
    required List<Offset> reserved,
    required BiomeV2 biome,
  }) {
    // collectors
    final staticSet = <Offset>{};
    final movingSet = <Offset>{};

    // convenience
    final densityBase = (min(hGrid, vGrid) * 0.25).round();
    final density = max(3, (densityBase * _getDensityModifier(level)).round());

    // common generator helpers (closures)
    Offset? findSafe() {
      for (int tries = 0; tries < 200; tries++) {
        final pos = Offset(
          _rnd.nextInt(hGrid).toDouble(),
          _rnd.nextInt(vGrid).toDouble(),
        );
        if (!reserved.contains(pos) && !staticSet.contains(pos) && !movingSet.contains(pos)) return pos;
      }
      return null;
    }

    // Generate base obstacles according to biome
    switch (biome) {
      case BiomeV2.grid:
        _genGridClassic(level, hGrid, vGrid, reserved, staticSet, movingSet, density);
        break;
      case BiomeV2.digitalRain:
        _genDigitalRain(level, hGrid, vGrid, reserved, staticSet, movingSet, density);
        break;
      case BiomeV2.glitchCity:
        _genGlitchCity(level, hGrid, vGrid, reserved, staticSet, movingSet, density);
        break;
      case BiomeV2.solarFlare:
        _genSolarFlare(level, hGrid, vGrid, reserved, staticSet, movingSet, density);
        break;
    }

    // After base obstacles, add a small number of hazards (Devil-style) based on level intensity.
    _injectHazards(level, hGrid, vGrid, reserved, staticSet, movingSet);

    // Reserve final positions to caller list (so other systems see them)
    for (final o in staticSet) {
      reserved.add(o);
    }
    for (final o in movingSet) {
      reserved.add(o);
    }

    // Return a LevelLayout (same shape as before)
    return LevelLayout(
      staticObstacles: staticSet.toList(),
      movingObstacles: movingSet.toList(),
    );
  }

  // ------------------------------
  // BIOmE IMPLEMENTATIONS
  // ------------------------------
  void _genGridClassic(
    int level,
    int h,
    int v,
    List<Offset> reserved,
    Set<Offset> staticSet,
    Set<Offset> movingSet,
    int density,
  ) {
    // patterns: boxes, rings, mirror lines, clusters, FILLED STRUCTURES
    final choice = level % 6;  // Changed from 5 to 6 for more variety
    if (choice == 1) {
      _addClusters(staticSet, reserved, h, v, clusterCount: 3 + (level ~/ 5), clusterSize: 5);
    } else if (choice == 2) {
      _addBox(staticSet, reserved, h, v, size: 6 + (level % 4));
      // Add a filled rectangle too
      _addFilledRect(staticSet, reserved, h, v, width: 4, height: 3);
    } else if (choice == 3) {
      _addMirrorLines(staticSet, reserved, h, v, count: 2 + (level % 3));
      // Add pyramid
      _addPyramid(staticSet, reserved, h, v, size: 3 + (level % 3));
    } else if (choice == 4) {
      _addRings(staticSet, reserved, h, v, rings: 1 + (level % 3));
      // Add filled diamond
      _addFilledDiamond(staticSet, reserved, h, v, size: 3);
    } else if (choice == 5) {
      // New: Multiple filled blocks
      _addFilledRect(staticSet, reserved, h, v, width: 5, height: 4);
      _addFilledRect(staticSet, reserved, h, v, width: 3, height: 3);
    } else {
      _addScattered(staticSet, reserved, h, v, count: density * 2);  // Double scattered
    }
  }

  void _genDigitalRain(
    int level,
    int h,
    int v,
    List<Offset> reserved,
    Set<Offset> staticSet,
    Set<Offset> movingSet,
    int density,
  ) {
    // vertical lines that move; some static vertical segments
    final lines = 2 + (level % 4);
    for (int i = 0; i < lines; i++) {
      final x = _rnd.nextInt(h);
      final len = 4 + _rnd.nextInt(min(8, v ~/ 4));
      final start = max(0, (v ~/ 2) - (len ~/ 2) + _rnd.nextInt(max(1, v ~/ 3)));
      for (int y = start; y < start + len; y++) {
        final pos = Offset(x.toDouble(), (y % v).toDouble());
        if (!reserved.contains(pos)) movingSet.add(pos);
      }
    }

    // also scattered static blocks
    _addScattered(staticSet, reserved, h, v, count: (density * 0.6).round());
  }

  void _genGlitchCity(
    int level,
    int h,
    int v,
    List<Offset> reserved,
    Set<Offset> staticSet,
    Set<Offset> movingSet,
    int density,
  ) {
    // Many small clusters, flicker walls, teleport nodes
    _addClusters(staticSet, reserved, h, v, clusterCount: 4, clusterSize: 3);
    _addScattered(staticSet, reserved, h, v, count: (density * 0.6).round());
    // spawn a flicker wall hazard metadata (tiles chosen)
    final flicker = _samplePositions(6, h, v, reserved);
    if (flicker.isNotEmpty) {
      lastHazards.add(Hazard(
        type: HazardType.flickerWall,
        tiles: flicker,
        durationTicks: 120,
        warnTicks: 8,
        meta: {'interval': 6 + (level % 4)},
      ));
    }
  }

  void _genSolarFlare(
    int level,
    int h,
    int v,
    List<Offset> reserved,
    Set<Offset> staticSet,
    Set<Offset> movingSet,
    int density,
  ) {
    // Rotating boxes, solar waves and flare beams
    _addBox(staticSet, reserved, h, v, size: 6 + (level % 6));
    _addRings(staticSet, reserved, h, v, rings: 1 + (level % 3));
    // Add some long horizontal beams as moving obstacles (will need game loop to animate)
    final beams = _samplePositions(3, h, v, reserved);
    for (final b in beams) {
      movingSet.add(b);
    }

    // schedule solar wave events (telegraphed)
    final center = _chooseCenter(h, v, reserved);
    if (center != null) {
      final H = Hazard(
        type: HazardType.solarWave,
        tiles: [center],
        center: center,
        durationTicks: 60,
        warnTicks: 10,
        meta: {'maxRadius': min(h, v) ~/ 2},
      );
      lastEvents.add(LevelEvent(tickOffset: 8 + _rnd.nextInt(8), hazard: H));
    }
  }

  // ------------------------------
  // HAZARD INJECTION (DEVIL-LIKE)
  // ------------------------------
  void _injectHazards(
    int level,
    int h,
    int v,
    List<Offset> reserved,
    Set<Offset> staticSet,
    Set<Offset> movingSet,
  ) {
    final intensity = _getHazardIntensity(level);

    // Rotating blades near center sometimes
    if (_rnd.nextDouble() < 0.25 * intensity) {
      final center = _chooseCenter(h, v, reserved) ?? Offset((h ~/ 2).toDouble(), (v ~/ 2).toDouble());
      final blades = _generateRotatingBladeTiles(center, radius: 2 + (level % 3), hGrid: h, vGrid: v);
      lastHazards.add(Hazard(
        type: HazardType.rotatingBlade,
        tiles: blades,
        center: center,
        durationTicks: 80 + (level * 2),
        warnTicks: 6,
        meta: {'clockwise': _rnd.nextBool() ? 1 : -1, 'speed': 1 + (level ~/ 6)},
      ));
    }

    // Snap lines: instantaneous telegraphed line across a row/col
    if (_rnd.nextDouble() < 0.20 * intensity) {
      final horizontal = _rnd.nextBool();
      final index = horizontal ? _rnd.nextInt(v) : _rnd.nextInt(h);
      final tiles = <Offset>[];
      if (horizontal) {
        for (int x = 0; x < h; x++) tiles.add(Offset(x.toDouble(), index.toDouble()));
      } else {
        for (int y = 0; y < v; y++) tiles.add(Offset(index.toDouble(), y.toDouble()));
      }
      lastEvents.add(LevelEvent(tickOffset: 6 + _rnd.nextInt(12), hazard: Hazard(
        type: HazardType.snapLine, tiles: tiles, durationTicks: 2, warnTicks: 4, meta: {'horizontal': horizontal},
      )));
    }

    // Reverse control zones sprinkled
    if (_rnd.nextDouble() < 0.18 * intensity) {
      final tile = _chooseCenter(h, v, reserved);
      if (tile != null) {
        lastHazards.add(Hazard(
          type: HazardType.reverseZone,
          tiles: [tile],
          durationTicks: 60 + (level * 2),
          warnTicks: 3,
          meta: {'radius': 0},
        ));
      }
    }

    // Lava crack line traveling across
    if (_rnd.nextDouble() < 0.12 * intensity) {
      final horizontal = _rnd.nextBool();
      final index = horizontal ? _rnd.nextInt(v) : _rnd.nextInt(h);
      final initialTiles = <Offset>[];
      if (horizontal) {
        for (int x = 0; x < h; x++) initialTiles.add(Offset(x.toDouble(), index.toDouble()));
      } else {
        for (int y = 0; y < v; y++) initialTiles.add(Offset(index.toDouble(), y.toDouble()));
      }
      lastHazards.add(Hazard(
        type: HazardType.lavaCrack,
        tiles: initialTiles,
        durationTicks: 120,
        warnTicks: 8,
        meta: {'dir': horizontal ? 'H' : 'V', 'speed': 1 + (level ~/ 8)},
      ));
    }

    // Teleport tiles (telegraph then enable)
    if (_rnd.nextDouble() < 0.12 * intensity) {
      final pos = _chooseCenter(h, v, reserved);
      final dest = _findSomewhereFar(h, v, reserved, origin: pos);
      if (pos != null && dest != null) {
        lastEvents.add(LevelEvent(tickOffset: 10 + _rnd.nextInt(10),
            hazard: Hazard(
          type: HazardType.teleportTile,
          tiles: [pos, dest],
          durationTicks: 40,
          warnTicks: 6,
          meta: {'dest': dest},
        )));
      }
    }

    // Shadow snake (mini enemy) spawn
    if (_rnd.nextDouble() < 0.10 * intensity) {
      final spawn = _chooseCenter(h, v, reserved);
      if (spawn != null) {
        lastHazards.add(Hazard(
          type: HazardType.shadowSnake,
          tiles: [spawn],
          durationTicks: 200,
          warnTicks: 4,
          meta: {'length': 3 + (_rnd.nextInt(3))},
        ));
      }
    }
  }

  double _getHazardIntensity(int level) {
    // 1.0 = baseline, increases as level grows (hybrid curve)
    if (level <= 5) return 0.4;
    if (level <= 12) return 0.9;
    if (level <= 18) return 1.25;
    return 1.8;
  }

  // ------------------------------
  // SMALL PATTERN HELPERS
  // ------------------------------
  void _addScattered(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int count}) {
    for (int i = 0; i < count; i++) {
      final p = _sampleOne(h, v, reserved);
      if (p != null) {
        dest.add(p);
        reserved.add(p);
      }
    }
  }

  void _addClusters(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int clusterCount, required int clusterSize}) {
    for (int c = 0; c < clusterCount; c++) {
      final center = _sampleOne(h, v, reserved);
      if (center == null) continue;
      dest.add(center);
      reserved.add(center);
      for (int j = 0; j < clusterSize; j++) {
        final dx = (_rnd.nextInt(3) - 1).toDouble();
        final dy = (_rnd.nextInt(3) - 1).toDouble();
        final pos = Offset(
          (center.dx + dx).clamp(0, h - 1),
          (center.dy + dy).clamp(0, v - 1),
        );
        if (!reserved.contains(pos)) {
          dest.add(pos);
          reserved.add(pos);
        }
      }
    }
  }

  void _addBox(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int size}) {
    final left = (h ~/ 2) - (size ~/ 2);
    final top = (v ~/ 2) - (size ~/ 2);
    for (int i = 0; i < size; i++) {
      final topPos = Offset((left + i).toDouble(), top.toDouble());
      final botPos = Offset((left + i).toDouble(), (top + size - 1).toDouble());
      final leftPos = Offset(left.toDouble(), (top + i).toDouble());
      final rightPos = Offset((left + size - 1).toDouble(), (top + i).toDouble());
      if (!reserved.contains(topPos)) { dest.add(topPos); reserved.add(topPos); }
      if (!reserved.contains(botPos)) { dest.add(botPos); reserved.add(botPos); }
      if (!reserved.contains(leftPos)) { dest.add(leftPos); reserved.add(leftPos); }
      if (!reserved.contains(rightPos)) { dest.add(rightPos); reserved.add(rightPos); }
    }
  }

  void _addRings(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int rings}) {
    final cx = (h ~/ 2).toDouble();
    final cy = (v ~/ 2).toDouble();
    for (int r = 1; r <= rings; r++) {
      final radius = 2 + r;
      for (int dx = -radius; dx <= radius; dx++) {
        for (int dy = -radius; dy <= radius; dy++) {
          if (dx.abs() == radius || dy.abs() == radius) {
            final pos = Offset((cx + dx).clamp(0, h - 1), (cy + dy).clamp(0, v - 1));
            if (!reserved.contains(pos)) { dest.add(pos); reserved.add(pos); }
          }
        }
      }
    }
  }

  void _addMirrorLines(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int count}) {
    final centerX = h ~/ 2;
    for (int i = 0; i < count; i++) {
      final offset = (i + 1);
      for (int y = 2; y < v - 2; y += 2) {
        final left = Offset((centerX - offset).toDouble(), y.toDouble());
        final right = Offset((centerX + offset).toDouble(), y.toDouble());
        if (!reserved.contains(left)) { dest.add(left); reserved.add(left); }
        if (!reserved.contains(right)) { dest.add(right); reserved.add(right); }
      }
    }
  }

  // ------------------------------
  // POSITION SAMPLING UTILITIES
  // ------------------------------
  Offset? _sampleOne(int h, int v, List<Offset> reserved) {
    for (int tries = 0; tries < 120; tries++) {
      final pos = Offset(_rnd.nextInt(h).toDouble(), _rnd.nextInt(v).toDouble());
      if (!reserved.contains(pos)) return pos;
    }
    return null;
  }

  List<Offset> _samplePositions(int count, int h, int v, List<Offset> reserved) {
    final out = <Offset>[];
    for (int i = 0; i < count; i++) {
      final p = _sampleOne(h, v, reserved);
      if (p != null) {
        out.add(p);
        reserved.add(p);
      }
    }
    return out;
  }

  Offset? _chooseCenter(int h, int v, List<Offset> reserved) {
    // Prefer center, otherwise sample valid and roughly central position
    final center = Offset((h ~/ 2).toDouble(), (v ~/ 2).toDouble());
    if (!reserved.contains(center)) return center;
    return _sampleOne(h, v, reserved);
  }

  Offset? _findSomewhereFar(int h, int v, List<Offset> reserved, {Offset? origin}) {
    // Find a free tile at least ~min(h,v)/3 away from origin
    final minDist = (min(h, v) / 3).floor();
    for (int tries = 0; tries < 200; tries++) {
      final p = _sampleOne(h, v, reserved);
      if (p == null) continue;
      if (origin == null) return p;
      final dx = (p.dx - origin.dx).abs();
      final dy = (p.dy - origin.dy).abs();
      if (sqrt(dx * dx + dy * dy) >= minDist) return p;
    }
    return null;
  }

  List<Offset> _generateRotatingBladeTiles(Offset center, {required int radius, required int hGrid, required int vGrid}) {
    final tiles = <Offset>[];
    final cx = center.dx.toInt();
    final cy = center.dy.toInt();
    for (int dx = -radius; dx <= radius; dx++) {
      final x = cx + dx;
      if (x < 0 || x >= hGrid) continue;
      tiles.add(Offset(x.toDouble(), cy.toDouble()));
    }
    for (int dy = -radius; dy <= radius; dy++) {
      final y = cy + dy;
      if (y < 0 || y >= vGrid) continue;
      tiles.add(Offset(cx.toDouble(), y.toDouble()));
    }
    // remove center
    tiles.removeWhere((o) => o.dx == center.dx && o.dy == center.dy);
    return tiles;
  }

  // ------------------------------
  // POST-GEN HELPERS
  // ------------------------------
  void _relaxReserved(List<Offset> reserved) {
    // randomly remove a few reserved items to relax tight maps
    if (reserved.isEmpty) return;
    final toRemove = min(reserved.length, 2 + _rnd.nextInt(4));
    for (int i = 0; i < toRemove; i++) {
      reserved.removeAt(_rnd.nextInt(reserved.length));
    }
  }

  Offset? _guessPlayerStart(List<Offset> reserved, int h, int v) {
    // Try find a reserved coordinate near center that is free, else fallback to center
    final center = Offset((h ~/ 2).toDouble(), (v ~/ 2).toDouble());
    if (!reserved.contains(center)) return center;
    final alt = _sampleOne(h, v, reserved);
    return alt ?? center;
  }

  // ------------------------------
  // REACHABILITY (BFS) to ensure level is solvable/playable
  // ------------------------------
  double _reachableAreaPct(
    int h,
    int v,
    List<Offset> staticObs,
    List<Offset> movingObs,
    List<Offset> reserved,
    {Offset? start}
  ) {
    final blocked = <Point<int>>{};
    for (final o in staticObs) blocked.add(Point(o.dx.toInt(), o.dy.toInt()));
    for (final o in movingObs) blocked.add(Point(o.dx.toInt(), o.dy.toInt()));
    for (final o in reserved) blocked.add(Point(o.dx.toInt(), o.dy.toInt()));

    final s = start ?? Offset((h ~/ 2).toDouble(), (v ~/ 2).toDouble());
    final startP = Point<int>(s.dx.toInt(), s.dy.toInt());
    if (blocked.contains(startP)) {
      // Try find a free start
      bool found = false;
      for (int y = 0; y < v && !found; y++) {
        for (int x = 0; x < h && !found; x++) {
          final p = Point<int>(x, y);
          if (!blocked.contains(p)) {
            found = true;
            break;
          }
        }
      }
      if (!found) return 0.0;
    }

    final visited = <Point<int>>{};
    final q = Queue<Point<int>>();
    q.add(startP);
    visited.add(startP);

    final dirs = [Point(1,0), Point(-1,0), Point(0,1), Point(0,-1)];
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final d in dirs) {
        final nx = cur.x + d.x;
        final ny = cur.y + d.y;
        final np = Point<int>(nx, ny);
        if (nx < 0 || nx >= h || ny < 0 || ny >= v) continue;
        if (blocked.contains(np)) continue;
        if (visited.contains(np)) continue;
        visited.add(np);
        q.add(np);
      }
    }

    final total = h * v;
    if (total == 0) return 0.0;
    return visited.length / total;
  }

  // ------------------------------
  // FILLED STRUCTURE HELPERS
  // ------------------------------
  void _addFilledRect(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int width, required int height}) {
    final left = (h ~/ 2) - (width ~/ 2);
    final top = (v ~/ 2) - (height ~/ 2);
    
    // Fill entire rectangle
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pos = Offset(
          (left + x).clamp(0, h - 1).toDouble(),
          (top + y).clamp(0, v - 1).toDouble(),
        );
        if (!reserved.contains(pos)) {
          dest.add(pos);
          reserved.add(pos);
        }
      }
    }
  }

  void _addPyramid(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int size}) {
    final cx = h ~/ 2;
    final cy = v ~/ 2;
    
    // Build pyramid from top to bottom
    for (int row = 0; row < size; row++) {
      final width = (row * 2) + 1;
      final startX = cx - row;
      final y = cy - (size ~/ 2) + row;
      
      for (int x = 0; x < width; x++) {
        final pos = Offset(
          (startX + x).clamp(0, h - 1).toDouble(),
          y.clamp(0, v - 1).toDouble(),
        );
        if (!reserved.contains(pos)) {
          dest.add(pos);
          reserved.add(pos);
        }
      }
    }
  }

  void _addFilledDiamond(Set<Offset> dest, List<Offset> reserved, int h, int v, {required int size}) {
    final cx = h ~/ 2;
    final cy = v ~/ 2;
    
    // Top half of diamond
    for (int row = 0; row <= size; row++) {
      final width = (row * 2) + 1;
      final startX = cx - row;
      final y = cy - size + row;
      
      for (int x = 0; x < width; x++) {
        final pos = Offset(
          (startX + x).clamp(0, h - 1).toDouble(),
          y.clamp(0, v - 1).toDouble(),
        );
        if (!reserved.contains(pos)) {
          dest.add(pos);
          reserved.add(pos);
        }
      }
    }
    
    // Bottom half of diamond
    for (int row = 1; row <= size; row++) {
      final width = ((size - row) * 2) + 1;
      final startX = cx - (size - row);
      final y = cy + row;
      
      for (int x = 0; x < width; x++) {
        final pos = Offset(
          (startX + x).clamp(0, h - 1).toDouble(),
          y.clamp(0, v - 1).toDouble(),
        );
        if (!reserved.contains(pos)) {
          dest.add(pos);
          reserved.add(pos);
        }
      }
    }
  }
}
