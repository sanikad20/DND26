import 'package:flutter/material.dart';

import 'features/occupational/models/occupational_assessment_result.dart';
import 'features/occupational/services/occupational_plan_builder.dart';
import 'features/occupational/state/occupational_plan_progress.dart';
import 'features/occupational/widgets/occupational_plan_day_card.dart';

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
  // Null when this screen was opened without an assessment (nothing to
  // scope progress to yet - there's no plan_id without one).
  OccupationalPlanProgress? _progress;

  @override
  void initState() {
    super.initState();
    final planId = widget.assessment?.planId;
    if (planId != null) {
      final progress = OccupationalPlanProgress(planId: planId);
      progress.addListener(_refresh);
      progress.load();
      _progress = progress;
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
    final progress = _progress;
    final days = buildOccupationalPlanDays(widget.assessment);
    final totalDays = days.length;
    // Low risk gets a short "maintain" list instead of a full 7-day plan.
    final isMaintain = totalDays < 7;
    final nextDay = progress?.nextOpenDay(totalDays) ?? 1;
    final riskLevel = widget.assessment?.riskLevel ?? 'Assessment pending';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isMaintain ? 'Maintain Plan' : '7-Day Wellness Plan',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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

/// Shown if this screen is opened without an assessment to attach a plan
/// to - there's no plan_id to load or save progress against.
class _NoPlanNotice extends StatelessWidget {
  const _NoPlanNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        'Take an assessment first to get a wellness plan.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final int completed;
  final bool started;
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
    final allDone = completed >= totalDays;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3DDC97).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFF3DDC97),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMaintain
                          ? 'Keep-it-steady plan'
                          : 'Interactive 7-day wellness plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current risk context: $riskLevel. Progress is saved to your account.',
                      style: const TextStyle(
                        color: Colors.white60,
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
            value: completed / totalDays,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white10,
            color: const Color(0xFF3DDC97),
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / $totalDays days completed',
            style: const TextStyle(
              color: Colors.white70,
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
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: Text(
                  started ? 'Plan Started' : 'Start Plan',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45199D),
                  disabledBackgroundColor: const Color(0xFF2A2440),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: !started || allDone ? null : onNext,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  allDone ? 'All Days Complete' : 'Complete Day $nextDay',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white30,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: completed == 0 && !started ? null : onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Plan'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  disabledForegroundColor: Colors.white24,
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
