import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quest.dart';

class QuestStorage {
  static const String _keyQuests = 'hq_quests_v1';
  static const String _keyLastActiveDate = 'hq_last_active_date_v1';
  static const String _keyDailyHistory = 'hq_daily_history_v1';

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

  Future<Map<DateTime, List<String>>> loadDailyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDailyHistory);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};

    final result = <DateTime, List<String>>{};
    decoded.forEach((dateKey, values) {
      final parsedDate = DateTime.tryParse(dateKey);
      if (parsedDate == null || values is! List) return;
      final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      result[dateOnly] = values.whereType<String>().toList();
    });
    return result;
  }

  Future<void> saveDailyHistory(Map<DateTime, List<String>> history) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, List<String>>{};
    history.forEach((date, titles) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      payload[dateOnly.toIso8601String()] = titles.toSet().toList()..sort();
    });
    await prefs.setString(_keyDailyHistory, jsonEncode(payload));
  }

}

