import 'package:flutter/material.dart';
import 'continuous_monitoring_consent_screen.dart';
import 'occupational_consent_screen.dart';
import 'occupational_wellness_dashboard.dart';
import 'widgets/veer_mitra_app_bar.dart';

class HomeScreen extends StatelessWidget {
  final String name;

  const HomeScreen({super.key, required this.name});

  String get _firstName {
    String n = name.trim();
    if (n.contains('@')) {
      n = n.split('@').first;
      n = n.replaceAll(RegExp(r'[0-9]'), '');
      n = n.split(RegExp(r'[._\-]')).first;
      return n.isEmpty
          ? 'there'
          : n[0].toUpperCase() + n.substring(1).toLowerCase();
    }
    return n.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: const VeerMitraAppBar(
        automaticallyImplyLeading: false,
        showProfileButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Welcome Header
              Text(
                'Hello, $_firstName 👋',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Wellness & Resilience Support System',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 20),

              /// Privacy Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privacy-first platform: All self-assessments and monitoring run with explicit user consent.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textTheme.bodyLarge?.color,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Feature 1: Continuous Monitoring
              _FeatureCard(
                title: 'CONTINUOUS MONITORING',
                subtitle: 'Monitor digital habits, usage patterns, and burnout indicators.',
                icon: Icons.insights_rounded,
                iconColor: theme.colorScheme.primary,
                buttonText: 'Open Monitoring',
                isPrimaryButton: false,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContinuousMonitoringConsentScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// Feature 2: Force Wellness
              _FeatureCard(
                title: 'FORCE WELLNESS',
                subtitle: 'Assess occupational stress and workload-related wellness.',
                icon: Icons.health_and_safety_outlined,
                iconColor: theme.colorScheme.tertiary,
                buttonText: 'Start Assessment',
                isPrimaryButton: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OccupationalConsentScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// Feature 3: Wellness Dashboard
              _FeatureCard(
                title: 'WELLNESS DASHBOARD',
                subtitle: 'View assessment history, trends and personalized wellness plans.',
                icon: Icons.space_dashboard_outlined,
                iconColor: theme.colorScheme.secondary,
                buttonText: 'View Dashboard',
                isPrimaryButton: false,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OccupationalWellnessDashboard(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String buttonText;
  final bool isPrimaryButton;
  final VoidCallback onPressed;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.buttonText,
    required this.isPrimaryButton,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isPrimaryButton
                ? ElevatedButton(
                    onPressed: onPressed,
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 15),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onPressed,
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
