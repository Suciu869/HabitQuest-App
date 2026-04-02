import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quest.dart';

class QuestStorage {
  static const String _keyQuests = 'hq_quests_v1';
  static const String _keyLastActiveDate = 'hq_last_active_date_v1';

  Future<List<Quest>> loadQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQuests);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((m) => Quest.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> saveQuests(List<Quest> quests) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = quests.map((q) => q.toMap()).toList();
    await prefs.setString(_keyQuests, jsonEncode(payload));
  }

  Future<DateTime?> loadLastActiveDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastActiveDate);
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> saveLastActiveDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final d = DateTime(date.year, date.month, date.day);
    await prefs.setString(_keyLastActiveDate, d.toIso8601String());
  }
}

