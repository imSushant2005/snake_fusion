// lib/main.dart
import 'package:flutter/material.dart';
import 'package:snake_fusion/core/constants/app_colors.dart';
import 'screens/game_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tutorial_screen.dart';
import 'screens/shop_screen.dart';
import 'services/settings_service.dart';
import 'services/music_manager.dart';

void main() async {
  // Initialize services before the app runs
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  await MusicManager.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Fusion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/tutorial': (context) => const TutorialScreen(),
        '/shop': (context) => const ShopScreen(),
      },
    );
  }
}