class UserProfile {
  int level;
  int currentXP;
  int gold;

  UserProfile({
    this.level = 1,
    this.currentXP = 0,
    this.gold = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      level: (map['level'] as num?)?.toInt() ?? 1,
      currentXP: (map['currentXP'] as num?)?.toInt() ?? (map['xp'] as num?)?.toInt() ?? 0,
      gold: (map['gold'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'currentXP': currentXP,
      'xp': currentXP,
      'gold': gold,
    };
  }
}
