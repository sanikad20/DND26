import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/veer_mitra_app_bar.dart';
import '../models/organizational_models.dart';
import '../services/organizational_service.dart';

class WelfareOfficerDashboard extends StatefulWidget {
  const WelfareOfficerDashboard({super.key});

  @override
  State<WelfareOfficerDashboard> createState() => _WelfareOfficerDashboardState();
}

class _WelfareOfficerDashboardState extends State<WelfareOfficerDashboard> {
  final OrganizationalService _service = OrganizationalService();

  bool _loading = true;
  String? _errorMessage;

  WelfareOverview? _overview;
  List<WelfareAlertItem> _alerts = [];
  List<PersonnelWelfareSummary> _personnel = [];

  String _selectedUnit = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final unitArg = _selectedUnit == 'ALL' ? null : _selectedUnit;
      final results = await Future.wait([
        _service.getWelfareOverview(),
        _service.getActiveAlerts(unitId: unitArg),
        _service.getPersonnelSummaries(unitId: unitArg),
      ]);

      if (!mounted) return;
      setState(() {
        _overview = results[0] as WelfareOverview;
        _alerts = results[1] as List<WelfareAlertItem>;
        _personnel = results[2] as List<PersonnelWelfareSummary>;
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

  Future<void> _acknowledgeAlert(WelfareAlertItem alert) async {
    try {
      final updated = await _service.acknowledgeAlert(alert.alertId);
      if (!mounted) return;
      setState(() {
        _alerts.removeWhere((a) => a.alertId == alert.alertId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert ${updated.alertId} acknowledged successfully.'),
          backgroundColor: AppColors.riskLow,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to acknowledge alert: $e'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;

    return Scaffold(
      appBar: const VeerMitraAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
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
              'Failed to load Welfare Dashboard',
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
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(ThemeData theme, bool isDark) {
    final overview = _overview!;
    final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final filteredPersonnel = _personnel.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.personnelId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.unitId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 1. Header Banner
        _buildHeaderBanner(isDark),
        const SizedBox(height: 12),

        // 2. Synthetic Data Notice Banner
        _buildPrivacyNoticeBanner(isDark),
        const SizedBox(height: 16),

        // 3. Unit Filter Selector
        _buildUnitFilterBar(cardBg, borderColor),
        const SizedBox(height: 16),

        // 4. Force High-Level Metrics
        _buildOverviewCards(overview, cardBg, borderColor),
        const SizedBox(height: 20),

        // 5. Active Welfare Alerts Section
        _buildAlertsSection(cardBg, borderColor),
        const SizedBox(height: 20),

        // 6. Stress Contributors Analysis
        _buildContributorsCard(overview, cardBg, borderColor),
        const SizedBox(height: 20),

        // 7. Unit Breakdown Comparison
        _buildUnitComparisonCard(overview, cardBg, borderColor),
        const SizedBox(height: 20),

        // 8. Monitored Personnel Registry
        _buildPersonnelRegistryCard(filteredPersonnel, cardBg, borderColor),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132337) : const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFB9D5F3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFD0E3F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF1E88E5), size: 30),
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
                      'Welfare Officer Dashboard',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    _RoleBadge(label: 'OFFICER'),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Proactive force wellness monitoring, early support alerts, and rest balance oversight.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNoticeBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1F26) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Synthetic demonstration data. Confidential: Individual 12-question responses remain strictly private.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitFilterBar(Color cardBg, Color borderColor) {
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
          const Icon(Icons.filter_list_rounded, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Filter Unit: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUnit,
                  isDense: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
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
                      _loadDashboardData();
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

  Widget _buildOverviewCards(WelfareOverview overview, Color cardBg, Color borderColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Monitored',
                value: '${overview.totalPersonnelMonitored}',
                subtitle: 'Personnel in roster',
                icon: Icons.groups_rounded,
                color: const Color(0xFF2563EB),
                cardBg: cardBg,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Active Alerts',
                value: '${overview.activeAlertsCount}',
                subtitle: 'Require check-in',
                icon: Icons.notification_important_rounded,
                color: overview.activeAlertsCount > 0 ? AppColors.riskHigh : AppColors.riskLow,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Avg Stress Score',
                value: '${overview.averageStressScore}/100',
                subtitle: 'Force average',
                icon: Icons.speed_rounded,
                color: overview.averageStressScore > 60 ? AppColors.riskHigh : AppColors.riskModerate,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Worsening Trend',
                value: '${overview.worseningTrendCount}',
                subtitle: 'Increasing strain',
                icon: Icons.trending_up_rounded,
                color: AppColors.riskModerate,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Risk Distribution Bar
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
              const Text('Risk Level Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (overview.lowRiskPct * 10).toInt(),
                        child: Container(color: AppColors.riskLow),
                      ),
                      Expanded(
                        flex: (overview.moderateRiskPct * 10).toInt(),
                        child: Container(color: AppColors.riskModerate),
                      ),
                      Expanded(
                        flex: (overview.highRiskPct * 10).toInt(),
                        child: Container(color: AppColors.riskHigh),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _RiskLegend(label: 'Low', count: overview.lowRiskCount, pct: overview.lowRiskPct, color: AppColors.riskLow),
                  _RiskLegend(label: 'Moderate', count: overview.moderateRiskCount, pct: overview.moderateRiskPct, color: AppColors.riskModerate),
                  _RiskLegend(label: 'High', count: overview.highRiskCount, pct: overview.highRiskPct, color: AppColors.riskHigh),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(Color cardBg, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.riskModerate),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Active Welfare Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _alerts.isNotEmpty ? AppColors.riskHigh.withValues(alpha: 0.1) : AppColors.riskLow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_alerts.length} Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _alerts.isNotEmpty ? AppColors.riskHigh : AppColors.riskLow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: const Center(
              child: Text(
                'No pending welfare alerts for this selection. All indicators are stable.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ..._alerts.map((alert) => _buildAlertCard(alert, cardBg, borderColor)),
      ],
    );
  }

  Widget _buildAlertCard(WelfareAlertItem alert, Color cardBg, Color borderColor) {
    final isHigh = alert.isHigh;
    final alertColor = isHigh ? AppColors.riskHigh : AppColors.riskModerate;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alertColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.severity.toUpperCase(),
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${alert.personnelId} • ${alert.unitId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                alert.alertId,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: alertColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _acknowledgeAlert(alert),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Acknowledge Outreach', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributorsCard(WelfareOverview overview, Color cardBg, Color borderColor) {
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
              Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Primary Force Stress Contributors',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...overview.topContributors.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${c.affectedCount} personnel (${c.percentage.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: c.percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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

  Widget _buildUnitComparisonCard(WelfareOverview overview, Color cardBg, Color borderColor) {
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
              Icon(Icons.corporate_fare_rounded, size: 20, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unit-wise Resilience Comparison',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...overview.unitOverviews.map((u) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          u.unitId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Avg Stress: ${u.averageStress}/100',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: u.averageStress > 55 ? AppColors.riskModerate : AppColors.riskLow,
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text('Personnel: ${u.personnelCount}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('High Risk: ${u.highRiskCount} (${u.highRiskPct}%)', style: const TextStyle(fontSize: 11, color: AppColors.riskHigh)),
                      Text('Alerts: ${u.activeAlertsCount}', style: const TextStyle(fontSize: 11, color: AppColors.riskModerate)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPersonnelRegistryCard(List<PersonnelWelfareSummary> personnel, Color cardBg, Color borderColor) {
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
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 20, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Monitored Personnel Registry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${personnel.length} Listed', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Individual records display risk indicators and shift load only. Detailed answers remain strictly confidential.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search Personnel ID or Unit...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          // List Items
          if (personnel.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No personnel matching query.', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: personnel.take(15).length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final p = personnel[index];
                final riskColor = p.riskLevel == 'High'
                    ? AppColors.riskHigh
                    : (p.riskLevel == 'Moderate' ? AppColors.riskModerate : AppColors.riskLow);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  p.personnelId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  p.unitId,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                _TrendBadge(trend: p.trend),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Duty: ${p.dutyHours}h/day • ${p.consecutiveDutyDays}d consec',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.riskLevel,
                              style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Score: ${p.score}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: riskColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          if (personnel.length > 15)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text('Showing first 15 of ${personnel.length} records',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final Color borderColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RiskLegend extends StatelessWidget {
  final String label;
  final int count;
  final double pct;
  final Color color;

  const _RiskLegend({
    required this.label,
    required this.count,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: $count (${pct.toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final String trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    if (trend == 'Worsening') {
      color = AppColors.riskHigh;
      icon = Icons.trending_up;
    } else if (trend == 'Improving') {
      color = AppColors.riskLow;
      icon = Icons.trending_down;
    } else {
      color = const Color(0xFF64748B);
      icon = Icons.trending_flat;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(trend, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
