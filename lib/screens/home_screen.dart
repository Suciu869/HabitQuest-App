// FILE: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/quest.dart';

// Acest ecran este "Stateless" (prost), primește toate datele de la "tatăl" său (MainScaffold)
class HomeScreen extends StatelessWidget {
  final List<Quest> quests;
  final int xp;
  final int targetXp;
  final int level;
  final DateTime currentDate;
  final Function(int) onComplete;
  final Function(int) onDelete;
  final VoidCallback onSimulateDay;

  const HomeScreen({
    super.key,
    required this.quests,
    required this.xp,
    required this.targetXp,
    required this.level,
    required this.currentDate,
    required this.onComplete,
    required this.onDelete,
    required this.onSimulateDay,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        // APP BAR MODERN M3 (Large)
        SliverAppBar.large(
          title: Text('Level $level'),
          actions: [
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: 'Simulate Next Day',
              onPressed: onSimulateDay,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                // Gradient modern în loc de culoare solidă
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.tertiary],
                )
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.shield_moon, size: 40, color: Colors.white),
                        Text('$xp / $targetXp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Bara de progres mai groasă și rotundă
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: xp / targetXp),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // LISTA DE QUESTURI MODERNĂ
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final quest = quests[index];
                final isCompletedToday = quest.isCompletedOn(currentDate);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: Key(quest.title),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.delete, color: colorScheme.onError),
                    ),
                    onDismissed: (direction) => onDelete(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      decoration: BoxDecoration(
                        // Cardurile sunt acum containere rotunjite cu bordură fină
                        color: isCompletedToday ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCompletedToday ? Colors.transparent : colorScheme.outlineVariant,
                          width: 1
                        ),
                        boxShadow: isCompletedToday ? [] : [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCompletedToday ? Colors.green.withOpacity(0.2) : quest.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(quest.icon, color: isCompletedToday ? Colors.green : quest.color),
                        ),
                        title: Text(quest.title,
                          style: TextStyle(
                            decoration: isCompletedToday ? TextDecoration.lineThrough : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCompletedToday ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                          )
                        ),
                        trailing: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: isCompletedToday
                            ? Icon(Icons.check_circle_rounded, color: Colors.green, size: 34, key: const ValueKey('icon'))
                            : FilledButton.tonal( // Buton modern tonal
                                key: const ValueKey('button'),
                                onPressed: () => onComplete(index),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                child: const Text('Done'),
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: quests.length,
            ),
          ),
        ),
      ],
    );
  }
}