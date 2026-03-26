// FILE: lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final int level; // Primim nivelul ca să știm ce avatare deblocăm
  final String currentAvatar;
  final Function(String) onAvatarChanged;

  const ProfileScreen({
    super.key,
    required this.level,
    required this.currentAvatar,
    required this.onAvatarChanged,
  });

  // --- CATALOGUL DE AVATARE ---
  static const List<Map<String, dynamic>> avatars = [
    {'emoji': '🧑‍🌾', 'name': 'Villager', 'level': 1},
    {'emoji': '🥷', 'name': 'Ninja', 'level': 3},
    {'emoji': '🧙‍♂️', 'name': 'Wizard', 'level': 5},
    {'emoji': '🧝‍♂️', 'name': 'Elf', 'level': 10},
    {'emoji': '🦸‍♂️', 'name': 'Hero', 'level': 15},
    {'emoji': '👑', 'name': 'King', 'level': 20},
  ];

  // --- PANOU DE SELECȚIE AVATAR ---
  void _showAvatarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHOOSE YOUR AVATAR',
                style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 pe rând
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isUnlocked = level >= avatar['level']; // Verificăm dacă ai nivelul necesar

                  return GestureDetector(
                    onTap: () {
                      if (isUnlocked) {
                        onAvatarChanged(avatar['emoji']);
                        Navigator.pop(context); // Închidem meniul după ce am ales
                      } else {
                        // Mesaj dacă nu ai nivelul
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unlocks at Level ${avatar['level']}!'),
                            backgroundColor: Colors.redAccent,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentAvatar == avatar['emoji'] ? Colors.amber.withOpacity(0.3) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: currentAvatar == avatar['emoji'] ? Colors.amber : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(avatar['emoji'], style: TextStyle(fontSize: 40, color: isUnlocked ? Colors.white : Colors.white24)),
                          
                          // Dacă e blocat, punem un lacăt transparent peste el
                          if (!isUnlocked)
                            Container(
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                              child: const Center(child: Icon(Icons.lock, color: Colors.white70, size: 28)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- LOGOUT & DELETE ACCOUNT ---
  void _logOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text('This action is irreversible.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE FOREVER', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
          await user.delete();
          if (context.mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error. Try logging out first.'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Butonul Avatarului tău
          GestureDetector(
            onTap: () => _showAvatarSelector(context),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.amber.withOpacity(0.2),
              child: Text(currentAvatar, style: const TextStyle(fontSize: 60)), // Arătăm Emoji-ul mare!
            ),
          ),
          
          const SizedBox(height: 20),
          const Text(
            'HERO PROFILE',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          Text(
            user?.email ?? 'Unknown Email',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white54),
          ),
          
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _logOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 15),
          TextButton.icon(
            onPressed: () => _deleteAccount(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text('DELETE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}