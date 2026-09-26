import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/veer_mitra_app_bar.dart';
import '../models/organizational_models.dart';
import '../services/organizational_service.dart';

class CommanderDashboard extends StatefulWidget {
  const CommanderDashboard({super.key});

  @override
  State<CommanderDashboard> createState() => _CommanderDashboardState();
}

class _CommanderDashboardState extends State<CommanderDashboard> {
  final OrganizationalService _service = OrganizationalService();

  bool _loading = true;
  String? _errorMessage;

  CommanderUnitSummary? _summary;

  String _selectedUnit = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUnitData();
  }

  Future<void> _loadUnitData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final unitParam = _selectedUnit;
      final summary = await _service.getCommanderUnitSummary(unitParam);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;

    return Scaffold(
      appBar: const VeerMitraAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadUnitData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _buildDashboardContent(theme, isDark),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.riskHigh),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Commander Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadUnitData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(ThemeData theme, bool isDark) {
    final summary = _summary!;
    final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 1. Header Banner
        _buildHeaderBanner(isDark),
        const SizedBox(height: 12),

        // 2. Strict Privacy Protected Banner
        _buildPrivacyProtectionBanner(summary.privacyNotice, isDark),
        const SizedBox(height: 16),

        // 3. Unit Selector Dropdown
        _buildUnitSelector(cardBg, borderColor),
        const SizedBox(height: 16),

        // 4. Aggregate Stress & Risk Cards
        _buildAggregateMetrics(summary, cardBg, borderColor),
        const SizedBox(height: 20),

        // 5. Operational Load Indicators
        _buildOperationalLoadSection(summary, cardBg, borderColor),
        const SizedBox(height: 20),

        // 6. Advisory Command Recommendations
        _buildRecommendationsSection(summary, cardBg, borderColor),
        const SizedBox(height: 20),

        // 7. Synthetic Data Notice
        _buildSyntheticNotice(summary.disclaimer),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2B3E) : const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF243B53) : const Color(0xFFB7E1CD),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF243B53) : const Color(0xFFCEEAD6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.military_tech_rounded, color: Color(0xFF137333), size: 30),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Commander Dashboard',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    _CommanderRoleBadge(label: 'COMMAND'),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Unit resilience, operational load indicators, and duty fatigue mitigation.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyProtectionBanner(String notice, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A261D) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(Color cardBg, Color borderColor) {
    const units = ['ALL', 'UNIT-ALPHA', 'UNIT-BRAVO', 'UNIT-CHARLIE'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 20, color: Color(0xFF137333)),
          const SizedBox(width: 8),
          const Text('Unit: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUnit,
                  isDense: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF137333)),
                  items: units.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(
                        u == 'ALL' ? 'Force-Wide (All Units)' : u,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedUnit) {
                      setState(() => _selectedUnit = val);
                      _loadUnitData();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAggregateMetrics(CommanderUnitSummary summary, Color cardBg, Color borderColor) {
    final low = summary.riskDistribution['Low'] ?? 0;
    final mod = summary.riskDistribution['Moderate'] ?? 0;
    final high = summary.riskDistribution['High'] ?? 0;
    final total = (low + mod + high) > 0 ? (low + mod + high) : 1;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unit Average Stress',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${summary.averageStress}/100',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: summary.averageStress > 55 ? AppColors.riskModerate : AppColors.riskLow,
                          )),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.unitId,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'High Risk Proportion',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${summary.highRiskPct}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: summary.highRiskPct > 15 ? AppColors.riskHigh : AppColors.riskModerate,
                          )),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$high of $total personnel',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Aggregate Distribution Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unit Risk Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(flex: low, child: Container(color: AppColors.riskLow)),
                      Expanded(flex: mod, child: Container(color: AppColors.riskModerate)),
                      Expanded(flex: high, child: Container(color: AppColors.riskHigh)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text('Low: $low', style: const TextStyle(fontSize: 11, color: AppColors.riskLow, fontWeight: FontWeight.bold)),
                  Text('Moderate: $mod', style: const TextStyle(fontSize: 11, color: AppColors.riskModerate, fontWeight: FontWeight.bold)),
                  Text('High: $high', style: const TextStyle(fontSize: 11, color: AppColors.riskHigh, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalLoadSection(CommanderUnitSummary summary, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, size: 20, color: Color(0xFF1E88E5)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operational Load & Resilience Indicators',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _IndicatorRow(
            title: 'Workload Pressure',
            status: summary.workloadPressure,
            description: 'Cumulative duty hours and shift intensity.',
            icon: Icons.timer_rounded,
          ),
          const Divider(height: 16),
          _IndicatorRow(
            title: 'Night Duty Load',
            status: summary.nightDutyLoad,
            description: 'Night shifts across rostered detachments.',
            icon: Icons.nightlight_round,
          ),
          const Divider(height: 16),
          _IndicatorRow(
            title: 'Recovery Status',
            status: summary.recoveryStatus,
            description: 'Adequacy of rest days and leave intervals.',
            icon: Icons.battery_charging_full_rounded,
          ),
          const Divider(height: 16),
          _IndicatorRow(
            title: 'Deployment Burden',
            status: summary.deploymentLoad,
            description: 'Consecutive field and detachment days.',
            icon: Icons.terrain_rounded,
          ),
          const Divider(height: 16),
          _IndicatorRow(
            title: 'Training Load',
            status: summary.trainingLoad,
            description: 'Physical and operational readiness conditioning.',
            icon: Icons.fitness_center_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(CommanderUnitSummary summary, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 20, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Command Advisory Recommendations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Operational suggestions for fatigue mitigation. Advisory only; does not override operational directives.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...summary.recommendations.map((rec) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded, size: 20, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSyntheticNotice(String disclaimer) {
    return Center(
      child: Text(
        '$disclaimer • Not real CRPF/CAPF personnel data',
        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final String title;
  final String status;
  final String description;
  final IconData icon;

  const _IndicatorRow({
    required this.title,
    required this.status,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    if (status == 'High' || status == 'Needs Attention' || status == 'Extended') {
      badgeColor = AppColors.riskHigh;
    } else if (status == 'Elevated' || status == 'Moderate' || status == 'Demanding') {
      badgeColor = AppColors.riskModerate;
    } else {
      badgeColor = AppColors.riskLow;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _CommanderRoleBadge extends StatelessWidget {
  final String label;
  const _CommanderRoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF137333),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
