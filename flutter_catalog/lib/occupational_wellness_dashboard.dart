import 'package:flutter/material.dart';
import 'api_service.dart';
import 'occupational_stress_screen.dart';
import 'occupational_wellness_plan.dart';

class OccupationalWellnessDashboard extends StatefulWidget {
  const OccupationalWellnessDashboard({super.key});

  @override
  State<OccupationalWellnessDashboard> createState() =>
      _OccupationalWellnessDashboardState();
}

class _OccupationalWellnessDashboardState
    extends State<OccupationalWellnessDashboard> {
  OccupationalAssessmentResult? _latestAssessment;
  final OccupationalPlanProgress _planProgress =
      OccupationalPlanProgress.instance;

  @override
  void initState() {
    super.initState();
    _planProgress.addListener(_refreshPlanState);
    _loadLocalState();
  }

  @override
  void dispose() {
    _planProgress.removeListener(_refreshPlanState);
    super.dispose();
  }

  Future<void> _loadLocalState() async {
    final assessment = await OccupationalAssessmentStore.instance
        .loadLatestAssessment();
    await _planProgress.load();
    if (!mounted) return;
    setState(() => _latestAssessment = assessment);
  }

  void _refreshPlanState() {
    if (mounted) setState(() {});
  }

  Future<void> _openAssessment() async {
    final result = await Navigator.push<OccupationalAssessmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => OccupationalStressScreen(
          onAssessmentComplete: (assessment) {
            setState(() => _latestAssessment = assessment);
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _latestAssessment = result);
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
        return const Color(0xFF3DDC97);
      case 'Moderate':
        return const Color(0xFFFFB020);
      case 'High':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF8A5CE6);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No assessment yet';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _primaryRecommendation() {
    final result = _latestAssessment;
    if (result == null) {
      return 'Complete an assessment to receive a focused recommendation.';
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
    if (result.riskLevel == 'Low') {
      return 'Maintain your current protective routines and reassess next week.';
    }
    return 'Start the 7-day plan and focus on one manageable wellness action today.';
  }

  @override
  Widget build(BuildContext context) {
    final result = _latestAssessment;
    final riskColor = _riskColor(result?.riskLevel);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Occupational Wellness',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
                  const Text(
                    'Your personal wellness overview',
                    style: TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      final summary = _DashboardPanel(
                        title: 'Current assessment',
                        child: _CurrentAssessmentCard(
                          riskLevel: result?.riskLevel ?? 'Not assessed',
                          score: result?.score,
                          generatedAt: _formatDate(result?.generatedAt),
                          riskColor: riskColor,
                          onStart: _openAssessment,
                        ),
                      );
                      final action = _DashboardPanel(
                        title: 'Recommended action',
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
                        title: 'Quick insights',
                        child: _InsightList(result: result),
                      );
                      final plan = _DashboardPanel(
                        title: '7-day plan',
                        child: _PlanSummary(
                          completed: _planProgress.completedCount,
                          started: _planProgress.started,
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
                    title: 'Day 4 history',
                    child: _HistoryEmptyState(hasLatest: result != null),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.health_and_safety_outlined, color: riskColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    score == null
                        ? 'Complete your first assessment'
                        : '$score / 100 wellness indicator',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Date of assessment: $generatedAt',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            label: Text(
              score == null ? 'Start Assessment' : 'Take New Assessment',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF45199D),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
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
    if (result == null) {
      return const Text(
        'No assessment is available yet. Your contributors and protective factors will appear here after the questionnaire.',
        style: TextStyle(color: Colors.white54, height: 1.45),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8A5CE6), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(color: Colors.white60, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  final int completed;
  final bool started;
  final VoidCallback onContinue;

  const _PlanSummary({
    required this.completed,
    required this.started,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: completed / 7,
          minHeight: 8,
          borderRadius: BorderRadius.circular(20),
          backgroundColor: Colors.white10,
          color: const Color(0xFF3DDC97),
        ),
        const SizedBox(height: 10),
        Text(
          '$completed / 7 completed',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          started
              ? 'Continue the same local plan from your latest assessment.'
              : 'Start the plan after your assessment, then mark each day complete.',
          style: const TextStyle(color: Colors.white54, height: 1.35),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Continue Plan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final bool hasLatest;

  const _HistoryEmptyState({required this.hasLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timeline_outlined, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasLatest
                  ? 'Latest assessment is shown above. Database-backed history and trends are reserved for Day 4.'
                  : 'No assessment history is stored in Day 3. Complete an assessment to view the current result and plan only.',
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
