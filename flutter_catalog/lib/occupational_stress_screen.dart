import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'config/api_config.dart';
import 'occupational_wellness_plan.dart';

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
  final OccupationalPlanProgress _planProgress =
      OccupationalPlanProgress.instance;

  @override
  void initState() {
    super.initState();
    _planProgress.addListener(_refreshPlanState);
    _planProgress.load();
  }

  @override
  void dispose() {
    _planProgress.removeListener(_refreshPlanState);
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

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
    final answers = OccupationalAnswers(
      firebaseUid: uid,
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
      await OccupationalAssessmentStore.instance.saveLatestAssessment(
        assessment,
      );
      await _planProgress.resetForNewAssessment();
      if (!mounted) return;
      widget.onAssessmentComplete?.call(assessment);
      setState(() {
        _result = assessment;
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
        return const Color(0xFF3DDC97);
      case 'Moderate':
        return const Color(0xFFFFB020);
      case 'High':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF8A5CE6);
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

  List<WellnessRecommendation> _recommendations() {
    final result = _result;
    if (result == null) return const [];

    final labels = result.contributorLabels
        .map((e) => e.toLowerCase())
        .toList();
    final recommendations = <WellnessRecommendation>[];

    bool has(String text) => labels.any((label) => label.contains(text));

    if (has('workload')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.work_outline,
          title: 'Manage workload pressure',
          body:
              'List the top duty pressure today and identify one practical adjustment, handoff, or recovery window where operationally feasible.',
        ),
      );
    }
    if (has('low control')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.event_note_outlined,
          title: 'Increase practical control',
          body:
              'Use a short planning check: what can be sequenced, clarified, or discussed before the next duty block?',
        ),
      );
    }
    if (has('support')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.groups_outlined,
          title: 'Use appropriate support',
          body:
              'Consider a specific check-in with a trusted peer, supervisor, or available wellness channel about the current stressor.',
        ),
      );
    }
    if (has('family') || has('social')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.family_restroom_outlined,
          title: 'Protect connection time',
          body:
              'Block a small realistic window for family, loved ones, or trusted social contact, even if it has to be brief.',
        ),
      );
    }
    if (has('effort-reward')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.balance_outlined,
          title: 'Reflect on effort and recognition',
          body:
              'Note where effort feels out of balance and use appropriate organizational channels to clarify expectations or support.',
        ),
      );
    }
    if (has('recovery')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.bedtime_outlined,
          title: 'Protect recovery time',
          body:
              'Plan one realistic rest block, reduce avoidable stimulation before sleep, and track whether recovery improves this week.',
        ),
      );
    }
    if (has('long duty')) {
      recommendations.add(
        const WellnessRecommendation(
          icon: Icons.schedule_outlined,
          title: 'Plan around extended duty',
          body:
              'After long duty hours, prioritize food, hydration, sleep timing, and a short decompression routine before other tasks.',
        ),
      );
    }
    if (has('night-shift')) {
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
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Force Wellness Assessment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_hasResult)
            TextButton.icon(
              onPressed: _returnToDashboard,
              icon: const Icon(Icons.dashboard_outlined, color: Colors.white70),
              label: const Text(
                'Dashboard',
                style: TextStyle(color: Colors.white70),
              ),
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
                      started: _planProgress.started,
                      completedDays: _planProgress.completedDays,
                      days: planDays,
                      onStart: _planProgress.start,
                      onOpenPlan: _openPlan,
                      onToggleDay: _planProgress.setDayCompleted,
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
                  color: const Color(0xFF45199D).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Color(0xFFBCA7FF),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Occupational Wellness Check-In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'A focused self-report assessment for duty load, recovery, support, and work stress indicators.',
                      style: TextStyle(color: Colors.white60, height: 1.35),
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
                color: const Color(0xFF8A5CE6),
              ),
              _StatusPill(
                icon: Icons.psychology_alt_outlined,
                label: hasResult ? 'Assessment ready' : 'Model decides risk',
                color: const Color(0xFF3DDC97),
              ),
              _StatusPill(
                icon: Icons.cloud_outlined,
                label: apiBaseUrl,
                color: const Color(0xFFFFB020),
              ),
              if (isLoading)
                const _StatusPill(
                  icon: Icons.sync,
                  label: 'Running assessment',
                  color: Color(0xFFFFB020),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionnairePanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '12-question assessment',
      subtitle:
          'All answers remain self-reported. The backend returns the risk level.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: 1,
              minHeight: 8,
              backgroundColor: Colors.white10,
              color: Color(0xFF8A5CE6),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Questionnaire ready: 12 of 12 values selected',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.badge_outlined,
            title: 'Duty and recovery context',
            subtitle:
                'These questions personalize explanations and practical wellness guidance.',
          ),
          _RangeQuestionCard(
            number: 1,
            total: 12,
            title: 'Hours actively on duty per day',
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
            title: 'Night duties or shifts in the last 2 weeks',
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
            title: 'Consecutive days without a full rest day',
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
            title: 'Days since your last leave or off day',
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
            title: 'Leave days taken in the last 3 months',
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
            title: 'Sleep and recovery quality this week',
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
            title: 'Quality time with family or loved ones',
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
                'These map to validated police occupational-stress constructs used by the backend model.',
          ),
          _LikertQuestionCard(
            number: 6,
            total: 12,
            title: 'How demanding is your current workload?',
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
            title: 'How much control do you have over how and when you work?',
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
            title: 'How supported do you feel by supervisors or organisation?',
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
            title: "Effort required relative to what's expected",
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
            title: 'How adequately recognised or rewarded is that effort?',
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
      title: 'Current assessment',
      subtitle: 'Risk level and score come directly from the FastAPI model.',
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
                          color: Colors.white,
                        ),
                  label: Text(
                    isLoading ? 'Assessing...' : 'Assess',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF45199D),
                    disabledBackgroundColor: const Color(0xFF2D2450),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onReset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (assessment != null) ...[
            const SizedBox(height: 18),
            _FactorSection(
              title: 'Main contributors',
              icon: Icons.trending_up,
              color: const Color(0xFFFF6B6B),
              items: assessment.modelContributors.map((e) => e.label).toList(),
            ),
            const SizedBox(height: 14),
            _FactorSection(
              title: 'Context factors',
              icon: Icons.info_outline,
              color: const Color(0xFFFFB020),
              items: assessment.contextContributors
                  .map((e) => e.label)
                  .toList(),
            ),
            const SizedBox(height: 14),
            _FactorSection(
              title: 'Protective factors',
              icon: Icons.shield_outlined,
              color: const Color(0xFF3DDC97),
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
      title: 'Wellness recommendations',
      subtitle: 'Practical next steps based on the latest contributors.',
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
  final Future<void> Function() onStart;
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
    final completeCount = completedDays.length;
    return _Panel(
      title: '7-day wellness plan',
      subtitle: 'Completion is local for now. Day 4 can persist this state.',
      trailing: started
          ? Text(
              '$completeCount / 7 completed',
              style: const TextStyle(color: Colors.white70),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: completeCount / 7,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white10,
            color: const Color(0xFF3DDC97),
          ),
          const SizedBox(height: 16),
          if (!started) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                ),
                label: const Text(
                  'Start 7-Day Plan',
                  style: TextStyle(color: Colors.white),
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
            const SizedBox(height: 14),
          ],
          if (started) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenPlan,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Full Plan'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white54,
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
          const SizedBox(height: 18),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFBCA7FF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
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
        activeColor: const Color(0xFF8A5CE6),
        inactiveColor: Colors.white12,
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
            activeColor: const Color(0xFF8A5CE6),
            inactiveColor: Colors.white12,
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
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    highLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF23213A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Question $number of $total',
                  style: const TextStyle(
                    color: Color(0xFFBCA7FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                constraints: const BoxConstraints(minWidth: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Occupational Wellness Risk',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  result.riskLevel,
                  style: TextStyle(
                    color: color,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${result.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  ' / 100',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.42),
          ),
          const SizedBox(height: 12),
          Text(
            'Model: ${result.modelVersion}  |  Real model scoring: ${!result.placeholderScoring}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        if (items.isEmpty)
          const Text(
            'None flagged',
            style: TextStyle(color: Colors.white38, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontSize: 13)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: const Color(0xFFBCA7FF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Color(0xFFBCA7FF),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Running the occupational wellness model...',
              style: TextStyle(color: Colors.white70, height: 1.4),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_outlined, color: Color(0xFFBCA7FF)),
          SizedBox(height: 10),
          Text(
            'Complete the questionnaire and run the assessment.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Your result will show the current risk level, score, contributors, protective factors, recommendations, and a 7-day plan.',
            style: TextStyle(color: Colors.white54, height: 1.4),
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
        color: const Color(0xFF2A1515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, height: 1.4),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: Colors.white38,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white54,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
