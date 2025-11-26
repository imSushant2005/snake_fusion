// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../core/enums/game_enums.dart';

class SettingsService {
  static SharedPreferences? _prefs;

  static const String _soundKey = 'soundEnabled';
  static const String _musicKey = 'musicEnabled';
  static const String _difficultyKey = 'difficulty';

  static const String _coinsKey = 'coins';
  static const String _equippedSkinKey = 'equippedSkin';
  static const String _ownedSkinsKey = 'ownedSkins';

  static bool soundEnabled = true;
  static bool musicEnabled = true;
  static Difficulty difficulty = Difficulty.normal;
  
  static int coins = 0;
  static String equippedSkinId = 'neon_cyan';
  static List<String> ownedSkins = ['neon_cyan'];

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadSettings();
  }

  static Future<void> loadSettings() async {
    soundEnabled = _prefs?.getBool(_soundKey) ?? true;
    musicEnabled = _prefs?.getBool(_musicKey) ?? true;
    
    String diffString = _prefs?.getString(_difficultyKey) ?? Difficulty.normal.name;
    difficulty = Difficulty.values.firstWhere(
      (d) => d.name == diffString,
      orElse: () => Difficulty.normal,
    );

    coins = _prefs?.getInt(_coinsKey) ?? 0;
    equippedSkinId = _prefs?.getString(_equippedSkinKey) ?? 'neon_cyan';
    ownedSkins = _prefs?.getStringList(_ownedSkinsKey) ?? ['neon_cyan'];
  }

  static Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await _prefs?.setBool(_soundKey, value);
  }

  static Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    await _prefs?.setBool(_musicKey, value);
  }

  static Future<void> setDifficulty(Difficulty value) async {
    difficulty = value;
    await _prefs?.setString(_difficultyKey, value.name);
  }

  static Future<void> setCoins(int value) async {
    coins = value;
    await _prefs?.setInt(_coinsKey, value);
  }

  static Future<void> setEquippedSkin(String skinId) async {
    equippedSkinId = skinId;
    await _prefs?.setString(_equippedSkinKey, skinId);
  }

  static Future<void> addOwnedSkin(String skinId) async {
    if (!ownedSkins.contains(skinId)) {
      ownedSkins.add(skinId);
      await _prefs?.setStringList(_ownedSkinsKey, ownedSkins);
    }
  }
}