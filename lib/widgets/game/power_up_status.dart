import 'package:flutter/material.dart';
import '../../core/enums/game_enums.dart';

class PowerUpStatusBar extends StatelessWidget {
  final Map<PowerUpType,int> activePowerUps;
  const PowerUpStatusBar({super.key, required this.activePowerUps});
  @override
  Widget build(BuildContext context) {
    if (activePowerUps.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
      color: Colors.black26,
      child: Wrap(
        spacing: 8,
        children: activePowerUps.entries.map((e){
          return Chip(label: Text('${e.key.toString().split(".").last} ${e.value}s'));
        }).toList(),
      ),
    );
  }
}
