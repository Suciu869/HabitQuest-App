import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/quest.dart';
import '../services/quest_storage.dart';

class HeroDashboardScreen extends StatelessWidget {
  const HeroDashboardScreen({super.key});

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<({List<Quest> quests, Map<DateTime, List<String>> history})> _loadData() async {
    final storage = QuestStorage();
    final quests = await storage.loadQuests();
    final history = await storage.loadDailyHistory();
    return (quests: quests, history: history);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Quest> quests, Map<DateTime, List<String>> history})>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final quests = snapshot.data!.quests;
        final dailyHistory = snapshot.data!.history;
        if (quests.isEmpty && dailyHistory.isEmpty) {
          return const Center(
            child: Text('No data yet.', style: TextStyle(color: Colors.white54)),
          );
        }

        final end = _dateOnly(DateTime.now());
        final start = end.subtract(const Duration(days: 29));
        int completions = 0;
        for (final entry in dailyHistory.entries) {
          final day = _dateOnly(entry.key);
          if (!day.isBefore(start) && !day.isAfter(end)) {
            completions += entry.value.length;
          }
        }
        final totalPossible = (quests.length * 30).clamp(1, 999999);
        final rate = (completions / totalPossible).clamp(0.0, 1.0);

        final weekdayCounts = List<int>.filled(7, 0);
        for (final entry in dailyHistory.entries) {
          final day = _dateOnly(entry.key);
          if (!day.isBefore(start) && !day.isAfter(end)) {
            weekdayCounts[day.weekday - 1] += entry.value.length;
          }
        }

        const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final maxValue = math.max(1, weekdayCounts.reduce(math.max));
        final bestIndex = weekdayCounts.indexOf(maxValue);
        const bestDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final topQuests = [...quests]
          ..sort((a, b) => b.maxStreak.compareTo(a.maxStreak));
        final hallOfFame = topQuests.take(3).toList();

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, reveal, child) {
            return Opacity(
              opacity: reveal,
              child: Transform.translate(
                offset: Offset(0, (1 - reveal) * 26),
                child: child,
              ),
            );
          },
          child: ColoredBox(
            color: const Color(0xFF121212),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1712),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x66FFC107)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FFC107),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Hero Dashboard • Sanctuary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SanctuaryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aura Ring',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutQuart,
                          tween: Tween<double>(begin: 0, end: rate),
                          builder: (context, animatedRate, _) {
                            final rateText = '${(animatedRate * 100).round()}%';
                            return SizedBox(
                              width: 230,
                              height: 230,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(230, 230),
                                    painter: _AuraRingPainter(progress: animatedRate),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        rateText,
                                        style: const TextStyle(
                                          color: Color(0xFFFFC107),
                                          fontSize: 50,
                                          fontWeight: FontWeight.w800,
                                          shadows: [
                                            Shadow(color: Color(0xAAFFC107), blurRadius: 18),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Win Rate',
                                        style: TextStyle(color: Colors.white54, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SanctuaryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Energy Pillars',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Most Productive Day: ${bestDayNames[bestIndex]}',
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            maxY: maxValue.toDouble() * 1.2,
                            minY: 0,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xFF2A2112),
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final value = weekdayCounts[group.x.toInt()];
                                  return BarTooltipItem(
                                    '${dayLabels[group.x.toInt()]}: $value quests',
                                    const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= dayLabels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        dayLabels[index],
                                        style: TextStyle(
                                          color: index == bestIndex ? Colors.amberAccent : Colors.white54,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(7, (i) {
                              final value = weekdayCounts[i].toDouble();
                              final isBest = i == bestIndex && weekdayCounts[i] > 0;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: value,
                                    width: 22,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                    gradient: isBest
                                        ? const LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Color(0xFFFF8F00), Color(0xFFFFD54F)],
                                          )
                                        : const LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Color(0xFFEF6C00), Color(0xFFFFB300)],
                                          ),
                                    rodStackItems: isBest
                                        ? [
                                            BarChartRodStackItem(
                                              0,
                                              value,
                                              const Color(0x11FFFFFF),
                                            ),
                                          ]
                                        : [],
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SanctuaryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hall of Fame 🏆',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (hallOfFame.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Complete quests to summon your champions.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      else
                        ...hallOfFame.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final quest = entry.value;
                          return Container(
                            margin: EdgeInsets.only(bottom: idx == hallOfFame.length - 1 ? 0 : 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0x33FFC107)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              title: Text(
                                quest.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${quest.maxStreak}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SanctuaryCard extends StatelessWidget {
  final Widget child;

  const _SanctuaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF181818),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x33FFC107)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22FFC107),
              blurRadius: 18,
              spreadRadius: 0.5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _AuraRingPainter extends CustomPainter {
  final double progress;

  const _AuraRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = 16.0;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF343434);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xCCFF8F00), Color(0x99FFE082)],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFFFF8F00), Color(0xFFFFD54F)],
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
