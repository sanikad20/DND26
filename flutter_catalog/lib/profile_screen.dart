import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'config/api_config.dart';
import 'theme/app_theme.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileRole? _profile;
  bool _switchingRole = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ApiService.instance.getMyRole();
      if (!mounted) return;
      setState(() {
        _profile = p;
      });
    } catch (_) {}
  }

  Future<void> _switchRole(String newRole) async {
    setState(() => _switchingRole = true);
    try {
      final updated = await ApiService.instance.switchRole(newRole);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _switchingRole = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched role to ${_formatRoleName(newRole)}. Home dashboard updated.'),
          backgroundColor: AppColors.riskLow,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingRole = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch role: $e'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
    }
  }

  Future<void> _toggleOptIn(bool value) async {
    try {
      final updated = await ApiService.instance.updateOptIn(value);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Opted in to demonstration optional wellness features.'
                : 'Opted out of demonstration optional wellness features.',
          ),
          backgroundColor: AppColors.riskLow,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update opt-in: $e'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
    }
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

  /// Lets the user point the app at the right backend without rebuilding.
  Future<void> _editServerUrl(BuildContext context) async {
    final controller = TextEditingController(text: ApiConfig.instance.baseUrl);
    String? status;
    bool reachable = false;
    bool testing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> test() async {
            final url = ApiConfig.normalize(controller.text);
            setDialogState(() {
              testing = true;
              status = null;
            });
            try {
              final r = await http
                  .get(Uri.parse('$url/health'))
                  .timeout(const Duration(seconds: 6));
              reachable = r.statusCode == 200;
              status = reachable
                  ? 'Connected'
                  : 'Server answered with HTTP ${r.statusCode}';
            } catch (_) {
              reachable = false;
              status = 'Could not reach $url';
            }
            if (!context.mounted) return;
            setDialogState(() => testing = false);
          }

          return AlertDialog(
            title: const Text('Backend server'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'http://10.48.117.154:8000',
                  ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      status!,
                      style: TextStyle(
                        color: reachable
                            ? AppColors.riskLow
                            : AppColors.riskHigh,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (ApiConfig.hasBuildTimeOverride)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'This build was started with API_BASE_URL, which '
                      'overrides the saved URL on every launch.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: testing ? null : test,
                child: Text(testing ? 'Testing…' : 'Test'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ApiConfig.instance.setBaseUrl(controller.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log out?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        content: Text(
          'You will need to log in again to continue.',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.saffronAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;

    String displayName = user?.displayName?.trim() ?? '';
    final email = user?.email ?? 'No email associated';
    if (displayName.isEmpty && email.contains('@')) {
      displayName = email.split('@').first;
      displayName = displayName.replaceAll(RegExp(r'[0-9]'), '');
      if (displayName.isNotEmpty) {
        displayName = displayName[0].toUpperCase() + displayName.substring(1);
      }
    }
    if (displayName.isEmpty) displayName = 'Personnel User';

    final currentRole = _profile?.role ?? 'personnel';
    final isOptedIn = _profile?.optInOptionalWellness ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// User Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isDark
                          ? AppColors.darkPrimaryNavy.withValues(alpha: 0.2)
                          : AppColors.lightPrimaryNavy.withValues(alpha: 0.1),
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkPrimaryNavy
                              : AppColors.lightPrimaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (_profile != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatRoleName(currentRole),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E88E5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _profile!.unitId,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// DEMO ROLE SWITCHER SECTION
              Text(
                'DEMO ROLE SWITCHER',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Switch active persona to evaluate role-specific dashboards & privacy controls:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    _RoleOption(
                      title: 'Personnel (Individual)',
                      description: 'Self-assessment, personalized 7-day plans, personal trends.',
                      roleValue: 'personnel',
                      currentRole: currentRole,
                      icon: Icons.person_rounded,
                      onSelect: _switchingRole ? null : () => _switchRole('personnel'),
                    ),
                    const Divider(height: 20),
                    _RoleOption(
                      title: 'Welfare Officer',
                      description: 'Force wellness oversight, active welfare alerts, monitored personnel list.',
                      roleValue: 'welfare_officer',
                      currentRole: currentRole,
                      icon: Icons.health_and_safety_rounded,
                      onSelect: _switchingRole ? null : () => _switchRole('welfare_officer'),
                    ),
                    const Divider(height: 20),
                    _RoleOption(
                      title: 'Unit Commander',
                      description: 'Strictly aggregate unit indicators, shift fatigue, advisory recommendations.',
                      roleValue: 'commander',
                      currentRole: currentRole,
                      icon: Icons.military_tech_rounded,
                      onSelect: _switchingRole ? null : () => _switchRole('commander'),
                    ),
                    const Divider(height: 20),
                    _RoleOption(
                      title: 'Administrator',
                      description: 'System audit logs, cross-unit administration and access review.',
                      roleValue: 'admin',
                      currentRole: currentRole,
                      icon: Icons.admin_panel_settings_rounded,
                      onSelect: _switchingRole ? null : () => _switchRole('admin'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// OPTIONAL WELLNESS DATA (DEMO OPT-IN)
              Text(
                'OPTIONAL WELLNESS DATA (DEMO OPT-IN)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                        const Icon(Icons.favorite_outline_rounded, color: AppColors.riskModerate),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Simulated Biometric / Wearable Streams',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Switch(
                          value: isOptedIn,
                          onChanged: _toggleOptIn,
                          activeThumbColor: AppColors.riskLow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Synthetic demonstration data: Requires explicit opt-in. When enabled, simulates optional wearable recovery and sleep stability indicators under strict privacy isolation.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// Theme Switcher Section
              Text(
                'APPEARANCE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              color: isDark ? AppColors.darkPrimaryNavy : AppColors.lightPrimaryNavy,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'App Theme Mode',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('☀ Light Mode'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('🌙 Dark Mode'),
                            icon: Icon(Icons.dark_mode),
                          ),
                        ],
                        selected: {ThemeController.instance.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          ThemeController.instance.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// Account Information Section
              Text(
                'ACCOUNT DETAILS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Personnel ID',
                      value: _profile?.personnelId ?? 'Loading...',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      label: 'Assigned Unit',
                      value: _profile?.unitId ?? 'UNIT-ALPHA',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      label: 'Account ID',
                      value: user?.uid ?? 'N/A',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      label: 'Auth Provider',
                      value: 'Firebase Email Auth',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      label: 'Account Status',
                      value: 'Active',
                      valueColor: AppColors.riskLow,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              /// Backend server (change URL / test connection)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _editServerUrl(context),
                  icon: const Icon(Icons.dns_rounded),
                  label: const Text(
                    'Backend server',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.riskHigh),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: AppColors.riskHigh,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.riskHigh, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

class _RoleOption extends StatelessWidget {
  final String title;
  final String description;
  final String roleValue;
  final String currentRole;
  final IconData icon;
  final VoidCallback? onSelect;

  const _RoleOption({
    required this.title,
    required this.description,
    required this.roleValue,
    required this.currentRole,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentRole == roleValue;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF1E88E5) : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? const Color(0xFF1E88E5) : null,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1E88E5)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}
