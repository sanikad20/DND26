import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'config/api_config.dart';
import 'occupational_wellness_plan.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

class OccupationalStressScreen extends StatefulWidget {
  final ValueChanged<OccupationalAssessmentResult>? onAssessmentComplete;

  const OccupationalStressScreen({super.key, this.onAssessmentComplete});

  @override
  State<OccupationalStressScreen> createState() =>
      _OccupationalStressScreenState();
}

class _OccupationalStressScreenState extends State<OccupationalStressScreen> {
  static const _disclaimer =
      'This is an early-warning wellness/stress-risk indicator based on '
      'self-reported information. It does not diagnose depression, anxiety, '
      'PTSD, or any medical or psychological condition.';

  bool _isLoading = false;
  String? _errorText;

  double dutyHoursPerDay = 8;
  double nightDutiesLast2wks = 2;
  double consecutiveDaysNoRest = 3;
  double daysSinceLastLeave = 20;
  double leaveDaysTaken3mo = 5;
  double recoveryQuality = 3;
  double familyTime = 3;

  double demand = 3;
  double control = 3;
  double support = 3;
  double effort = 3;
  double reward = 3;

  OccupationalAssessmentResult? _result;
  OccupationalPlanProgress? _planProgress;

  Map<int, String> _questionTexts = const {};

  @override
  void initState() {
    super.initState();
    _loadQuestionTexts();
  }

  Future<void> _loadQuestionTexts() async {
    try {
      final texts = await ApiService.instance.getOccupationalQuestionTexts();
      if (!mounted) return;
      setState(() => _questionTexts = texts);
    } catch (_) {}
  }

  @override
  void dispose() {
    _planProgress?.removeListener(_refreshPlanState);
    super.dispose();
  }

  void _refreshPlanState() {
    if (mounted) setState(() {});
  }

  bool get _hasResult => _result != null;

  Future<void> _runAssessment() async {
    if (_isLoading) return;
    if (!_answersAreValid()) {
      setState(() {
        _errorText = 'Please review the highlighted values before submitting.';
      });
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _errorText = 'Please sign in again before running an assessment.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final answers = OccupationalAnswers(
      dutyHoursPerDay: dutyHoursPerDay,
      nightDutiesLast2wks: nightDutiesLast2wks,
      consecutiveDaysNoRest: consecutiveDaysNoRest,
      daysSinceLastLeave: daysSinceLastLeave,
      leaveDaysTaken3mo: leaveDaysTaken3mo,
      recoveryQuality: recoveryQuality.round(),
      familyTime: familyTime.round(),
      demand: demand.round(),
      control: control.round(),
      support: support.round(),
      effort: effort.round(),
      reward: reward.round(),
    );

    try {
      final assessment = await ApiService.instance.assessOccupational(answers);
      if (!mounted) return;
      OccupationalAssessmentStore.instance.setLatestAssessment(assessment);

      _planProgress?.removeListener(_refreshPlanState);
      final planProgress = OccupationalPlanProgress(planId: assessment.planId);
      planProgress.addListener(_refreshPlanState);
      await planProgress.load();
      if (!mounted) return;

      widget.onAssessmentComplete?.call(assessment);
      setState(() {
        _result = assessment;
        _planProgress = planProgress;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText =
            'Could not reach the occupational wellness API. Check that the backend is running at ${ApiConfig.instance.baseUrl}.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _answersAreValid() {
    return dutyHoursPerDay >= 4 &&
        dutyHoursPerDay <= 16 &&
        nightDutiesLast2wks >= 0 &&
        nightDutiesLast2wks <= 14 &&
        consecutiveDaysNoRest >= 0 &&
        consecutiveDaysNoRest <= 30 &&
        daysSinceLastLeave >= 0 &&
        daysSinceLastLeave <= 180 &&
        leaveDaysTaken3mo >= 0 &&
        leaveDaysTaken3mo <= 30 &&
        recoveryQuality >= 1 &&
        recoveryQuality <= 5 &&
        familyTime >= 1 &&
        familyTime <= 5 &&
        demand >= 1 &&
        demand <= 5 &&
        control >= 1 &&
        control <= 5 &&
        support >= 1 &&
        support <= 5 &&
        effort >= 1 &&
        effort <= 5 &&
        reward >= 1 &&
        reward <= 5;
  }

  void _resetFields() {
    setState(() {
      dutyHoursPerDay = 8;
      nightDutiesLast2wks = 2;
      consecutiveDaysNoRest = 3;
      daysSinceLastLeave = 20;
      leaveDaysTaken3mo = 5;
      recoveryQuality = 3;
      familyTime = 3;
      demand = 3;
      control = 3;
      support = 3;
      effort = 3;
      reward = 3;
      _result = null;
      _errorText = null;
    });
  }

  void _returnToDashboard() {
    Navigator.pop(context, _result);
  }

  Future<void> _openPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OccupationalWellnessPlanScreen(assessment: _result),
      ),
    );
  }

