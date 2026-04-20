// FILE: lib/models/quest.dart
import 'package:flutter/material.dart';

enum QuestStreakState { active, safe, broken }
enum QuestType { standard, progressive, negative }

class Quest {
  final String title;
  final IconData icon;
  final Color color;
  QuestType type;
  List<DateTime> completedDates;
  bool isCompletedToday;
  int streakCount;
  int maxStreak;
  int targetValue;
  int currentProgress;
  DateTime? lastCompletedDate;
  int recoveryStreakValue;
  DateTime? lastBreakNoticeDate;

  Quest({
    required this.title,
    required this.icon,
    this.color = Colors.amber,
    this.type = QuestType.standard,
    List<DateTime>? completedDates,
    bool? isCompletedToday,
    int? streakCount,
    int? maxStreak,
    int? targetValue,
    int? currentProgress,
    DateTime? lastCompletedDate,
    int? recoveryStreakValue,
    DateTime? lastBreakNoticeDate,
  })  : completedDates = completedDates ?? [],
        isCompletedToday = isCompletedToday ?? false,
        streakCount = streakCount ?? 0,
        maxStreak = maxStreak ?? 0,
        targetValue = (targetValue ?? 1) <= 0 ? 1 : (targetValue ?? 1),
        currentProgress = currentProgress ?? 0,
        lastCompletedDate = lastCompletedDate == null ? null : _dateOnly(lastCompletedDate),
        recoveryStreakValue = recoveryStreakValue ?? 0,
        lastBreakNoticeDate = lastBreakNoticeDate;

