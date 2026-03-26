// FILE: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'; // IMPORT NOU PENTRU VERIFICARE CONT
import 'main_scaffold.dart'; 
import 'login_screen.dart'; // IMPORT NOU PENTRU ECRANUL DE LOGIN

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Variabile pentru a controla animația
  double _opacity = 0.0;
  double _scale = 0.5;

  @override
  void initState() {
    super.initState();
    
    // SCENARIUL ANIMAȚIEI:
    
    // 1. La 100 milisecunde după ce pornește aplicația, facem logo-ul vizibil și mare
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
          _scale = 1.0;
        });
      }
    });

    // 2. După 1.8 secunde, începem să îl facem să dispară (Fade Out) și să se mărească un pic
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _opacity = 0.0;
          _scale = 1.5; 
        });
      }
    });

    // 3. După 2.5 secunde, verificăm contul și trecem la ecranul corect
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        
        // --- LOGICA INTELIGENTĂ NOUĂ ---
        // Întrebăm Firebase dacă există un cont deja conectat pe acest telefon
        final utilizatorCurent = FirebaseAuth.instance.currentUser;
        
        // Dacă a găsit un utilizator, mergem la MainScaffold. Dacă e null, mergem la LoginScreen.
        final ecranUrmator = (utilizatorCurent != null) ? const MainScaffold() : const LoginScreen();
        // ------------------------------

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ecranUrmator,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Folosim fundalul Dark din tema noastră
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          opacity: _opacity,
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut, 
            transform: Matrix4.identity()..scale(_scale),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_moon, size: 100, color: Colors.amber), // L-am făcut auriu ca să se potrivească cu tema nouă
                SizedBox(height: 20),
                Text(
                  'Habit Quest',
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}