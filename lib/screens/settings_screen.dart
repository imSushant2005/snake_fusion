// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/enums/game_enums.dart';
import '../services/settings_service.dart';
import '../services/music_manager.dart';
import '../core/utils/storage_manager.dart';
import '../core/utils/sound_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _soundEnabled;
  late bool _musicEnabled;
  late Difficulty _difficulty;

  @override
  void initState() {
    super.initState();
    _soundEnabled = SettingsService.soundEnabled;
    _musicEnabled = SettingsService.musicEnabled;
    _difficulty = SettingsService.difficulty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Audio'),
          SwitchListTile(
            title: const Text('Sound Effects (SFX)', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Eat, power-ups, game over, etc.'),
            secondary: const Icon(Icons.volume_up, color: AppColors.accent),
            value: _soundEnabled,
            onChanged: (value) async {
              await SettingsService.setSoundEnabled(value);
              setState(() {
                _soundEnabled = value;
              });
              if (value) SoundManager.playClick();
            },
          ),
          SwitchListTile(
            title: const Text('Music (BGM)', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Main menu background music'),
            secondary: const Icon(Icons.music_note, color: AppColors.accent),
            value: _musicEnabled,
            onChanged: (value) async {
              await SettingsService.setMusicEnabled(value);
              setState(() {
                _musicEnabled = value;
              });
              if (value) {
                MusicManager.playBGM();
              } else {
                MusicManager.stopBGM();
              }
            },
          ),
          _buildSectionHeader('Gameplay'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Difficulty', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SegmentedButton<Difficulty>(
              segments: const [
                ButtonSegment(value: Difficulty.easy, label: Text('Easy'), icon: Icon(Icons.mood)),
                ButtonSegment(value: Difficulty.normal, label: Text('Normal'), icon: Icon(Icons.person)),
                ButtonSegment(value: Difficulty.hard, label: Text('Hard'), icon: Icon(Icons.whatshot)),
              ],
              selected: {_difficulty},
              onSelectionChanged: (Set<Difficulty> newSelection) async {
                await SettingsService.setDifficulty(newSelection.first);
                setState(() {
                  _difficulty = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.backgroundSecondary,
                foregroundColor: Colors.white,
                selectedForegroundColor: AppColors.accent,
                selectedBackgroundColor: AppColors.background,
              ),
            ),
          ),

          _buildSectionHeader('Data'),
          ListTile(
            title: const Text('Clear Leaderboard', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Resets all saved high scores.'),
            leading: const Icon(Icons.delete_forever, color: AppColors.error),
            onTap: () {
              SoundManager.playClick();
              _showClearDataDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: const Text('Clear Leaderboard?'),
          content: const Text('This action cannot be undone. Are you sure you want to delete all high scores?'),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () {
                SoundManager.playClick();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Clear Data', style: TextStyle(color: AppColors.error)),
              onPressed: () async {
                SoundManager.playGameOver();
                await StorageManager.clearLeaderboard();
                Navigator.of(context).pop();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leaderboard has been cleared!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}