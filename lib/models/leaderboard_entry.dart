// lib/models/leaderboard_entry.dart
import 'dart:convert';

class LeaderboardEntry {
  final int score;
  final int level;
  final int maxCombo;
  final DateTime date;

  LeaderboardEntry({
    required this.score,
    required this.level,
    required this.maxCombo,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
      'maxCombo': maxCombo,
      'date': date.toIso8601String(),
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      score: json['score'] ?? 0,
      level: json['level'] ?? 1,
      maxCombo: json['maxCombo'] ?? 0,
      date: DateTime.parse(json['date']),
    );
  }
}