import 'package:flutter/material.dart';
import 'usage_access_setup_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

class ContinuousMonitoringConsentScreen extends StatelessWidget {
  const ContinuousMonitoringConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: const VeerMitraAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permission-Based Monitoring',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
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
                    Text(
                      'Veer Mitra can monitor behavioral summaries such as app usage patterns, screen time trends, and switching frequency to estimate burnout continuously.',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Monitoring starts only after you explicitly enable the required Android settings access.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your data remains private on device and is used exclusively for personal wellness insights.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UsageAccessSetupScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Continue to Settings',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}