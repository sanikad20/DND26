import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'config/api_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ApiConfig.instance.init();
  await ThemeController.instance.init();

  runApp(const BrainLagApp());
}

class BrainLagApp extends StatelessWidget {
  const BrainLagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Veer Mitra',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: const AuthGate(),
        );
      },
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
            body: Center(
              child: CircularProgressIndicator(),
            ),
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