// lib/screens/main_menu_screen.dart
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/music_manager.dart';
import '../core/utils/sound_manager.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  
  @override
  void initState() {
    super.initState();
    MusicManager.playBGM();
  }

  Future<void> _navigateTo(BuildContext context, String routeName) async {
    SoundManager.playClick();
    if (routeName == '/game') {
      MusicManager.stopBGM();
    }
    
    await Navigator.pushNamed(context, routeName);
    
    // When we return from Game/Settings, resume BGM
    MusicManager.playBGM();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SNAKE FUSION',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
            _MenuButton(
              text: 'Start Game',
              icon: Icons.play_arrow,
              color: AppColors.success,
              onPressed: () => _navigateTo(context, '/game'),
            ),
            const SizedBox(height: 20),
            _MenuButton(
              text: 'Shop',
              icon: Icons.shopping_bag,
              color: AppColors.doubleScore,
              onPressed: () => _navigateTo(context, '/shop'),
            ),
            const SizedBox(height: 20),
            _MenuButton(
              text: 'Leaderboard',
              icon: Icons.leaderboard,
              color: AppColors.warning,
              onPressed: () => _navigateTo(context, '/leaderboard'),
            ),
            const SizedBox(height: 20),
            _MenuButton(
              text: 'Settings',
              icon: Icons.settings,
              color: AppColors.textSecondary,
              onPressed: () => _navigateTo(context, '/settings'),
            ),
            const SizedBox(height: 20),
            _MenuButton(
              text: 'How to Play',
              icon: Icons.help_outline,
              color: AppColors.accent,
              onPressed: () => _navigateTo(context, '/tutorial'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        fixedSize: const Size(280, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}