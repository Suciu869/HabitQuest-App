// FILE: lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import '../models/quest.dart';

class CalendarScreen extends StatefulWidget {
  final List<Quest> quests;
  final DateTime currentDate;
  final Map<DateTime, List<String>> dailyHistory;
  final List<String> Function(DateTime date) eventLoader;

  const CalendarScreen({
    super.key,
    required this.quests,
    required this.currentDate,
    required this.dailyHistory,
    required this.eventLoader,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime selectedDate;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    selectedDate = widget.currentDate;
  }

  // Funcție ajutătoare pentru formatare dată
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showDaySummary(DateTime day) {
    final entries = widget.eventLoader(day);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quest Summary - ${_formatDate(day)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No completed quests on this day.', style: TextStyle(color: Colors.white54)),
                )
              else
                ...entries.map(
                  (title) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final colorScheme = Theme.of(context).colorScheme;

    final selectedDayEvents = widget.eventLoader(selectedDate);

    return SafeArea(
      child: Column(
        children: [
          // Antet Modern
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.history_edu, size: 40, color: colorScheme.primary),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Journey', style: Theme.of(context).textTheme.titleLarge),
                    Text('Year ${widget.currentDate.year}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  ],
                ),
              ],
            ),
          ),
          Divider(indent: 24, endIndent: 24, color: colorScheme.outlineVariant),

          // Lista Anuală
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: 12,
              itemBuilder: (context, monthIndex) {
                int currentMonth = monthIndex + 1;
                int daysInMonth = DateUtils.getDaysInMonth(widget.currentDate.year, currentMonth);
                int firstWeekday = DateTime(widget.currentDate.year, currentMonth, 1).weekday;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text(
                        monthNames[monthIndex],
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.1, // Celule puțin mai late
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: daysInMonth + (firstWeekday - 1),
                      itemBuilder: (context, dayIndex) {
                        if (dayIndex < firstWeekday - 1) return const SizedBox();

                        int dayNumber = dayIndex - (firstWeekday - 1) + 1;
                        DateTime cellDate = DateTime(widget.currentDate.year, currentMonth, dayNumber);

                        bool isSelected = _formatDate(cellDate) == _formatDate(selectedDate);
                        bool isToday = _formatDate(cellDate) == _formatDate(widget.currentDate);
                        final events = widget.eventLoader(cellDate);
                        final completedCount = events.length;

                        // Design modern pentru celula de calendar
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedDate = _dateOnly(cellDate));
                            _showDaySummary(cellDate);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              // Dacă e selectat, folosim culoarea primară, altfel o nuanță deschisă dacă e azi
                              color: isSelected ? colorScheme.primary : (isToday ? colorScheme.primaryContainer : colorScheme.surface),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : (isToday ? colorScheme.primary : colorScheme.outlineVariant),
                                width: isToday ? 2 : 1
                              ),
                              boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text('$dayNumber',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? colorScheme.onPrimary : (isToday ? colorScheme.onPrimaryContainer : colorScheme.onSurface),
                                  )
                                ),
                                if (completedCount > 0)
                                  Positioned(
                                    bottom: 6,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        completedCount > 3 ? 3 : completedCount,
                                        (i) => Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 1),
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: isSelected ? colorScheme.onPrimary : Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // Zona de detalii (Bottom Sheet style)
          Container(
            height: 200,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History for ${_formatDate(selectedDate)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: selectedDayEvents.isEmpty
                      ? Center(child: Text('No activity yet.', style: TextStyle(color: colorScheme.outline)))
                      : ListView.separated(
                          itemCount: selectedDayEvents.length,
                          separatorBuilder: (_, _) => Divider(color: colorScheme.outlineVariant),
                          itemBuilder: (context, i) {
                            return Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 12),
                                Text(selectedDayEvents[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            );
                          },
                        ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}