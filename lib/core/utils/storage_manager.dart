// lib/core/utils/storage_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/leaderboard_entry.dart';

class StorageManager {
  static const String _leaderboardKey = 'leaderboard';
  static const int _maxEntries = 10;
  static const String _totalGamesKey = 'totalGames';
  static const String _totalScoreKey = 'totalScore';

  static Future<List<LeaderboardEntry>> getLeaderboardEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> entriesJson = prefs.getStringList(_leaderboardKey) ?? [];

    final entries = entriesJson
        .map((jsonString) =>
            LeaderboardEntry.fromJson(jsonDecode(jsonString)))
        .toList();
        
    entries.sort((a, b) => b.score.compareTo(a.score));
    
    return entries;
  }

  static Future<void> addLeaderboardEntry(LeaderboardEntry newEntry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getLeaderboardEntries();
    
    entries.add(newEntry);
    entries.sort((a, b) => b.score.compareTo(a.score));
    
    final topEntries = entries.take(_maxEntries).toList();

    final List<String> entriesJson = topEntries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
        
    await prefs.setStringList(_leaderboardKey, entriesJson);
  }

  static Future<int> getHighScore() async {
    final entries = await getLeaderboardEntries();
    if (entries.isEmpty) {
      return 0;
    }
    return entries.first.score;
  }
  
  static Future<void> clearLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_leaderboardKey);
  }

  static Future<int> getTotalGames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalGamesKey) ?? 0;
  }
  
  static Future<int> getTotalScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalScoreKey) ?? 0;
  }

  static Future<void> incrementTotalGames() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTotalGames();
    await prefs.setInt(_totalGamesKey, current + 1);
  }

  static Future<void> addToTotalScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTotalScore();
    await prefs.setInt(_totalScoreKey, current + score);
  }
}