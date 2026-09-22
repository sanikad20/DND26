import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'continuous_monitoring_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

class UsageAccessSetupScreen extends StatefulWidget {
  const UsageAccessSetupScreen({super.key});

  @override
  State<UsageAccessSetupScreen> createState() => _UsageAccessSetupScreenState();
}

class _UsageAccessSetupScreenState extends State<UsageAccessSetupScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel =
      MethodChannel('brainlag/usage_access');

  bool accessGranted = false;
  bool isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkUsageAccessPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkUsageAccessPermission();
    }
  }

  Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open settings: $e')),
      );
    }
  }

  Future<void> checkUsageAccessPermission() async {
    setState(() {
      isChecking = true;
    });

    try {
      final bool granted =
          await _channel.invokeMethod('checkUsageAccessPermission');

      if (!mounted) return;
      setState(() {
        accessGranted = granted;
        isChecking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        accessGranted = false;
        isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission check failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;

    return Scaffold(
      appBar: const VeerMitraAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: isChecking
                    ? Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Checking usage access permission...',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        accessGranted
                            ? 'Usage access granted. You can now start continuous monitoring.'
                            : 'Grant usage access from Android settings to begin continuous monitoring.',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: openUsageSettings,
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: checkUsageAccessPermission,
                  child: const Text('Check Again'),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: accessGranted
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContinuousMonitoringScreen(),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenAccent,
                    disabledBackgroundColor: theme.dividerColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Continuous Monitoring',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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