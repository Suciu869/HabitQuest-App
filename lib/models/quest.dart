// FILE: lib/models/quest.dart
import 'package:flutter/material.dart';

class Quest {
  final String title;
  final IconData icon;
  final Color color;
  List<DateTime> completedDates;
  int streak;
  DateTime? lastCompletedAt;
  int frozenStreak;
  DateTime? lastStreakAwardedDate;
  DateTime? lastBreakNoticeDate;

  Quest({
    required this.title,
    required this.icon,
    this.color = Colors.amber,
    List<DateTime>? completedDates,
    int? streak,
    DateTime? lastCompletedAt,
    int? frozenStreak,
    DateTime? lastStreakAwardedDate,
    DateTime? lastBreakNoticeDate,
  })  : completedDates = completedDates ?? [],
        streak = streak ?? 0,
        lastCompletedAt = lastCompletedAt,
        frozenStreak = frozenStreak ?? 0,
        lastStreakAwardedDate = lastStreakAwardedDate,
        lastBreakNoticeDate = lastBreakNoticeDate;

  // --- ADAUGĂ ACEASTĂ METODĂ PENTRU A CITI DIN FIREBASE ---
  static Quest fromMap(Map<String, dynamic> map) {
    final lastCompletedRaw = map['lastCompletedAt'] as String?;
    final lastCompleted = lastCompletedRaw == null ? null : DateTime.tryParse(lastCompletedRaw);
    final lastAwardedRaw = map['lastStreakAwardedDate'] as String?;
    final lastAwarded = lastAwardedRaw == null ? null : DateTime.tryParse(lastAwardedRaw);
    final lastNoticeRaw = map['lastBreakNoticeDate'] as String?;
    final lastNotice = lastNoticeRaw == null ? null : DateTime.tryParse(lastNoticeRaw);
    return Quest(
      title: map['title'] ?? 'Unknown Quest',
      icon: IconData(map['iconCodePoint'] ?? 58711, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] ?? Colors.amber.value),
      completedDates: (map['completedDates'] as List<dynamic>?)
          ?.map((d) {
            final parsed = DateTime.parse(d as String);
            return _dateOnly(parsed);
          })
          .toList() ?? [],
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      lastCompletedAt: lastCompleted,
      frozenStreak: (map['frozenStreak'] as num?)?.toInt() ?? 0,
      lastStreakAwardedDate: lastAwarded == null ? null : _dateOnly(lastAwarded),
      lastBreakNoticeDate: lastNotice == null ? null : _dateOnly(lastNotice),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
      'completedDates': completedDates
          .map((d) => _dateOnly(d).toIso8601String())
          .toSet()
          .toList()
        ..sort(),
      'streak': streak,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'frozenStreak': frozenStreak,
      'lastStreakAwardedDate': lastStreakAwardedDate == null ? null : _dateOnly(lastStreakAwardedDate!).toIso8601String(),
      'lastBreakNoticeDate': lastBreakNoticeDate == null ? null : _dateOnly(lastBreakNoticeDate!).toIso8601String(),
    };
  }

  // Metodele isCompletedOn și toggleCompleted rămân la fel...
  bool isCompletedOn(DateTime date) {
    final target = _dateOnly(date);
    return completedDates.any((d) => _dateOnly(d) == target);
  }

  void toggleCompleted(DateTime date) {
    // Backwards-compatible toggle (date-only). Prefer `toggleCompletedAt(now)` for streak logic.
    toggleCompletedAt(DateTime(date.year, date.month, date.day, 12));
  }

  void toggleCompletedAt(DateTime now) {
    final today = _dateOnly(now);
    final wasDoneToday = isCompletedOn(today);

    if (wasDoneToday) {
      completedDates.removeWhere((d) => _dateOnly(d) == today);
      // If user unchecks "today" and that was the last completion, fall back to the latest completed day.
      if (lastCompletedAt != null && _dateOnly(lastCompletedAt!) == today) {
        final lastDay = completedDates.isEmpty
            ? null
            : (completedDates..sort()).last;
        lastCompletedAt = lastDay == null
            ? null
            : DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59);
      }
      // Streak becomes derived from lastCompletedAt window; keep current streak as-is for now.
      return;
    }

    // Mark complete for "today" and update streak with 36h grace.
    completedDates.add(today);
    completedDates = completedDates.map(_dateOnly).toSet().toList()..sort();

    if (lastCompletedAt == null) {
      streak = 1;
      lastCompletedAt = now;
      lastStreakAwardedDate = today;
      frozenStreak = 0;
      return;
    }

    final delta = now.difference(lastCompletedAt!);
    final lastDay = _dateOnly(lastCompletedAt!);

    if (today == lastDay) {
      // Same day completion (e.g. re-adding) shouldn't increment.
      lastCompletedAt = now;
      if (streak <= 0) streak = 1;
      return;
    }

    // IMPORTANT: prevent farming streak by unchecking/rechecking in the same day.
    final alreadyAwardedToday = lastStreakAwardedDate != null && _dateOnly(lastStreakAwardedDate!) == today;

    if (delta <= const Duration(hours: 36)) {
      // Grace window: keep and add to streak (max once per day).
      if (!alreadyAwardedToday) {
        streak = (streak <= 0) ? 1 : (streak + 1);
        lastStreakAwardedDate = today;
      }
    } else {
      // Too late: streak resets.
      streak = 1;
      lastStreakAwardedDate = today;
    }

    lastCompletedAt = now;
    frozenStreak = 0;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool hasCompletedBefore(DateTime date) {
    final cut = _dateOnly(date);
    return completedDates.any((d) => _dateOnly(d).isBefore(cut));
  }

  int currentStreak(DateTime today) {
    // Prefer persisted streak; it’s updated with 36h grace on completion.
    return streak;
  }

  bool isStreakBroken(DateTime today) {
    final now = today;
    if (lastCompletedAt == null) return false;
    return now.difference(lastCompletedAt!) >= const Duration(hours: 36);
  }

  bool isInWarningWindow(DateTime now) {
    if (lastCompletedAt == null) return false;
    final delta = now.difference(lastCompletedAt!);
    return delta >= const Duration(hours: 24) && delta < const Duration(hours: 36);
  }

  void ensureStreakUpToDate(DateTime now) {
    if (lastCompletedAt == null) return;
    if (now.difference(lastCompletedAt!) >= const Duration(hours: 36)) {
      if (streak > 0 && frozenStreak == 0) {
        frozenStreak = streak;
      }
      streak = 0;
    }
  }

  bool restoreStreakAfterAd(DateTime now) {
    if (frozenStreak <= 0) return false;
    // Bring back the streak value that existed before breaking.
    streak = frozenStreak;
    frozenStreak = 0;
    // Reset the timer window so it's not immediately "broken" again.
    lastCompletedAt = now;
    // Prevent extra +1 farming for the same day after restore.
    lastStreakAwardedDate = _dateOnly(now);
    // Allow break popups again in the future.
    lastBreakNoticeDate = null;
    return true;
  }

  bool restoreYesterdayIfMissed(DateTime today) {
    final t = _dateOnly(today);
    final yesterday = t.subtract(const Duration(days: 1));
    if (isCompletedOn(yesterday)) return false;
    completedDates.add(yesterday);
    completedDates = completedDates.map(_dateOnly).toSet().toList()..sort();
    return true;
  }
}