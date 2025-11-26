// lib/services/music_manager.dart
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class MusicManager {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isInitialized = false;

  static Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    _isInitialized = true;
  }

  static void playBGM() {
    if (!_isInitialized || !SettingsService.musicEnabled) return;
    try {
      _player.play(AssetSource('sounds/bgm.mp3'));
    } catch (_) {
      // Handle error
    }
  }

  static void stopBGM() {
    if (!_isInitialized) return;
    _player.stop();
  }
  
  static void updateVolume() {
    if (!_isInitialized) return;
    _player.setVolume(SettingsService.musicEnabled ? 1.0 : 0.0);
  }
}