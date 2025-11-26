// lib/core/utils/sound_manager.dart
import 'package:audioplayers/audioplayers.dart';
import '../../services/settings_service.dart';

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();
  // soundEnabled is now controlled by SettingsService

  static Future<void> _play(String file) async {
    if (!SettingsService.soundEnabled) return; 
    try {
      await _player.play(AssetSource('sounds/$file'));
    } catch (_) {
      // swallow audio errors
    }
  }

  static void playEat() => _play("eat.mp3");
  static void playPowerUp() => _play("powerup.mp3");
  static void playGameOver() => _play("game_over.mp3");
  static void playLevelUp() => _play("level_up.mp3");
  static void playPortalAppear() => _play("portal_appear.mp3");
  static void playPortalEnter() => _play("portal_enter.mp3");
  static void playShieldHit() => _play("shield_hit.wav");
  static void playEnemyNear() => _play("enemy_near.wav");
  static void playDevilGuffaw() => _play("devil_laugh.wav");
  static void playClick() => _play("click.wav");
}