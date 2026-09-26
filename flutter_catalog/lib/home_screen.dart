import 'package:flutter/material.dart';

import 'api_service.dart';
import 'continuous_monitoring_consent_screen.dart';
import 'features/organizational/screens/commander_dashboard.dart';
import 'features/organizational/screens/welfare_officer_dashboard.dart';
import 'occupational_consent_screen.dart';
import 'occupational_wellness_dashboard.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

class HomeScreen extends StatefulWidget {
  final String name;

  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfileRole? _userRole;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await ApiService.instance.getMyRole();
      if (!mounted) return;
      setState(() {
        _userRole = role;
        _loadingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRole = false;
      });
    }
  }

  String get _firstName {
    String n = widget.name.trim();
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

  String _formatRoleName(String? role) {
    switch (role) {
      case 'welfare_officer':
        return 'Welfare Officer';
      case 'commander':
        return 'Unit Commander';
      case 'admin':
        return 'Administrator';
      default:
        return 'Personnel';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'welfare_officer':
        return const Color(0xFF1E88E5);
      case 'commander':
        return const Color(0xFF16A34A);
      case 'admin':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.riskLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final role = _userRole?.role ?? 'personnel';
    final isOfficer = role == 'welfare_officer' || role == 'admin';
    final isCommander = role == 'commander' || role == 'admin';

    return Scaffold(
      appBar: const VeerMitraAppBar(
        automaticallyImplyLeading: false,
        showProfileButton: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserRole,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Welcome Header with Role Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        ],
                      ),
                    ),
                    if (!_loadingRole)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getRoleColor(role).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              role == 'commander'
                                  ? Icons.military_tech_rounded
                                  : (role == 'welfare_officer'
                                      ? Icons.health_and_safety_rounded
                                      : Icons.person_rounded),
                              size: 14,
                              color: _getRoleColor(role),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatRoleName(role),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(role),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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

                /// Welfare Officer Role Card (Only for welfare_officer & admin)
                if (isOfficer) ...[
                  _FeatureCard(
                    title: 'WELFARE OFFICER DASHBOARD',
                    subtitle: 'Force-wide wellness oversight, active welfare alerts, and monitored personnel registry.',
                    icon: Icons.health_and_safety_rounded,
                    iconColor: const Color(0xFF1E88E5),
                    buttonText: 'Open Welfare Dashboard',
                    isPrimaryButton: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WelfareOfficerDashboard(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                /// Commander Role Card (Only for commander & admin)
                if (isCommander) ...[
                  _FeatureCard(
                    title: 'COMMANDER RESILIENCE DASHBOARD',
                    subtitle: 'Aggregate unit operational strain indicators, duty load balancing, and command advisory recommendations.',
                    icon: Icons.military_tech_rounded,
                    iconColor: const Color(0xFF16A34A),
                    buttonText: 'Open Command Dashboard',
                    isPrimaryButton: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommanderDashboard(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                  isPrimaryButton: !isOfficer && !isCommander,
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
