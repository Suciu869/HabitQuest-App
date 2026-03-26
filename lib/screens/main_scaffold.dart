// FILE: lib/screens/main_scaffold.dart
import 'package:flutter/material.dart';
import '../models/quest.dart';
import 'calendar_screen.dart';
import 'add_quest_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'package:confetti/confetti.dart';
import '../services/notification_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  
  // Variabilele jocului
  int level = 1;
  int xp = 0;
  int targetXp = 100;
  DateTime currentDate = DateTime.now();
  bool _isLoadingData = true; 
  String currentAvatar = '🧑‍🌾'; 
  List<Quest> quests = [];

  // --- UNELTELE FIREBASE & CONFETTI ---
  late ConfettiController _confettiController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

@override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadUserData(); 
    
    // --- NOU: DECLANȘĂM NOTIFICĂRILE ---
    NotificationService().requestPermission(); // Îi cere voie să trimită notificări
    NotificationService().scheduleDailyNotification(); // Setează alarma la ora 20:00
  }

  @override
  void dispose() {
    _confettiController.dispose(); 
    super.dispose();
  }

  // --- ÎNCĂRCARE DATE ---
  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          level = data['level'] ?? 1;
          xp = data['xp'] ?? 0;
          targetXp = data['targetXp'] ?? 100;
          currentAvatar = data['avatar'] ?? '🧑‍🌾'; 
          
          if (data['quests'] != null) {
            quests = (data['quests'] as List)
                .map((q) => Quest.fromMap(q as Map<String, dynamic>))
                .toList();
          }
          _isLoadingData = false;
        });
      } else {
        await _saveUserData();
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      print("Error downloading data: $e");
      setState(() => _isLoadingData = false);
    }
  }

  // --- SALVARE DATE USER ---
  Future<void> _saveUserData() async {
    await _firestore.collection('users').doc(userId).set({
      'level': level,
      'xp': xp,
      'targetXp': targetXp,
      'avatar': currentAvatar,
    }, SetOptions(merge: true));
  }

  // --- SALVARE QUESTURI ---
  Future<void> _saveQuestsToFirestore() async {
    List<Map<String, dynamic>> questData = quests.map((q) => {
      'title': q.title,
      'iconCodePoint': q.icon.codePoint,
      'completedDates': q.completedDates.map((d) => d.toIso8601String()).toList(),
    }).toList();

    await _firestore.collection('users').doc(userId).set({
      'quests': questData,
    }, SetOptions(merge: true));
  }

  // --- ȘTERGERE QUEST ---
  void deleteQuest(int index) {
    final deletedQuest = quests[index]; 
    setState(() {
      quests.removeAt(index);
    });
    _saveQuestsToFirestore();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Quest '${deletedQuest.title}' deleted!"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- LOGICA DE XP / BIFĂ ---
  void completeQuest(int index) {
    bool wasAlreadyDone = quests[index].isCompletedOn(currentDate);

    setState(() {
      quests[index].toggleCompleted(currentDate);

      if (!wasAlreadyDone && quests[index].isCompletedOn(currentDate)) {
        xp += 25;
      } 
      else if (wasAlreadyDone && !quests[index].isCompletedOn(currentDate)) {
        xp -= 25;
        if (xp < 0) xp = 0; 
      }

      // Logică Level Up 
      // Logică Level Up 
      if (xp >= targetXp) {
        level++;
        xp = xp - targetXp;
        targetXp = (targetXp * 1.5).toInt();
        
        // DECLANȘEAZĂ ANIMAȚIA!
        _confettiController.play(); 

        // --- NOU: VERIFICĂM DACĂ AM DEBLOCAT UN AVATAR ---
        String unlockedAvatarMsg = "";
        // Căutăm în lista de avatare din ProfileScreen dacă vreunul corespunde cu noul nivel
        for (var avatar in ProfileScreen.avatars) {
          if (avatar['level'] == level) {
            unlockedAvatarMsg = "\n🔓 New Avatar Unlocked: ${avatar['emoji']} ${avatar['name']}!";
            break; // Am găsit avatarul, ne oprim din căutat
          }
        }
        
        // Afișăm mesajul de victorie (cu sau fără avatar nou)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Level Up! You are now Level $level$unlockedAvatarMsg', // Adăugăm mesajul surpriză aici
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4), // Am pus 4 secunde ca să aibă timp să citească
          ),
        );
      }
    });
    
    _saveUserData();
    _saveQuestsToFirestore();
  }

  // --- SIMULARE ZI URMĂTOARE ---
  // void simulateNextDay() {
  //   setState(() {
  //     currentDate = currentDate.add(const Duration(days: 1));
  //   });
  //   _saveUserData();
    
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Time travel successful! Current date: ${currentDate.day}/${currentDate.month}'),
  //       backgroundColor: Colors.blueGrey,
  //       duration: const Duration(seconds: 1),
  //     ),
  //   );
  // }

  // --- ADĂUGARE QUEST ---
  void _openAddQuestSheet() async {
    final newQuest = await showModalBottomSheet<Quest>(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const AddQuestScreen(),
    );

    if (newQuest != null) {
      setState(() {
        quests.add(newQuest);
      });
      _saveQuestsToFirestore();
    }
  }

  // --- INTERFAȚA VIZUALĂ (BUILD) ---
  @override
  Widget build(BuildContext context) {
    double xpProgress = targetXp == 0 ? 0 : (xp / targetXp); 

    final homeContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level $level', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Icon(Icons.shield, color: Colors.amber, size: 32),
                  ],
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: LinearProgressIndicator(value: xpProgress, minHeight: 8, backgroundColor: Colors.black45, color: Colors.amber),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('$xp / $targetXp XP', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text('TODAY\'S QUESTS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white54)),
          const SizedBox(height: 15),
          Expanded(
            child: quests.isEmpty
                ? const Center(
                    child: Text('No quests yet.\nTap + to begin your journey.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 16)),
                  )
                : ListView.separated(
                    itemCount: quests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final quest = quests[index];
                      final isDone = quest.isCompletedOn(currentDate);

                      return Dismissible(
                        key: Key('${quest.title}_$index'), 
                        direction: DismissDirection.endToStart, 
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete, color: Colors.white, size: 30),
                        ),
                        onDismissed: (direction) => deleteQuest(index),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: isDone ? Colors.amber.withOpacity(0.2) : const Color(0xFF2A2A2A), shape: BoxShape.circle),
                              child: Icon(quest.icon, color: isDone ? Colors.amber : Colors.white70),
                            ),
                            title: Text(
                              quest.title,
                              style: TextStyle(fontSize: 18, color: isDone ? Colors.white54 : Colors.white, decoration: isDone ? TextDecoration.lineThrough : null),
                            ),
                            trailing: IconButton(
                              icon: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.amber : Colors.white38, size: 28),
                              onPressed: () => completeQuest(index),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    // Îmbrăcăm totul într-un Stack pentru confetti
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.amber.withOpacity(0.2),
                child: Text(currentAvatar, style: const TextStyle(fontSize: 22)),
              ),
            ),
            title: const Text('HABIT QUEST'),
            // actions: [
            //   IconButton(
            //     icon: const Icon(Icons.fast_forward, size: 24, color: Colors.white54),
            //     onPressed: simulateNextDay,
            //     tooltip: 'Simulate Next Day',
            //   ),
            // ],
          ),
          
          body: _currentIndex == 0 
              ? homeContent 
              : _currentIndex == 1 
                  ? CalendarScreen(quests: quests, currentDate: currentDate)
                  : ProfileScreen(
                      level: level,
                      currentAvatar: currentAvatar,
                      onAvatarChanged: (newAvatar) {
                        setState(() { currentAvatar = newAvatar; });
                        _saveUserData(); 
                      },
                    ), 
                  
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() { _currentIndex = index; });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
          
          floatingActionButton: _currentIndex == 0 
              ? FloatingActionButton(
                  onPressed: _openAddQuestSheet,
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
        ), // Aici se termină corect Scaffold-ul

        // Confetti-ul stă frumos deasupra a tot!
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive, 
            shouldLoop: false,
            colors: const [Colors.amber, Colors.orange, Colors.yellow, Colors.white], 
            gravity: 0.2, 
            numberOfParticles: 50, 
          ),
        ),
      ],
    ); // Aici se termină Stack-ul
  }
}