// FILE: lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLogin = true; // Controlează dacă suntem pe Login sau pe Register
  bool _isLoading = false; // Arată o rotiță de încărcare când vorbim cu serverul

  // --- LOGICA DE FIREBASE ---
  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // Încercăm să ne logăm
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Încercăm să creăm un cont nou
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      
      // Dacă a mers, mergem în aplicație (la MainScaffold)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScaffold()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Dacă parola e greșită, emailul e deja folosit, etc.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'An error occurred.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- DESIGN-UL ELEGANT (DARK MODE) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Titlu
              const Icon(Icons.shield, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'WELCOME BACK' : 'JOIN THE QUEST',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),

              // Căsuța de Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.email, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.amber, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Căsuța de Parolă
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.amber, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Butonul Principal
              SizedBox(
                height: 55,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          _isLogin ? 'ENTER REALM' : 'CREATE HERO',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Butonul de schimbare între Login și Register
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin 
                    ? "Don't have an account? Sign Up" 
                    : "Already have an account? Log In",
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}