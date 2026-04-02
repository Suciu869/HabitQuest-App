// FILE: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // IMPORT NOU
import 'firebase_options.dart'; // IMPORT NOU (Fișierul generat de tine adineauri)
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Modificăm main() ca să fie asincron (să poată aștepta conexiunea la internet)
Future<void> main() async {
  // 1. Pregătire obligatorie
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge for Android 15+ (SDK 35). Flutter draws behind system bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    // 2. Încercăm să pornim Firebase, dar îi dăm MAXIM 8 secunde.
    // Dacă în 8 secunde nu răspunde, merge mai departe oricum.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    
    // 3. Pornim notificările cu o limită de 4 secunde.
    await NotificationService().init().timeout(const Duration(seconds: 4));
    // Schedule daily recurring reminders at app start.
    await NotificationService().scheduleDailyQuestReminders().timeout(const Duration(seconds: 4));
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 4));
    
    print("Habit Quest: Servicii pornite cu succes!");
  } catch (e) {
    // Dacă apare orice eroare (SHA-1 greșit, net prost), o prindem aici
    // și lăsăm aplicația să pornească oricum, în loc să înghețe.
    print("Habit Quest: Eroare la pornire servicii, dar continuăm: $e");
  }

  // 4. Această linie TREBUIE să fie executată orice ar fi
  runApp(const HabitQuestApp());
}

class HabitQuestApp extends StatelessWidget {
  const HabitQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Quest',
      // --- NOUA TEMĂ DARK ELEGANTĂ ---
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // Negru mat profund
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber, // Culoarea principală (pentru butoane, progres)
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E1E1E), // Culoarea cardurilor
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white54,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
       cardTheme: CardThemeData( // ADAUGĂ "Data" aici
  color: const Color(0xFF1E1E1E),
  elevation: 0.0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16.0),
    side: const BorderSide(color: Colors.white12, width: 1.0),
  ),
),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white54),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}