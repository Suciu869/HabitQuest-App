import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileController extends ChangeNotifier {
  static const String _keyProfile = 'hq_user_profile_v1';
  UserProfile profile = UserProfile();

  int getRequiredXpForNextLevel(int currentLevel) {
    return (currentLevel * currentLevel) * 50 + 50;
  }

  String getPlayerTitle(int currentLevel) {
    if (currentLevel >= 50) return 'Legend';
    if (currentLevel >= 20) return 'Hero';
    if (currentLevel >= 10) return 'Knight';
    if (currentLevel >= 5) return 'Squire';
    return 'Novice';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    profile = UserProfile.fromMap(decoded);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toMap()));
    notifyListeners();
  }

  Future<void> addReward(int xpAmount, int goldAmount) async {
    profile.currentXP += xpAmount;
    profile.gold += goldAmount;

    var requiredXp = getRequiredXpForNextLevel(profile.level);
    while (profile.currentXP >= requiredXp) {
      profile.currentXP -= requiredXp;
      profile.level += 1;
      requiredXp = getRequiredXpForNextLevel(profile.level);
    }

    await save();
  }

  Future<void> removeReward(int xpAmount, int goldAmount) async {
    profile.currentXP -= xpAmount;
    profile.gold -= goldAmount;

    if (profile.gold < 0) profile.gold = 0;

    while (profile.currentXP < 0 && profile.level > 1) {
      profile.level -= 1;
      profile.currentXP += getRequiredXpForNextLevel(profile.level);
    }

    if (profile.currentXP < 0) profile.currentXP = 0;
    if (profile.level < 1) profile.level = 1;

    await save();
  }
}
