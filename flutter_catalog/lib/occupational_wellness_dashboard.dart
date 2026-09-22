import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'api_service.dart';
import 'features/burnout/state/burnout_history_store.dart';
import 'occupational_consent_screen.dart';
import 'occupational_wellness_plan.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

class OccupationalWellnessDashboard extends StatefulWidget {
  const OccupationalWellnessDashboard({super.key});

  @override
  State<OccupationalWellnessDashboard> createState() =>
      _OccupationalWellnessDashboardState();
}

class _OccupationalWellnessDashboardState
    extends State<OccupationalWellnessDashboard> {
  OccupationalAssessmentResult? _latestAssessment;
  OccupationalPlanProgress? _planProgress;

  OccupationalHistory? _history;
  bool _historyLoading = true;
  String? _historyError;

  List<BurnoutHistoryPoint> _burnoutHistory = const [];

  @override
  void initState() {
    super.initState();
    _loadBurnoutHistory();
    _loadHistory();
  }

  Future<void> _loadBurnoutHistory() async {
    final points = await BurnoutHistoryStore.instance.load();
    if (!mounted) return;
    setState(() => _burnoutHistory = points);
  }

  @override
  void dispose() {
    _planProgress?.removeListener(_refreshPlanState);
    super.dispose();
  }

  void _attachPlanProgress(OccupationalAssessmentResult assessment) {
    _planProgress?.removeListener(_refreshPlanState);
    final progress = OccupationalPlanProgress(planId: assessment.planId);
    progress.addListener(_refreshPlanState);
    progress.load();
    _planProgress = progress;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = 'Sign in to view your wellness history.';
      });
      return;
    }
    try {
      final history = await ApiService.instance.getOccupationalHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = 'Could not load history from the backend.';
        _historyLoading = false;
      });
    }
  }

  void _refreshPlanState() {
    if (mounted) setState(() {});
  }

  Future<void> _openAssessment() async {
    final result = await Navigator.push<OccupationalAssessmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => OccupationalConsentScreen(
          onAssessmentComplete: (assessment) {
            setState(() => _latestAssessment = assessment);
            _attachPlanProgress(assessment);
            _loadHistory();
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _latestAssessment = result);
      _attachPlanProgress(result);
      _loadHistory();
    }
  }

  Future<void> _openPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OccupationalWellnessPlanScreen(assessment: _latestAssessment),
      ),
    );
  }

  Color _riskColor(String? level) {
    switch (level) {
      case 'Low':
        return AppColors.riskLow;
      case 'Moderate':
        return AppColors.riskModerate;
      case 'High':
        return AppColors.riskHigh;
      default:
        return AppColors.saffronAccent;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No assessment yet';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _primaryRecommendation() {
    final result = _latestAssessment;
    if (result == null) {
      return 'Complete an assessment to receive a focused recommendation.';
    }
    if (result.recommendationItems.isNotEmpty) {
      return result.recommendationItems.first.text;
    }
    final labels = result.contributorLabels.join(' ').toLowerCase();
    if (labels.contains('recovery')) {
      return 'Prioritize a short recovery window after duty and track whether rest improves this week.';
    }
    if (labels.contains('workload')) {
      return 'Identify one workload pressure that can be planned, delegated, or discussed through the right channel.';
    }
    if (labels.contains('support')) {
      return 'Consider a practical check-in with a trusted peer or supervisor for support around current duty pressure.';
    }
    if (labels.contains('family') || labels.contains('social')) {
      return 'Protect a short connection window with family, loved ones, or a trusted peer this week.';
    }
    if (labels.contains('control')) {
      return 'Pick one flexible part of the next duty block that can be clarified, sequenced, or simplified.';
    }
    if (result.riskLevel == 'Low') {
      return 'Maintain your current protective routines and reassess next week.';
    }
    return 'Start the 7-day plan and focus on one manageable wellness action today.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final result = _latestAssessment;
    final latestHistoryPoint = (_history?.assessments.isNotEmpty ?? false)
        ? _history!.assessments.last
        : null;
    final displayRiskLevel = result?.riskLevel ?? latestHistoryPoint?.riskLevel;
    final displayScore = result?.score ?? latestHistoryPoint?.score;
    final displayDate = result?.generatedAt ?? latestHistoryPoint?.timestamp;
    final riskColor = _riskColor(displayRiskLevel);

    return Scaffold(
      appBar: const VeerMitraAppBar(
        showProfileButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your personal force wellness overview',
                    style: TextStyle(
                      color: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DashboardPanel(
                    title: 'Trends at a glance',
                    child: _TrendsAtAGlance(
                      burnout: _burnoutHistory,
                      occupational: _history,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      final summary = _DashboardPanel(
                        title: 'Current Assessment',
                        child: _CurrentAssessmentCard(
                          riskLevel: displayRiskLevel ?? 'Not assessed',
                          score: displayScore,
                          generatedAt: _formatDate(displayDate),
                          riskColor: riskColor,
                          onStart: _openAssessment,
                        ),
                      );
                      final action = _DashboardPanel(
                        title: 'Recommended Action',
                        child: _RecommendedActionCard(
                          text: _primaryRecommendation(),
                          color: riskColor,
                        ),
                      );

                      if (!wide) {
                        return Column(
                          children: [
                            summary,
                            const SizedBox(height: 16),
                            action,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: summary),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: action),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      final insights = _DashboardPanel(
                        title: 'Quick Insights',
                        child: _InsightList(result: result),
                      );
                      final planTotal = buildOccupationalPlanDays(
                        result,
                      ).length;
                      final planProgress = _planProgress;
                      final plan = _DashboardPanel(
                        title: planTotal < 7 ? 'Maintain Plan' : '7-Day Plan',
                        child: result == null
                            ? _PlanSummary(
                                total: planTotal,
                                completed: 0,
                                started: false,
                                onContinue: _openAssessment,
                                continueLabel: 'Take Assessment',
                              )
                            : _PlanSummary(
                                total: planTotal,
                                completed: planProgress?.completedCount ?? 0,
                                started: planProgress?.started ?? false,
                                onContinue: _openPlan,
                              ),
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            insights,
                            const SizedBox(height: 16),
                            plan,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: insights),
                          const SizedBox(width: 16),
                          Expanded(child: plan),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _DashboardPanel(
                    title: 'Assessment History',
                    child: _HistoryChartsSection(
                      history: _history,
                      loading: _historyLoading,
                      error: _historyError,
                      hasLatest: result != null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _DashboardPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CurrentAssessmentCard extends StatelessWidget {
  final String riskLevel;
  final int? score;
  final String generatedAt;
  final Color riskColor;
  final VoidCallback onStart;

  const _CurrentAssessmentCard({
    required this.riskLevel,
    required this.score,
    required this.generatedAt,
    required this.riskColor,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.health_and_safety_outlined, color: riskColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    riskLevel.toUpperCase(),
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    score == null
                        ? 'Complete your first assessment'
                        : '$score / 100 wellness indicator',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Date of assessment: $generatedAt',
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.assignment_outlined),
            label: Text(
              score == null ? 'Start Assessment' : 'Take New Assessment',
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedActionCard extends StatelessWidget {
  final String text;
  final Color color;

  const _RecommendedActionCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightList extends StatelessWidget {
  final OccupationalAssessmentResult? result;

  const _InsightList({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result == null) {
      return Text(
        'No assessment is available yet. Your contributors and protective factors will appear here after the questionnaire.',
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          height: 1.45,
        ),
      );
    }

    final contributors = result!.contributorLabels;
    return Column(
      children: [
        _InsightRow(
          icon: Icons.trending_up,
          label: 'Key contributors',
          value: contributors.isEmpty
              ? 'None flagged'
              : contributors.join(', '),
        ),
        const SizedBox(height: 12),
        _InsightRow(
          icon: Icons.shield_outlined,
          label: 'Protective factors',
          value: result!.protectiveFactors.isEmpty
              ? 'None flagged yet'
              : result!.protectiveFactors.join(', '),
        ),
        const SizedBox(height: 12),
        _InsightRow(
          icon: Icons.bedtime_outlined,
          label: 'Recovery indicator',
          value:
              contributors.any(
                (item) => item.toLowerCase().contains('recovery'),
              )
              ? 'Recovery needs attention'
              : 'No recovery concern flagged',
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.textTheme.titleSmall?.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  final int total;
  final int completed;
  final bool started;
  final VoidCallback onContinue;
  final String continueLabel;

  const _PlanSummary({
    required this.total,
    required this.completed,
    required this.started,
    required this.onContinue,
    this.continueLabel = 'Continue Plan',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: total == 0 ? 0 : completed / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: theme.dividerColor,
          color: AppColors.riskLow,
        ),
        const SizedBox(height: 10),
        Text(
          '$completed / $total completed',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          started
              ? 'Continue the plan from your latest assessment.'
              : 'Start the plan after your assessment, then mark each day complete.',
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(continueLabel),
          ),
        ),
      ],
    );
  }
}

class _HistoryChartsSection extends StatelessWidget {
  final OccupationalHistory? history;
  final bool loading;
  final String? error;
  final bool hasLatest;

  const _HistoryChartsSection({
    required this.history,
    required this.loading,
    required this.error,
    required this.hasLatest,
  });

  Color _trendColor(String trend) {
    switch (trend) {
      case 'Improving':
        return AppColors.riskLow;
      case 'Worsening':
        return AppColors.riskHigh;
      case 'Stable':
        return AppColors.riskModerate;
      default:
        return AppColors.saffronAccent;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Improving':
        return Icons.trending_down;
      case 'Worsening':
        return Icons.trending_up;
      case 'Stable':
        return Icons.trending_flat;
      default:
        return Icons.show_chart;
    }
  }

  double _riskToY(String riskLevel) {
    switch (riskLevel) {
      case 'Low':
        return 1;
      case 'Moderate':
        return 2;
      case 'High':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final data = history;
    if (data == null || !data.hasEnoughForChart) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timeline_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLatest
                    ? 'Complete one more assessment to start seeing a trend here. Each assessment is saved to your account.'
                    : 'No assessment history yet. Complete an assessment to start building your trend.',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final points = data.assessments;
    final scoreSpots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].score.toDouble()),
    ];
    final riskSpots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), _riskToY(points[i].riskLevel)),
    ];
    final trendColor = _trendColor(data.trend);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_trendIcon(data.trend), color: trendColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Trend: ${data.trend}',
              style: TextStyle(
                color: trendColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${points.length} assessments',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Score over time (0-100)',
          style: TextStyle(
            color: theme.textTheme.titleSmall?.color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: theme.dividerColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: scoreSpots,
                  isCurved: true,
                  color: theme.colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Risk level over time',
          style: TextStyle(
            color: theme.textTheme.titleSmall?.color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: 0.5,
              maxY: 3.5,
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: theme.dividerColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 66,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const labels = {1: 'Low', 2: 'Moderate', 3: 'High'};
                      final rounded = value.round();
                      if ((value - rounded).abs() > 0.01) {
                        return const SizedBox.shrink();
                      }
                      final label = labels[rounded];
                      if (label == null) return const SizedBox.shrink();
                      return Text(
                        label,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: riskSpots,
                  isCurved: false,
                  color: trendColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendsAtAGlance extends StatelessWidget {
  final List<BurnoutHistoryPoint> burnout;
  final OccupationalHistory? occupational;

  const _TrendsAtAGlance({required this.burnout, required this.occupational});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final burnoutValues = burnout.map((p) => p.score).toList();
    final occupationalValues =
        (occupational?.assessments ?? const <OccupationalHistoryPoint>[])
            .map((p) => p.score.toDouble())
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MiniTrendCard(
                title: 'Digital burnout',
                scale: 'Score 1-10',
                color: theme.colorScheme.primary,
                values: burnoutValues,
                minY: 0,
                maxY: 10,
                latestText: burnoutValues.isEmpty
                    ? '--'
                    : burnoutValues.last.toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniTrendCard(
                title: 'Force wellness',
                scale: 'Score 0-100',
                color: AppColors.saffronAccent,
                values: occupationalValues,
                minY: 0,
                maxY: 100,
                latestText: occupationalValues.isEmpty
                    ? '--'
                    : occupationalValues.last.toStringAsFixed(0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Shown separately on purpose: the two scores measure different indicators using distinct evaluation models.',
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MiniTrendCard extends StatelessWidget {
  final String title;
  final String scale;
  final String latestText;
  final Color color;
  final List<double> values;
  final double minY;
  final double maxY;

  const _MiniTrendCard({
    required this.title,
    required this.scale,
    required this.latestText,
    required this.color,
    required this.values,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor == AppColors.lightSurfaceCard
            ? AppColors.lightSurfaceMuted
            : AppColors.darkSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            latestText,
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            scale,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: values.length >= 2
                ? LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      minX: 0,
                      maxX: (values.length - 1).toDouble(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: FlDotData(show: values.length <= 8),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      'Not enough data yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            '${values.length} ${values.length == 1 ? 'result' : 'results'}',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