  static Quest fromMap(Map<String, dynamic> map) {
    final lastCompletedRaw = (map['lastCompletedDate'] ?? map['lastCompletedAt']) as String?;
    final parsedLastCompleted = lastCompletedRaw == null ? null : DateTime.tryParse(lastCompletedRaw);
    final lastCompleted = parsedLastCompleted == null ? null : _dateOnly(parsedLastCompleted);
    final lastNoticeRaw = map['lastBreakNoticeDate'] as String?;
    final parsedLastNotice = lastNoticeRaw == null ? null : DateTime.tryParse(lastNoticeRaw);
    final lastNotice = parsedLastNotice == null ? null : _dateOnly(parsedLastNotice);
    return Quest(
      title: map['title'] ?? 'Unknown Quest',
      icon: IconData(map['iconCodePoint'] ?? 58711, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] ?? Colors.amber.value),
      type: QuestType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'standard'),
        orElse: () => QuestType.standard,
      ),
      completedDates: (map['completedDates'] as List<dynamic>?)
          ?.map((d) {
            final parsed = DateTime.parse(d as String);
            return _dateOnly(parsed);
          })
          .toList() ?? [],
      isCompletedToday: map['isCompletedToday'] == true,
      streakCount: (map['streakCount'] as num?)?.toInt() ?? (map['streak'] as num?)?.toInt() ?? 0,
      maxStreak: (map['maxStreak'] as num?)?.toInt() ?? 0,
      targetValue: (map['targetValue'] as num?)?.toInt() ?? 1,
      currentProgress: (map['currentProgress'] as num?)?.toInt() ?? 0,
      lastCompletedDate: lastCompleted,
      recoveryStreakValue:
          (map['recoveryStreakValue'] as num?)?.toInt() ??
          (map['previousStreakCount'] as num?)?.toInt() ?? (map['frozenStreak'] as num?)?.toInt() ?? 0,
      lastBreakNoticeDate: lastNotice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
      'type': type.name,
      'completedDates': completedDates
          .map((d) => _dateOnly(d).toIso8601String())
          .toSet()
          .toList()
        ..sort(),
      'isCompletedToday': isCompletedToday,
      'streakCount': streakCount,
      'maxStreak': maxStreak,
      'targetValue': targetValue,
      'currentProgress': currentProgress,
      'streak': streakCount,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'lastCompletedAt': lastCompletedDate?.toIso8601String(),
      'recoveryStreakValue': recoveryStreakValue,
      'previousStreakCount': recoveryStreakValue,
      'frozenStreak': recoveryStreakValue,
      'lastBreakNoticeDate': lastBreakNoticeDate == null ? null : _dateOnly(lastBreakNoticeDate!).toIso8601String(),
    };
  }

  bool isCompletedOn(DateTime date) {
    final target = _dateOnly(date);
    if (target == _dateOnly(DateTime.now())) {
      return isCompletedToday;
    }
    if (lastCompletedDate == target) {
      return isCompletedToday;
    }
    return completedDates.any((d) => _dateOnly(d) == target);
  }

  bool isCheckedToday(DateTime today) {
    return isCompletedToday && lastCompletedDate == _dateOnly(today);
  }

  void toggleCompleted(DateTime date) {
    toggleCompletedAt(DateTime(date.year, date.month, date.day, 12));
  }

  void toggleCompletedAt(DateTime now) {
    if (type == QuestType.negative) return;
    final today = _dateOnly(now);
    if (isCompletedToday) {
      isCompletedToday = false;
      if (streakCount > 0) {
        streakCount -= 1;
      }
      if (streakCount <= 0) {
        streakCount = 0;
        lastCompletedDate = null;
      } else {
        lastCompletedDate = today.subtract(const Duration(days: 1));
      }
      completedDates.removeWhere((d) => _dateOnly(d) == today);
      if (type == QuestType.progressive) {
        currentProgress = (targetValue - 1).clamp(0, targetValue);
      }
      return;
    }

    if (type == QuestType.progressive && currentProgress < targetValue) {
      return;
    }
    isCompletedToday = true;
    completedDates.add(today);
    completedDates = completedDates.map(_dateOnly).toSet().toList()..sort();
    streakCount += 1;
    lastCompletedDate = today;
    recoveryStreakValue = 0;
    lastBreakNoticeDate = null;
    if (streakCount > maxStreak) {
      maxStreak = streakCount;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool hasCompletedBefore(DateTime date) {
    final cut = _dateOnly(date);
    return completedDates.any((d) => _dateOnly(d).isBefore(cut));
  }

  int currentStreak(DateTime today) {
    return streakCount;
  }

  QuestStreakState streakState(DateTime date) {
    if (lastCompletedDate == null) return QuestStreakState.broken;
    final today = _dateOnly(date);
    final yesterday = today.subtract(const Duration(days: 1));
    if (lastCompletedDate == today && isCompletedToday) return QuestStreakState.active;
    if (lastCompletedDate == yesterday) return QuestStreakState.safe;
    return QuestStreakState.broken;
  }

  bool isStreakBroken(DateTime date) => streakState(date) == QuestStreakState.broken;

  // REGULA 5: curata checkbox-ul la zi noua fara penalizare de streak.
  bool checkDailyReset(DateTime now) {
    final today = _dateOnly(now);
    if (type == QuestType.negative) {
      return _checkNegativeDaily(today);
    }
    if (lastCompletedDate == null) {
      isCompletedToday = false;
      if (type == QuestType.progressive) currentProgress = 0;
      return false;
    }

    final dayDiff = today.difference(lastCompletedDate!).inDays;
    if (dayDiff <= 0) {
      return false;
    }

    isCompletedToday = false;
    if (type == QuestType.progressive) currentProgress = 0;

    if (dayDiff >= 2) {
      if (streakCount > 0 && recoveryStreakValue <= 0) {
        recoveryStreakValue = streakCount;
      }
      streakCount = 0;
      return true;
    }
    return false;
  }

  bool runDailyCheck(DateTime now) => checkDailyReset(now);

  bool restoreStreakAfterAd(DateTime now) {
    if (recoveryStreakValue <= 0) return false;
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    streakCount = recoveryStreakValue;
    recoveryStreakValue = 0;
    lastCompletedDate = yesterday;
    isCompletedToday = false;
    if (!isCompletedOn(yesterday)) {
      completedDates.add(yesterday);
      completedDates = completedDates.map(_dateOnly).toSet().toList()..sort();
    }
    if (type == QuestType.progressive) {
      currentProgress = 0;
    }
    lastBreakNoticeDate = null;
    return true;
  }

  int streakBadgeValue(DateTime today) {
    return streakState(today) == QuestStreakState.broken ? recoveryStreakValue : streakCount;
  }

  bool incrementProgress(DateTime now) {
    if (type != QuestType.progressive) return false;
    if (isCompletedToday) return false;
    if (currentProgress < targetValue) {
      currentProgress += 1;
    }
    if (currentProgress >= targetValue) {
      currentProgress = targetValue;
      toggleCompletedAt(now);
      return true;
    }
    return false;
  }

  bool failNegativeToday(DateTime now) {
    if (type != QuestType.negative) return false;
    final today = _dateOnly(now);
    isCompletedToday = false;
    if (streakCount > 0 && recoveryStreakValue <= 0) {
      recoveryStreakValue = streakCount;
    }
    streakCount = 0;
    currentProgress = 0;
    lastCompletedDate = today.subtract(const Duration(days: 2));
    completedDates.removeWhere((d) => _dateOnly(d) == today);
    return true;
  }

  bool _checkNegativeDaily(DateTime today) {
    if (lastCompletedDate == null) {
      isCompletedToday = true;
      streakCount = streakCount <= 0 ? 1 : streakCount;
      lastCompletedDate = today;
      if (streakCount > maxStreak) maxStreak = streakCount;
      return false;
    }

    final dayDiff = today.difference(lastCompletedDate!).inDays;
    if (dayDiff <= 0) return false;

    if (dayDiff == 1 && isCompletedToday) {
      streakCount += 1;
      if (streakCount > maxStreak) maxStreak = streakCount;
      lastCompletedDate = today;
      isCompletedToday = true;
      completedDates.add(today);
      completedDates = completedDates.map(_dateOnly).toSet().toList()..sort();
      return false;
    }

    if (dayDiff >= 1 && !isCompletedToday) {
      if (streakCount > 0 && recoveryStreakValue <= 0) {
        recoveryStreakValue = streakCount;
      }
      streakCount = 0;
      return true;
    }

    if (dayDiff >= 2) {
      if (streakCount > 0 && recoveryStreakValue <= 0) {
        recoveryStreakValue = streakCount;
      }
      streakCount = 0;
      isCompletedToday = false;
      return true;
    }
    return false;
  }
}