import 'package:flutter/material.dart';

import 'features/occupational/models/occupational_assessment_result.dart';
import 'features/occupational/services/occupational_plan_builder.dart';
import 'features/occupational/state/occupational_assessment_store.dart';
import 'features/occupational/state/occupational_plan_progress.dart';
import 'features/occupational/widgets/occupational_plan_day_card.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

export 'features/occupational/models/occupational_plan_day.dart';
export 'features/occupational/services/occupational_plan_builder.dart';
export 'features/occupational/state/occupational_assessment_store.dart';
export 'features/occupational/state/occupational_plan_progress.dart';
export 'features/occupational/widgets/occupational_plan_day_card.dart';

class OccupationalWellnessPlanScreen extends StatefulWidget {
  final OccupationalAssessmentResult? assessment;

  const OccupationalWellnessPlanScreen({super.key, this.assessment});

  @override
  State<OccupationalWellnessPlanScreen> createState() =>
      _OccupationalWellnessPlanScreenState();
}

class _OccupationalWellnessPlanScreenState
    extends State<OccupationalWellnessPlanScreen> {
  OccupationalAssessmentResult? _assessment;
  OccupationalPlanProgress? _progress;

  @override
  void initState() {
    super.initState();
    _initPlan();
  }

  Future<void> _initPlan() async {
    _assessment = widget.assessment ??
        OccupationalAssessmentStore.instance.latestAssessment ??
        await OccupationalAssessmentStore.instance.loadFromDisk();

    final planId = _assessment?.planId;
    if (planId != null && mounted) {
      final days = buildOccupationalPlanDays(_assessment);
      final progress = OccupationalPlanProgress(
        planId: planId,
        totalDays: days.length,
      );
      progress.addListener(_refresh);
      await progress.load();
      if (!mounted) return;
      setState(() {
        _progress = progress;
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _progress?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final progress = _progress;
    final days = buildOccupationalPlanDays(assessment);
    final totalDays = days.length;
    final isMaintain = totalDays < 7;
    if (progress != null) {
      progress.updateTotalDays(totalDays);
    }
    final nextDay = progress?.currentDay ?? 1;
    final riskLevel = assessment?.riskLevel ?? 'Assessment pending';

    return Scaffold(
      appBar: const VeerMitraAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (progress == null)
                    const _NoPlanNotice()
                  else ...[
                    _PlanHeader(
                      completed: progress.completedCount,
                      started: progress.started,
                      status: progress.status,
                      riskLevel: riskLevel,
                      totalDays: totalDays,
                      isMaintain: isMaintain,
                      onStart: progress.start,
                      onNext: () => progress.setDayCompleted(nextDay, true),
                      onReset: progress.resetProgress,
                      nextDay: nextDay,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 780;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: days.map((day) {
                            final completed = progress.completedDays.contains(
                              day.day,
                            );
                            return SizedBox(
                              width: twoColumns
                                  ? (constraints.maxWidth - 14) / 2
                                  : constraints.maxWidth,
                              child: OccupationalPlanDayCard(
                                day: day,
                                enabled: progress.started,
                                completed: completed,
                                onChanged: (value) => progress.setDayCompleted(
                                  day.day,
                                  value ?? false,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPlanNotice extends StatelessWidget {
  const _NoPlanNotice();

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
      child: Text(
        'Take an assessment first to get a wellness plan.',
        style: TextStyle(color: ThemeController.instance.isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final int completed;
  final bool started;
  final PlanStatus? status;
  final String riskLevel;
  final int totalDays;
  final bool isMaintain;
  final int nextDay;
  final VoidCallback onStart;
  final VoidCallback onNext;
  final VoidCallback onReset;

  const _PlanHeader({
    required this.completed,
    required this.started,
    this.status,
    required this.riskLevel,
    required this.totalDays,
    required this.isMaintain,
    required this.nextDay,
    required this.onStart,
    required this.onNext,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = completed >= totalDays || status == PlanStatus.completed;
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.greenAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMaintain
                          ? '3-Day Maintain Plan'
                          : 'Interactive 7-Day Wellness Plan',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current risk context: $riskLevel. Progress is saved to your account.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: totalDays == 0 ? 0 : completed / totalDays,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: theme.dividerColor,
            color: AppColors.greenAccent,
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / $totalDays days completed',
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: started ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  started ? 'Plan Started' : 'Start Plan',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: !started || allDone ? null : onNext,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  allDone ? 'All Days Complete 🎉' : 'Complete Day $nextDay',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: completed == 0 && !started ? null : onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Plan'),
                style: TextButton.styleFrom(
                  foregroundColor: secondaryTextColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
