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
import '../services/rewarded_ad_service.dart';
import '../services/quest_storage.dart';
import '../services/time_service.dart';
import '../widgets/streak_badge.dart';

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
  String currentAvatar = '🧑‍🌾'; 
  List<Quest> quests = [];
  final QuestStorage _questStorage = QuestStorage();
  final TimeService _time = TimeService();

  // --- UNELTELE FIREBASE & CONFETTI ---
  late ConfettiController _confettiController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _applyStreakAging({
    required DateTime now,
    required bool showPopup,
  }) async {
    final today = _dateOnly(now);
    bool anyBrokeNow = false;
    bool shouldNotifyUser = false;

    setState(() {
      for (final q in quests) {
        final prev = q.streak;
        q.ensureStreakUpToDate(now);
        final brokeNow = prev > 0 && q.streak == 0;
        if (brokeNow) {
          anyBrokeNow = true;
        }
        if (brokeNow && showPopup && (q.lastBreakNoticeDate == null || q.lastBreakNoticeDate != today)) {
          // Mark as notified for today so we don't spam.
          q.lastBreakNoticeDate = today;
          shouldNotifyUser = true;
        }
      }
    });

    if (anyBrokeNow) {
      await _persistAll();
      _syncNotificationsForToday();
    }

    if (!showPopup || !shouldNotifyUser || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Streak broken! Tap the 💔 badge to watch an ad and restore your streak.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

@override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadUserData(); 
    
    // --- NOU: DECLANȘĂM NOTIFICĂRILE ---
    NotificationService().init();
  }

  @override
  void dispose() {
    _confettiController.dispose(); 
    super.dispose();
  }

  // --- ÎNCĂRCARE DATE ---
  Future<void> _loadUserData() async {
    try {
      await _time.init();
      // Ensure release users are always on real time.
      await _time.reset();

      // 1) Load local cache immediately (so restart doesn't "lose" state even offline).
      final cachedQuests = await _questStorage.loadQuests();
      final cachedLastActive = await _questStorage.loadLastActiveDate();
      if (cachedQuests.isNotEmpty) {
        setState(() {
          quests = cachedQuests;
          currentDate = DateTime(_time.now().year, _time.now().month, _time.now().day);
        });
      }

      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final lastActiveRaw = data['lastActiveDate'] as String?;
        final lastActive = lastActiveRaw == null ? cachedLastActive : DateTime.tryParse(lastActiveRaw);
        final today = _time.now();
        final todayDateOnly = DateTime(today.year, today.month, today.day);
        final lastActiveDateOnly = lastActive == null ? null : DateTime(lastActive.year, lastActive.month, lastActive.day);

        setState(() {
          level = data['level'] ?? 1;
          xp = data['xp'] ?? 0;
          targetXp = data['targetXp'] ?? 100;
          currentAvatar = data['avatar'] ?? '🧑‍🌾'; 
          currentDate = todayDateOnly;
          
          if (data['quests'] != null) {
            quests = (data['quests'] as List)
                .map((q) => Quest.fromMap(q as Map<String, dynamic>))
                .toList();
          }

          // Keep streak correct vs 36h rule on startup.
          for (final q in quests) {
            q.ensureStreakUpToDate(today);
          }
        });

        // 2) Day transition logic: we don't erase history; UI simply checks for today via `isCompletedOn`.
        // Persist "lastActiveDate" so day comparisons are robust.
        await _persistLastActiveDate(todayDateOnly);
        await _questStorage.saveQuests(quests);
        // If a streak just broke while the app was closed, notify once on startup.
        await _applyStreakAging(now: today, showPopup: true);

        // If it's a new day, we intentionally do NOT remove any history.
        // "Today" is naturally unchecked unless a completion exists for today.
        if (lastActiveDateOnly == null || lastActiveDateOnly != todayDateOnly) {
          // New day: nothing else required for history; streak/broken is derived from history.
        }
        _syncNotificationsForToday();
      } else {
        await _saveUserData();
        await _persistLastActiveDate(_time.now());
        _syncNotificationsForToday();
      }
    } catch (e) {
      print("Error downloading data: $e");
    }
  }

  void _syncNotificationsForToday() {
    final total = quests.length;
    final completed = quests.where((q) => q.isCompletedOn(currentDate)).length;
    NotificationService().syncDailyNotifications(
      totalQuests: total,
      completedToday: completed,
    );
  }

  Future<void> _saveUserData() async {
    await _firestore.collection('users').doc(userId).set({
      'level': level,
      'xp': xp,
      'targetXp': targetXp,
      'avatar': currentAvatar,
    }, SetOptions(merge: true));
  }

  Future<void> _saveQuestsToFirestore() async {
    List<Map<String, dynamic>> questData = quests.map((q) => q.toMap()).toList();

    await _firestore.collection('users').doc(userId).set({
      'quests': questData,
    }, SetOptions(merge: true));
  }

  Future<void> _persistLastActiveDate(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    await _firestore.collection('users').doc(userId).set({
      'lastActiveDate': d.toIso8601String(),
    }, SetOptions(merge: true));
    await _questStorage.saveLastActiveDate(d);
  }

  Future<void> _persistAll() async {
    // Local-first ensures persistence even if Firestore write is delayed.
    await _questStorage.saveQuests(quests);
    await _saveUserData();
    await _saveQuestsToFirestore();
    await _persistLastActiveDate(_time.now());
  }

  Future<void> deleteQuest(int index) async {
    final deletedQuest = quests[index]; 
    setState(() {
      quests.removeAt(index);
    });
    await _persistAll();
    _syncNotificationsForToday();

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
  Future<void> completeQuest(int index) async {
    final now = _time.now();
    final today = DateTime(now.year, now.month, now.day);
    currentDate = today;
    bool wasAlreadyDone = quests[index].isCompletedOn(today);

    setState(() {
      // Uses 36h grace logic via lastCompletedAt/streak persistence.
      quests[index].toggleCompletedAt(now);

      if (!wasAlreadyDone && quests[index].isCompletedOn(today)) {
        xp += 25;
      } 
      else if (wasAlreadyDone && !quests[index].isCompletedOn(today)) {
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
    
    await _persistAll();
    _syncNotificationsForToday();
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
  Future<void> _openAddQuestSheet() async {
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
      await _persistAll();
      _syncNotificationsForToday();
    }
  }

  Future<void> _showStreakRecoveryDialog(int questIndex) async {
    final quest = quests[questIndex];
    final themeBg = Colors.grey.shade900;

    final restored = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        bool loading = false;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: themeBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0x33FF6A00), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Icon(Icons.ac_unit, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your streak is dying! ❄️',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You missed yesterday. Watch a rewarded ad to restore your streak and reignite your fire.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: loading
                                ? null
                                : () async {
                                    setLocalState(() => loading = true);
                                    final ok = await RewardedAdService().showRewardedAdForStreakRestore();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(ok);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A1A12),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Color(0x55FF6A00)),
                            ),
                            icon: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6A00)),
                                  )
                                : const Icon(Icons.play_circle_fill, color: Color(0xFFFF6A00)),
                            label: Text(loading ? 'Opening ad…' : 'Watch Ad to Restore Streak'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: loading ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Not now', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (restored != true) return;

    setState(() {
      // Restore the streak value that existed before the 36h break.
      quest.restoreStreakAfterAd(_time.now());
    });
    await _persistAll();
    _syncNotificationsForToday();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Streak restored! Your fire burns again.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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
                      final now = _time.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final isDone = quest.isCompletedOn(today);
                      final streak = quest.currentStreak(today);
                      final isBroken = quest.isStreakBroken(now);
                      final isGrace = !isDone && !isBroken && quest.isInWarningWindow(now);
                      final badgeState = isBroken
                          ? StreakBadgeState.broken
                          : isDone
                              ? StreakBadgeState.validated
                              : isGrace
                                  ? StreakBadgeState.grace
                                  : StreakBadgeState.waiting;

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
                            leading: StreakBadge(
                              streak: streak,
                              state: badgeState,
                              onTapBroken: () => _showStreakRecoveryDialog(index),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDone ? Colors.amber.withOpacity(0.2) : const Color(0xFF2A2A2A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(quest.icon, color: isDone ? Colors.amber : Colors.white70),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    quest.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isDone ? Colors.white54 : Colors.white,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ],
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
          ),
          
          body: SafeArea(
            bottom: true,
            child: _currentIndex == 0
                ? homeContent
                : _currentIndex == 1
                    ? CalendarScreen(quests: quests, currentDate: currentDate)
                    : ProfileScreen(
                        level: level,
                        currentAvatar: currentAvatar,
                        onAvatarChanged: (newAvatar) {
                          setState(() {
                            currentAvatar = newAvatar;
                          });
                          _saveUserData();
                        },
                      ),
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