  Color _riskColor(String? riskLevel) {
    switch (riskLevel) {
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

  String _riskMessage(String riskLevel) {
    switch (riskLevel) {
      case 'Low':
        return 'Current indicators look steady. Keep protective routines visible and repeat the assessment later.';
      case 'Moderate':
        return 'Some occupational stress indicators are present. Focus on prevention and recovery planning.';
      case 'High':
        return 'Several occupational stress indicators are elevated. Treat this as an early signal to prioritize support and recovery.';
      default:
        return 'Complete the questionnaire to view your current assessment.';
    }
  }

  IconData _iconForLabel(String label) {
    final text = label.toLowerCase();
    if (text.contains('workload')) return Icons.work_outline;
    if (text.contains('control')) return Icons.event_note_outlined;
    if (text.contains('support')) return Icons.groups_outlined;
    if (text.contains('effort') || text.contains('reward')) {
      return Icons.balance_outlined;
    }
    if (text.contains('duty hours')) return Icons.schedule_outlined;
    if (text.contains('night')) return Icons.dark_mode_outlined;
    if (text.contains('family') || text.contains('social')) {
      return Icons.family_restroom_outlined;
    }
    if (text.contains('recovery')) return Icons.bedtime_outlined;
    return Icons.tips_and_updates_outlined;
  }

  List<WellnessRecommendation> _recommendations() {
    final result = _result;
    if (result == null) return const [];

    final fromServer = result.recommendationItems
        .map(
          (item) => WellnessRecommendation(
            icon: _iconForLabel(item.label),
            title: item.label,
            body: item.text,
          ),
        )
        .toList();
    final useLocalRules = fromServer.isEmpty;

    final labels = result.contributorLabels
        .map((e) => e.toLowerCase())
        .toList();
    final recommendations = <WellnessRecommendation>[...fromServer];

    bool has(String text) => labels.any((label) => label.contains(text));

    if (useLocalRules && has('workload')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.work_outline,
          title: 'Manage workload pressure',
          body:
              'List the top duty pressure today and identify one practical adjustment, handoff, or recovery window where operationally feasible.',
        ),
      );
    }
    if (useLocalRules && has('low control')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.event_note_outlined,
          title: 'Increase practical control',
          body:
              'Use a short planning check: what can be sequenced, clarified, or discussed before the next duty block?',
        ),
      );
    }
    if (useLocalRules && has('support')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.groups_outlined,
          title: 'Use appropriate support',
          body:
              'Consider a specific check-in with a trusted peer, supervisor, or available wellness channel about the current stressor.',
        ),
      );
    }
    if (useLocalRules && (has('family') || has('social'))) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.family_restroom_outlined,
          title: 'Protect connection time',
          body:
              'Block a small realistic window for family, loved ones, or trusted social contact, even if it has to be brief.',
        ),
      );
    }
    if (useLocalRules && has('effort-reward')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.balance_outlined,
          title: 'Reflect on effort and recognition',
          body:
              'Note where effort feels out of balance and use appropriate organizational channels to clarify expectations or support.',
        ),
      );
    }
    if (useLocalRules && has('recovery')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.bedtime_outlined,
          title: 'Protect recovery time',
          body:
              'Plan one realistic rest block, reduce avoidable stimulation before sleep, and track whether recovery improves this week.',
        ),
      );
    }
    if (useLocalRules && has('long duty')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.schedule_outlined,
          title: 'Plan around extended duty',
          body:
              'After long duty hours, prioritize food, hydration, sleep timing, and a short decompression routine before other tasks.',
        ),
      );
    }
    if (useLocalRules && has('night-shift')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.dark_mode_outlined,
          title: 'Support shift recovery',
          body:
              'Keep the post-shift routine predictable: dim light, reduce interruptions, and reserve a protected sleep window when possible.',
        ),
      );
    }
    if (result.protectiveFactors.isNotEmpty) {
      recommendations.add(
        WellnessRecommendation(
          icon: Icons.shield_outlined,
          title: 'Build on what is working',
          body:
              'Protective factors flagged: ${result.protectiveFactors.join(', ')}. Keep these supports active during the week.',
        ),
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        WellnessRecommendation(
          icon: Icons.spa_outlined,
          title: result.riskLevel == 'Low'
              ? 'Maintain your routine'
              : 'Start with one small action',
          body: result.riskLevel == 'Low'
              ? 'Keep steady recovery, connection, and movement routines in place, then reassess next week.'
              : 'Choose one practical wellness action today and track whether it changes your recovery or workload pressure.',
        ),
      );
    }

    return recommendations.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final recommendations = _recommendations();
    final planDays = buildOccupationalPlanDays(result);

    return Scaffold(
      appBar: VeerMitraAppBar(
        showProfileButton: true,
        extraActions: [
          if (_hasResult)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: _returnToDashboard,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(
                    apiBaseUrl: ApiConfig.instance.baseUrl,
                    isLoading: _isLoading,
                    hasResult: _hasResult,
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final questions = _QuestionnairePanel(
                        questionTexts: _questionTexts,
                        isLoading: _isLoading,
                        dutyHoursPerDay: dutyHoursPerDay,
                        nightDutiesLast2wks: nightDutiesLast2wks,
                        consecutiveDaysNoRest: consecutiveDaysNoRest,
                        daysSinceLastLeave: daysSinceLastLeave,
                        leaveDaysTaken3mo: leaveDaysTaken3mo,
                        recoveryQuality: recoveryQuality,
                        familyTime: familyTime,
                        demand: demand,
                        control: control,
                        support: support,
                        effort: effort,
                        reward: reward,
                        onDutyHoursChanged: (v) =>
                            setState(() => dutyHoursPerDay = v),
                        onNightDutiesChanged: (v) =>
                            setState(() => nightDutiesLast2wks = v),
                        onNoRestChanged: (v) =>
                            setState(() => consecutiveDaysNoRest = v),
                        onLastLeaveChanged: (v) =>
                            setState(() => daysSinceLastLeave = v),
                        onLeaveTakenChanged: (v) =>
                            setState(() => leaveDaysTaken3mo = v),
                        onRecoveryChanged: (v) =>
                            setState(() => recoveryQuality = v),
                        onFamilyChanged: (v) => setState(() => familyTime = v),
                        onDemandChanged: (v) => setState(() => demand = v),
                        onControlChanged: (v) => setState(() => control = v),
                        onSupportChanged: (v) => setState(() => support = v),
                        onEffortChanged: (v) => setState(() => effort = v),
                        onRewardChanged: (v) => setState(() => reward = v),
                      );
                      final resultPanel = _ActionAndResultPanel(
                        isLoading: _isLoading,
                        errorText: _errorText,
                        result: result,
                        riskColor: _riskColor(result?.riskLevel),
                        riskMessage: result == null
                            ? 'Complete the questionnaire to view the current assessment.'
                            : _riskMessage(result.riskLevel),
                        onAssess: _runAssessment,
                        onReset: _resetFields,
                      );

                      if (!wide) {
                        return Column(
                          children: [
                            questions,
                            const SizedBox(height: 18),
                            resultPanel,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: questions),
                          const SizedBox(width: 18),
                          Expanded(flex: 4, child: resultPanel),
                        ],
                      );
                    },
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 18),
                    _RecommendationsPanel(items: recommendations),
                    const SizedBox(height: 18),
                    _WellnessPlanPanel(
                      started: _planProgress!.started,
                      completedDays: _planProgress!.completedDays,
                      days: planDays,
                      onStart: _planProgress!.start,
                      onOpenPlan: _openPlan,
                      onToggleDay: _planProgress!.setDayCompleted,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Disclaimer(text: _disclaimer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WellnessRecommendation {
  final IconData icon;
  final String title;
  final String body;

  const WellnessRecommendation({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _HeaderCard extends StatelessWidget {
  final String apiBaseUrl;
  final bool isLoading;
  final bool hasResult;

  const _HeaderCard({
    required this.apiBaseUrl,
    required this.isLoading,
    required this.hasResult,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Occupational Stress & Wellness Assessment',
                      style: TextStyle(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A focused self-report assessment for duty load, recovery, support, and work stress indicators.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                icon: Icons.list_alt_outlined,
                label: '12 questions',
                color: theme.colorScheme.primary,
              ),
              _StatusPill(
                icon: Icons.psychology_alt_outlined,
                label: hasResult ? 'Assessment ready' : 'Risk calculation model',
                color: AppColors.riskLow,
              ),
              if (isLoading)
                const _StatusPill(
                  icon: Icons.sync,
                  label: 'Running assessment',
                  color: AppColors.saffronAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionnairePanel extends StatelessWidget {
  final Map<int, String> questionTexts;
  final bool isLoading;
  final double dutyHoursPerDay;
  final double nightDutiesLast2wks;
  final double consecutiveDaysNoRest;
  final double daysSinceLastLeave;
  final double leaveDaysTaken3mo;
  final double recoveryQuality;
  final double familyTime;
  final double demand;
  final double control;
  final double support;
  final double effort;
  final double reward;
  final ValueChanged<double> onDutyHoursChanged;
  final ValueChanged<double> onNightDutiesChanged;
  final ValueChanged<double> onNoRestChanged;
  final ValueChanged<double> onLastLeaveChanged;
  final ValueChanged<double> onLeaveTakenChanged;
  final ValueChanged<double> onRecoveryChanged;
  final ValueChanged<double> onFamilyChanged;
  final ValueChanged<double> onDemandChanged;
  final ValueChanged<double> onControlChanged;
  final ValueChanged<double> onSupportChanged;
  final ValueChanged<double> onEffortChanged;
  final ValueChanged<double> onRewardChanged;

  const _QuestionnairePanel({
    required this.questionTexts,
    required this.isLoading,
    required this.dutyHoursPerDay,
    required this.nightDutiesLast2wks,
    required this.consecutiveDaysNoRest,
    required this.daysSinceLastLeave,
    required this.leaveDaysTaken3mo,
    required this.recoveryQuality,
    required this.familyTime,
    required this.demand,
    required this.control,
    required this.support,
    required this.effort,
    required this.reward,
    required this.onDutyHoursChanged,
    required this.onNightDutiesChanged,
    required this.onNoRestChanged,
    required this.onLastLeaveChanged,
    required this.onLeaveTakenChanged,
    required this.onRecoveryChanged,
    required this.onFamilyChanged,
    required this.onDemandChanged,
    required this.onControlChanged,
    required this.onSupportChanged,
    required this.onEffortChanged,
    required this.onRewardChanged,
  });

  String _t(int number, String fallback) => questionTexts[number] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Panel(
      title: '12-Question Assessment',
      subtitle:
          'Self-reported responses for duty workload and occupational experience.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 1,
              minHeight: 6,
              backgroundColor: theme.dividerColor,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Questionnaire ready: 12 of 12 values selected',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.badge_outlined,
            title: 'Duty and recovery context',
            subtitle:
                'Questions regarding your duty load and rest windows.',
          ),
          _RangeQuestionCard(
            number: 1,
            total: 12,
            title: _t(1, 'Hours actively on duty per day'),
            description: 'Use your typical active duty load.',
            value: dutyHoursPerDay,
            min: 4,
            max: 16,
            divisions: 12,
            unit: 'hrs',
            enabled: !isLoading,
            onChanged: onDutyHoursChanged,
          ),
          _RangeQuestionCard(
            number: 2,
            total: 12,
            title: _t(2, 'Night duties or shifts in the last 2 weeks'),
            description: 'Count overnight or late-shift duty blocks.',
            value: nightDutiesLast2wks,
            min: 0,
            max: 14,
            divisions: 14,
            unit: 'shifts',
            enabled: !isLoading,
            onChanged: onNightDutiesChanged,
          ),
          _RangeQuestionCard(
            number: 3,
            total: 12,
            title: _t(3, 'Consecutive days without a full rest day'),
            description: 'Longest current stretch without a full rest day.',
            value: consecutiveDaysNoRest,
            min: 0,
            max: 30,
            divisions: 30,
            unit: 'days',
            enabled: !isLoading,
            onChanged: onNoRestChanged,
          ),
          _RangeQuestionCard(
            number: 4,
            total: 12,
            title: _t(4, 'Days since your last leave or off day'),
            description:
                'Approximate days since meaningful time away from duty.',
            value: daysSinceLastLeave,
            min: 0,
            max: 180,
            divisions: 36,
            unit: 'days',
            enabled: !isLoading,
            onChanged: onLastLeaveChanged,
          ),
          _RangeQuestionCard(
            number: 5,
            total: 12,
            title: _t(5, 'Leave days taken in the last 3 months'),
            description: 'Include sanctioned leave or full off-duty days.',
            value: leaveDaysTaken3mo,
            min: 0,
            max: 30,
            divisions: 30,
            unit: 'days',
            enabled: !isLoading,
            onChanged: onLeaveTakenChanged,
          ),
          _LikertQuestionCard(
            number: 11,
            total: 12,
            title: _t(11, 'Sleep and recovery quality this week'),
            description: 'Rate how restorative your rest has felt.',
            lowLabel: 'Very poor',
            highLabel: 'Excellent',
            value: recoveryQuality,
            enabled: !isLoading,
            onChanged: onRecoveryChanged,
          ),
          _LikertQuestionCard(
            number: 12,
            total: 12,
            title: _t(12, 'Quality time with family or loved ones'),
            description: 'Think about the last 2 weeks.',
            lowLabel: 'None',
            highLabel: 'Plenty',
            value: familyTime,
            enabled: !isLoading,
            onChanged: onFamilyChanged,
          ),
          const SizedBox(height: 8),
          const _SectionHeader(
            icon: Icons.assessment_outlined,
            title: 'Work experience indicators',
            subtitle:
                'Occupational stress constructs evaluated by the assessment model.',
          ),
          _LikertQuestionCard(
            number: 6,
            total: 12,
            title: _t(6, 'How demanding is your current workload?'),
            description: 'Consider pace, volume, and pressure.',
            lowLabel: 'Very light',
            highLabel: 'Very demanding',
            value: demand,
            enabled: !isLoading,
            onChanged: onDemandChanged,
          ),
          _LikertQuestionCard(
            number: 7,
            total: 12,
            title: _t(
              7,
              'How much control do you have over how and when you work?',
            ),
            description: 'Rate your practical say in work timing and methods.',
            lowLabel: 'None',
            highLabel: 'A great deal',
            value: control,
            enabled: !isLoading,
            onChanged: onControlChanged,
          ),
          _LikertQuestionCard(
            number: 8,
            total: 12,
            title: _t(
              8,
              'How supported do you feel by supervisors or organisation?',
            ),
            description: 'Think about practical and emotional support.',
            lowLabel: 'Not at all',
            highLabel: 'Fully',
            value: support,
            enabled: !isLoading,
            onChanged: onSupportChanged,
          ),
          _LikertQuestionCard(
            number: 9,
            total: 12,
            title: _t(9, "Effort required relative to what's expected"),
            description: 'Rate the level of effort your current duty requires.',
            lowLabel: 'Much less',
            highLabel: 'Much more',
            value: effort,
            enabled: !isLoading,
            onChanged: onEffortChanged,
          ),
          _LikertQuestionCard(
            number: 10,
            total: 12,
            title: _t(
              10,
              'How adequately recognised or rewarded is that effort?',
            ),
            description: 'Include recognition, fairness, and perceived return.',
            lowLabel: 'Not at all',
            highLabel: 'Very well',
            value: reward,
            enabled: !isLoading,
            onChanged: onRewardChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionAndResultPanel extends StatelessWidget {
  final bool isLoading;
  final String? errorText;
  final OccupationalAssessmentResult? result;
  final Color riskColor;
  final String riskMessage;
  final VoidCallback onAssess;
  final VoidCallback onReset;

  const _ActionAndResultPanel({
    required this.isLoading,
    required this.errorText,
    required this.result,
    required this.riskColor,
    required this.riskMessage,
    required this.onAssess,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final assessment = result;

    return _Panel(
      title: 'FORCE WELLNESS ASSESSMENT',
      subtitle: 'Current Wellness Risk and score calculated by the model.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const _LoadingState()
          else if (assessment == null)
            const _EmptyResultState()
          else
            _RiskSummaryCard(
              result: assessment,
              color: riskColor,
              message: riskMessage,
            ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            _ErrorState(message: errorText!),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onAssess,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    isLoading ? 'Assessing...' : 'Assess',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onReset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
          if (assessment != null) ...[
            const SizedBox(height: 18),
            _FactorSection(
              title: 'Key Contributors',
              icon: Icons.trending_up,
              color: AppColors.riskHigh,
              items: assessment.modelContributors.map((e) => e.label).toList(),
            ),
            const SizedBox(height: 14),
            _FactorSection(
              title: 'Context Factors',
              icon: Icons.info_outline,
              color: AppColors.riskModerate,
              items: assessment.contextContributors
                  .map((e) => e.label)
                  .toList(),
            ),
            const SizedBox(height: 14),
            _FactorSection(
              title: 'Protective Factors',
              icon: Icons.shield_outlined,
              color: AppColors.riskLow,
              items: assessment.protectiveFactors,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationsPanel extends StatelessWidget {
  final List<WellnessRecommendation> items;

  const _RecommendationsPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recommended Actions',
      subtitle: 'Practical next steps based on the identified contributors.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 760;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: items
                .map(
                  (item) => SizedBox(
                    width: twoColumns
                        ? (constraints.maxWidth - 14) / 2
                        : constraints.maxWidth,
                    child: _RecommendationCard(item: item),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _WellnessPlanPanel extends StatelessWidget {
  final bool started;
  final Set<int> completedDays;
  final List<OccupationalPlanDay> days;
  final VoidCallback onStart;
  final VoidCallback onOpenPlan;
  final Future<void> Function(int day, bool selected) onToggleDay;

  const _WellnessPlanPanel({
    required this.started,
    required this.completedDays,
    required this.days,
    required this.onStart,
    required this.onOpenPlan,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completeCount = completedDays.length;
    final total = days.isEmpty ? 7 : days.length;
    final isMaintain = total < 7;

    return _Panel(
      title: isMaintain ? 'Maintain Plan' : '7-Day Wellness Plan',
      subtitle: 'Interactive wellness actions.',
      trailing: started
          ? Text(
              '$completeCount / $total completed',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: completeCount / total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: theme.dividerColor,
            color: AppColors.riskLow,
          ),
          const SizedBox(height: 16),
          if (!started) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  isMaintain ? 'Start Maintain Plan' : 'Start 7-Day Plan',
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (started) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenPlan,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open 7-Day Wellness Plan'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 760;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: days
                    .map(
                      (day) => SizedBox(
                        width: twoColumns
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth,
                        child: OccupationalPlanDayCard(
                          day: day,
                          enabled: started,
                          completed: completedDays.contains(day.day),
                          onChanged: (value) =>
                              onToggleDay(day.day, value ?? false),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textTheme.titleMedium?.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textTheme.titleMedium?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeQuestionCard extends StatelessWidget {
  final int number;
  final int total;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _RangeQuestionCard({
    required this.number,
    required this.total,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _QuestionCard(
      number: number,
      total: total,
      title: title,
      description: description,
      valueLabel: '${value.round()} $unit',
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: value.round().toString(),
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.dividerColor,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _LikertQuestionCard extends StatelessWidget {
  final int number;
  final int total;
  final String title;
  final String description;
  final String lowLabel;
  final String highLabel;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _LikertQuestionCard({
    required this.number,
    required this.total,
    required this.title,
    required this.description,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _QuestionCard(
      number: number,
      total: total,
      title: title,
      description: description,
      valueLabel: value.round().toString(),
      child: Column(
        children: [
          Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.round().toString(),
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.dividerColor,
            onChanged: enabled ? onChanged : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    lowLabel,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    highLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int number;
  final int total;
  final String title;
  final String description;
  final String valueLabel;
  final Widget child;

  const _QuestionCard({
    required this.number,
    required this.total,
    required this.title,
    required this.description,
    required this.valueLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Question $number of $total',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                constraints: const BoxConstraints(minWidth: 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: textTheme.titleMedium?.color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: TextStyle(
              color: textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RiskSummaryCard extends StatelessWidget {
  final OccupationalAssessmentResult result;
  final Color color;
  final String message;

  const _RiskSummaryCard({
    required this.result,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Wellness Risk',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.riskLevel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Score: ${result.score}',
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ' / 100',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _FactorSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.textTheme.titleMedium?.color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'None flagged',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) =>
                      _ContributorChip(label: item, icon: icon, color: color),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ContributorChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ContributorChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final WellnessRecommendation item;

  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor == AppColors.lightSurfaceCard
            ? AppColors.lightSurfaceMuted
            : AppColors.darkSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: theme.textTheme.titleMedium?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Running the occupational wellness model...',
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
}

class _EmptyResultState extends StatelessWidget {
  const _EmptyResultState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            'Complete the questionnaire and run the assessment.',
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your result will show the current risk level, score, contributors, protective factors, recommendations, and a 7-day plan.',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.riskHigh.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.riskHigh.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.riskHigh, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.riskHigh, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;

  const _Disclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          Icon(
            Icons.privacy_tip_outlined,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
