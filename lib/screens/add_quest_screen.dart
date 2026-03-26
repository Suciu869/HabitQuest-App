// FILE: lib/screens/add_quest_screen.dart
import 'package:flutter/material.dart';
import '../models/quest.dart'; // Importăm modelul nostru

class AddQuestScreen extends StatefulWidget {
  const AddQuestScreen({super.key});

  @override
  State<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends State<AddQuestScreen> {
  final TextEditingController _titleController = TextEditingController();

  void _saveQuest() {
    if (_titleController.text.trim().isEmpty) return;

    // Creăm un obiect Quest adevărat
    final newQuest = Quest(
      title: _titleController.text.trim(),
      icon: Icons.rocket_launch, // O iconiță mai modernă
      color: Theme.of(context).colorScheme.primary, // Folosim culoarea temei
    );

    Navigator.pop(context, newQuest);
  }

  @override
  Widget build(BuildContext context) {
    // Design modern: Folosim un container cu colțuri rotunjite sus
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      child: Padding(
        // Folosim padding dinamic pentru tastatură
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ocupă doar spațiul necesar (bun pentru modal bottom sheet)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Habit Goal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'What do you want to achieve?',
                hintText: 'e.g., Read 15 mins',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon( // Buton modern M3
                onPressed: _saveQuest,
                icon: const Icon(Icons.add_task),
                label: const Text('Create Quest', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}