import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'prediction_screen.dart';
import 'continuous_monitoring_consent_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  final String name;

  const HomeScreen({super.key, required this.name});

  // Extract a friendly first name from whatever we receive:
  // "Sanika Deshmukh"       → "Sanika"
  // "sanika20deshmukh@gmail.com" → "Sanika"  (takes part before @, strips digits, capitalizes)
  String get _firstName {
    String n = name.trim();

    // If it looks like an email, extract the local part
    if (n.contains('@')) {
      n = n.split('@').first;          // "sanika20deshmukh"
      n = n.replaceAll(RegExp(r'[0-9]'), ''); // "sanikadesmukh"
      // Split on common separators and take first part
      n = n.split(RegExp(r'[._\-]')).first; // "sanikadesmukh" (no separator here)
      // Capitalize first letter only
      return n.isEmpty ? 'there' : n[0].toUpperCase() + n.substring(1).toLowerCase();
    }

    // It's a display name — take first word
    return n.split(' ').first;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F3F3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('BrainLag',
            style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $_firstName 👋',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you want to monitor burnout.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF45199D), Color(0xFF6D3DE6)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Burnout Monitoring',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text(
                    'Use manual input or enable continuous monitoring for habit-based burnout detection.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.privacy_tip_outlined, color: Color(0xFF45199D)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privacy-first design: monitoring starts only after user consent.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.analytics_outlined, color: Color(0xFF45199D)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manual mode uses entered values, while continuous mode uses collected behavioral summaries.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ]),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45199D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PredictionScreen())),
                child: const Text('Manual Mode',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF45199D), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ContinuousMonitoringConsentScreen())),
                child: const Text('Continuous Monitoring',
                    style: TextStyle(color: Color(0xFF45199D), fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}