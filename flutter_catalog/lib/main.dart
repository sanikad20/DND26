import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';   // ← ADD
import 'firebase_options.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';                            // ← ADD
import 'config/api_config.dart';   // ← ADD

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ApiConfig.instance.init();  // ← ADD: loads saved URL before any screen opens
 
  runApp(const BrainLagApp());
}

class BrainLagApp extends StatelessWidget {
  const BrainLagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BrainLag',
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const AuthGate(),   // ← CHANGED from WelcomeScreen
    );
  }
}

/// Decides where to land the user on app start:
/// - No saved Firebase session → WelcomeScreen (Login/Register)
/// - Saved session already exists → straight to HomeScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const WelcomeScreen();
        }

        final displayName =
            (user.displayName != null && user.displayName!.isNotEmpty)
                ? user.displayName!
                : user.email!;

        return HomeScreen(name: displayName);
      },
    );
  }
}