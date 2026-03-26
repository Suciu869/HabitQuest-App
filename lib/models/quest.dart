// FILE: lib/models/quest.dart
import 'package:flutter/material.dart';

class Quest {
  final String title;
  final IconData icon;
  final Color color;
  List<DateTime> completedDates;

  Quest({
    required this.title,
    required this.icon,
    this.color = Colors.amber,
    List<DateTime>? completedDates,
  }) : completedDates = completedDates ?? [];

  // --- ADAUGĂ ACEASTĂ METODĂ PENTRU A CITI DIN FIREBASE ---
  static Quest fromMap(Map<String, dynamic> map) {
    return Quest(
      title: map['title'] ?? 'Unknown Quest',
      icon: IconData(map['iconCodePoint'] ?? 58711, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] ?? Colors.amber.value),
      completedDates: (map['completedDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d as String))
          .toList() ?? [],
    );
  }

  // Metodele isCompletedOn și toggleCompleted rămân la fel...
  bool isCompletedOn(DateTime date) {
    return completedDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  void toggleCompleted(DateTime date) {
    if (isCompletedOn(date)) {
      completedDates.removeWhere((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);
    } else {
      completedDates.add(date);
    }
  }
}