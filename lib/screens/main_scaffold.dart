// FILE: lib/screens/main_scaffold.dart
import 'package:flutter/material.dart';
import '../models/quest.dart';
import 'calendar_screen.dart';
import 'add_quest_screen.dart';
import 'hero_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'package:confetti/confetti.dart';
import '../services/notification_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/quest_storage.dart';
import '../services/time_service.dart';
import '../services/user_profile_controller.dart';
import '../widgets/streak_badge.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;
  
  // Variabilele jocului
  int level = 1;
  int xp = 0;
  int gold = 0;
  int targetXp = 100;
  DateTime currentDate = DateTime.now();
  String currentAvatar = '🧑‍🌾'; 
  List<Quest> quests = [];
  final QuestStorage _questStorage = QuestStorage();
  final TimeService _time = TimeService();
  final UserProfileController _userProfileController = UserProfileController();
  Map<DateTime, List<String>> dailyHistory = {};

  // --- UNELTELE FIREBASE & CONFETTI ---
  late ConfettiController _confettiController;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _syncStatsFromProfile() {
    level = _userProfileController.profile.level;
    xp = _userProfileController.profile.currentXP;
    gold = _userProfileController.profile.gold;
    targetXp = _userProfileController.getRequiredXpForNextLevel(level);
  }

  List<String> _eventLoader(DateTime date) {
    return List<String>.from(dailyHistory[_dateOnly(date)] ?? const []);
  }

  Map<DateTime, List<String>> _buildHistoryFromQuests(List<Quest> source) {
    final history = <DateTime, List<String>>{};
    for (final quest in source) {
      for (final date in quest.completedDates) {
        final key = _dateOnly(date);
        final list = history[key] ?? <String>[];
        if (!list.contains(quest.title)) list.add(quest.title);
        history[key] = list;
      }
    }
    return history;
  }

  Future<void> verifyDailyReset({
    required DateTime now,
    required bool showPopup,
  }) async {
    final today = _dateOnly(now);
    final List<Quest> brokenNow = [];
    bool shouldNotifyUser = false;

    setState(() {
      for (final q in quests) {
        final brokeNow = q.checkDailyReset(today);
        if (brokeNow) {
          brokenNow.add(q);
        }
        if (brokeNow && showPopup && (q.lastBreakNoticeDate == null || q.lastBreakNoticeDate != today)) {
          q.lastBreakNoticeDate = today;
          shouldNotifyUser = true;
        }
      }
    });

    if (brokenNow.isNotEmpty) {
      await _persistAll();
      for (final brokenQuest in brokenNow) {
        await NotificationService().showStreakFrozenNotification(questTitle: brokenQuest.title);
      }
      _syncNotificationsForToday();
    }

    if (!showPopup || !shouldNotifyUser || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your streak is frozen! Tap TAP TO RESCUE to watch an ad and restore progress.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

@override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadUserData(); 
    
    // --- NOU: DECLANȘĂM NOTIFICĂRILE ---
    NotificationService().init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose(); 
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runDailyResetCheckOnResume();
    }
  }

  Future<void> _runDailyResetCheckOnResume() async {
    if (!mounted || quests.isEmpty) return;
    await verifyDailyReset(now: _time.now(), showPopup: true);
  }

  // --- ÎNCĂRCARE DATE ---
  Future<void> _loadUserData() async {
    try {
      await _time.init();
      // Ensure release users are always on real time.
      await _time.reset();
      await _userProfileController.load();
      _syncStatsFromProfile();

      // 1) Load local cache immediately (so restart doesn't "lose" state even offline).
      final cachedQuests = await _questStorage.loadQuests();
      final cachedLastActive = await _questStorage.loadLastActiveDate();
      final cachedHistory = await _questStorage.loadDailyHistory();
      if (cachedQuests.isNotEmpty) {
        final historySeed = cachedHistory.isEmpty ? _buildHistoryFromQuests(cachedQuests) : cachedHistory;
        setState(() {
          quests = cachedQuests;
          dailyHistory = historySeed;
          currentDate = DateTime(_time.now().year, _time.now().month, _time.now().day);
        });
        await verifyDailyReset(now: _time.now(), showPopup: false);
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
          final remoteLevel = (data['level'] as num?)?.toInt();
          final remoteXp = (data['xp'] as num?)?.toInt();
          final remoteGold = (data['gold'] as num?)?.toInt();
          if (remoteLevel != null) _userProfileController.profile.level = remoteLevel;
          if (remoteXp != null) _userProfileController.profile.currentXP = remoteXp;
          if (remoteGold != null) _userProfileController.profile.gold = remoteGold;
          _syncStatsFromProfile();
          currentAvatar = data['avatar'] ?? '🧑‍🌾'; 
          currentDate = todayDateOnly;
          
          if (data['quests'] != null) {
            quests = (data['quests'] as List)
                .map((q) => Quest.fromMap(q as Map<String, dynamic>))
                .toList();
          }

          // Keep streak correct vs 36h rule on startup.
          for (final q in quests) {
            q.checkDailyReset(today);
          }
        });

        // 2) Day transition logic: we don't erase history; UI simply checks for today via `isCompletedOn`.
        // Persist "lastActiveDate" so day comparisons are robust.
        await _persistLastActiveDate(todayDateOnly);
        await _questStorage.saveQuests(quests);
        await _questStorage.saveDailyHistory(dailyHistory);
        await _userProfileController.save();
        // If a streak just broke while the app was closed, notify once on startup.
        await verifyDailyReset(now: today, showPopup: true);

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to sync cloud data right now. Using local data.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _syncNotificationsForToday() {
    final total = quests.length;
    final completed = quests.where((q) => q.isCheckedToday(currentDate)).length;
    final hasPending = quests.any(
      (q) => q.streakState(currentDate) != QuestStreakState.broken && !q.isCheckedToday(currentDate),
    );
    NotificationService().syncDailyNotifications(
      totalQuests: total,
      completedToday: completed,
    );
    NotificationService().syncFomoAtNinePm(hasPendingQuests: hasPending);
  }

  Future<void> _saveUserData() async {
    await _firestore.collection('users').doc(userId).set({
      'level': level,
      'xp': xp,
      'gold': gold,
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
    await _userProfileController.save();
    await _questStorage.saveQuests(quests);
    await _questStorage.saveDailyHistory(dailyHistory);
    await _saveUserData();
    await _saveQuestsToFirestore();
    await _persistLastActiveDate(_time.now());
  }

  Future<void> deleteQuest(int index) async {
    final deletedQuest = quests[index]; 
    setState(() {
      quests.removeAt(index);
      for (final entry in dailyHistory.entries.toList()) {
        entry.value.remove(deletedQuest.title);
        if (entry.value.isEmpty) {
          dailyHistory.remove(entry.key);
        } else {
          dailyHistory[entry.key] = entry.value;
        }
      }
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

  // --- LOGICA DE XP/GOLD / BIFĂ ---
  Future<void> completeQuest(int index) async {
    final now = _time.now();
    final today = DateTime(now.year, now.month, now.day);
    currentDate = today;
    final quest = quests[index];
    final wasAlreadyDone = quest.isCheckedToday(today);
    var becameDoneToday = false;
    var becameUndoneToday = false;
    var appliedFailurePenalty = false;

    setState(() {
      if (quest.type == QuestType.negative) {
        appliedFailurePenalty = quest.failNegativeToday(now);
      } else if (quest.type == QuestType.progressive && !quest.isCheckedToday(today)) {
        becameDoneToday = quest.incrementProgress(now);
      } else {
        quest.toggleCompletedAt(now);
      }

      becameDoneToday = becameDoneToday || (!wasAlreadyDone && quest.isCheckedToday(today));
      becameUndoneToday = wasAlreadyDone && !quest.isCheckedToday(today);

      final key = _dateOnly(today);
      final events = List<String>.from(dailyHistory[key] ?? const []);
      if (becameDoneToday) {
        if (!events.contains(quest.title)) events.add(quest.title);
      } else if (becameUndoneToday) {
        events.remove(quest.title);
      }
      if (events.isEmpty) {
        dailyHistory.remove(key);
      } else {
        dailyHistory[key] = events;
      }

      if (becameDoneToday && quest.streakCount > quest.maxStreak) {
        quest.maxStreak = quest.streakCount;
      }
    });

    if (becameDoneToday) {
      final previousLevel = _userProfileController.profile.level;
      await _userProfileController.addReward(25, 5);
      _syncStatsFromProfile();
      if (level > previousLevel) {
        _confettiController.play(); 

        String unlockedAvatarMsg = "";
        for (var avatar in ProfileScreen.avatars) {
          if (avatar['level'] == level) {
            unlockedAvatarMsg = "\n🔓 New Avatar Unlocked: ${avatar['emoji']} ${avatar['name']}!";
            break;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Level Up! You are now Level $level$unlockedAvatarMsg',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (becameUndoneToday) {
      await _userProfileController.removeReward(25, 5);
      _syncStatsFromProfile();
    } else if (appliedFailurePenalty) {
      await _userProfileController.removeReward(15, 10);
      _syncStatsFromProfile();
    }
    
    setState(() {});
    await _persistAll();
    _syncNotificationsForToday();
  }

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
                    Text(
                      'Your flame for "${quest.title}" is frozen. Recover ${quest.recoveryStreakValue} day streak with this rescue.',
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
                              backgroundColor: const Color(0xFF3A2712),
                              foregroundColor: const Color(0xFFFFF3D1),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Color(0xFFFFC107), width: 1.4),
                            ),
                            icon: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6A00)),
                                  )
                                : const Icon(Icons.play_circle_fill, color: Color(0xFFFF6A00)),
                            label: Text(loading ? 'Opening portal…' : 'WATCH AD'),
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
                  child: Text(
                    '$xp / $targetXp XP • $gold Gold • ${_userProfileController.getPlayerTitle(level)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
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
                      final isDone = quest.isCheckedToday(today);
                      final streak = quest.streakBadgeValue(today);
                      final streakState = quest.streakState(today);
                      final badgeState = streakState == QuestStreakState.broken
                          ? StreakBadgeState.broken
                          : streakState == QuestStreakState.active
                              ? StreakBadgeState.active
                              : StreakBadgeState.safe;
                      final isNegative = quest.type == QuestType.negative;
                      final isProgressive = quest.type == QuestType.progressive;

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
                          color: isNegative ? const Color(0xFF2A1717) : null,
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
                            trailing: isNegative
                                ? FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red.shade800,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => completeQuest(index),
                                    child: const Text('I Failed'),
                                  )
                                : isProgressive
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              '${quest.currentProgress}/${quest.targetValue}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, color: Colors.amber, size: 30),
                                            onPressed: () => completeQuest(index),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        icon: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.amber : Colors.white38, size: 28),
                                        onPressed: () => completeQuest(index),
                                      ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isProgressive)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: quest.targetValue == 0 ? 0 : quest.currentProgress / quest.targetValue,
                                          minHeight: 6,
                                          backgroundColor: Colors.black45,
                                          color: Colors.lightBlueAccent,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Text(
                                        'Streak: ${quest.streakCount}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Max: ${quest.maxStreak}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                    ? CalendarScreen(
                        quests: quests,
                        currentDate: currentDate,
                        dailyHistory: dailyHistory,
                        eventLoader: _eventLoader,
                      )
                    : _currentIndex == 2
                        ? const HeroDashboardScreen()
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
              BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Hero'),
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