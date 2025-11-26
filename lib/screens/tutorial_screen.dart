import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({Key? key}) : super(key: key);

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int step = 0;

  final List<Map<String, dynamic>> tutorialSteps = [
    {'title': 'Swipe to Move', 'desc': 'Swipe up/down/left/right to control your snake.', 'icon': Icons.swipe},
    {'title': 'Avoid Obstacles', 'desc': 'Devil blocks are big and silly — avoid or you lose!', 'icon': Icons.block},
    {'title': 'Portals', 'desc': 'After scoring enough a portal appears. Enter it to go next level.', 'icon': Icons.auto_mode},
    {'title': 'Enemy Snake', 'desc': 'A tiny enemy will chase you — don\'t get caught!', 'icon': Icons.pets},
    {'title': 'Ready?', 'desc': 'Let\'s play and become the fusion master!', 'icon': Icons.rocket_launch},
  ];

  void _next() {
    if (step < tutorialSteps.length - 1) {
      setState(() => step++);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tutorialSteps[step];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(t['icon'], size: 96, color: AppColors.accent),
              const SizedBox(height: 18),
              Text(t['title'], style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(t['desc'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _next, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)), child: Text(step == tutorialSteps.length - 1 ? 'START' : 'NEXT', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            ]),
          ),
        ),
      ),
    );
  }
}
