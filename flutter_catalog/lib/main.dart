import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'welcome_screen.dart';
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
      home: const WelcomeScreen(),
    );
  }
}