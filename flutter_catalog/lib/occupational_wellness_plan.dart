import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class OccupationalAssessmentStore {
  OccupationalAssessmentStore._();

  static final OccupationalAssessmentStore instance =
      OccupationalAssessmentStore._();

  static const _latestAssessmentKey = 'occupational_latest_assessment';

  OccupationalAssessmentResult? _latestAssessment;

  OccupationalAssessmentResult? get latestAssessment => _latestAssessment;

  Future<OccupationalAssessmentResult?> loadLatestAssessment() async {
    if (_latestAssessment != null) return _latestAssessment;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestAssessmentKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _latestAssessment = OccupationalAssessmentResult.fromJson(data);
      return _latestAssessment;
    } catch (_) {
      await prefs.remove(_latestAssessmentKey);
      return null;
    }
  }

  Future<void> saveLatestAssessment(OccupationalAssessmentResult result) async {
    _latestAssessment = result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latestAssessmentKey, jsonEncode(result.toJson()));
  }
}

class OccupationalPlanProgress extends ChangeNotifier {
  OccupationalPlanProgress._();

  static final OccupationalPlanProgress instance = OccupationalPlanProgress._();

  static const _startedKey = 'occupational_plan_started';
  static const _completedDaysKey = 'occupational_plan_completed_days';

  bool _loaded = false;
  bool _started = false;
  final Set<int> _completedDays = {};

  bool get started => _started;
  Set<int> get completedDays => Set.unmodifiable(_completedDays);
  int get completedCount => _completedDays.length;
  double get progress => completedCount / 7;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _started = prefs.getBool(_startedKey) ?? false;
    _completedDays
      ..clear()
      ..addAll(
        (prefs.getStringList(_completedDaysKey) ?? const [])
            .map(int.tryParse)
            .whereType<int>()
            .where((day) => day >= 1 && day <= 7),
      );
    _loaded = true;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    notifyListeners();
    await _save();
  }

  Future<void> resetForNewAssessment() async {
    _started = false;
    _completedDays.clear();
    _loaded = true;
    notifyListeners();
    await _save();
  }

  Future<void> setDayCompleted(int day, bool completed) async {
    if (day < 1 || day > 7) return;
    if (!_started) _started = true;
    final changed = completed
        ? _completedDays.add(day)
        : _completedDays.remove(day);
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  int nextOpenDay() {
    for (var day = 1; day <= 7; day++) {
      if (!_completedDays.contains(day)) return day;
    }
    return 7;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startedKey, _started);
    await prefs.setStringList(
      _completedDaysKey,
      _completedDays.map((day) => day.toString()).toList()..sort(),
    );
  }
}

class OccupationalPlanDay {
  final int day;
  final String title;
  final String explanation;
  final List<String> tasks;

  const OccupationalPlanDay({
    required this.day,
    required this.title,
    required this.explanation,
    required this.tasks,
  });
}

List<OccupationalPlanDay> buildOccupationalPlanDays(
  OccupationalAssessmentResult? result,
) {
  final labels = result?.contributorLabels.join(' ').toLowerCase() ?? '';
  final recoveryFocus =
      labels.contains('recovery') ||
      labels.contains('night') ||
      labels.contains('long duty');
  final supportFocus = labels.contains('support') || labels.contains('family');
  final lowControlFocus = labels.contains('control');
  final workloadFocus =
      labels.contains('workload') ||
      labels.contains('demand') ||
      labels.contains('effort');
  final rewardFocus = labels.contains('reward');

  return [
    OccupationalPlanDay(
      day: 1,
      title: 'Reset & Recover',
      explanation: recoveryFocus
          ? 'Start by protecting the next realistic recovery window.'
          : 'Begin with a simple reset so the plan feels manageable.',
      tasks: const [
        'Take a two-minute check of energy, hydration, and sleep pressure.',
        'Choose one protected rest or decompression window today.',
      ],
    ),
    OccupationalPlanDay(
      day: 2,
      title: 'Improve Recovery',
      explanation:
          'A predictable wind-down can make recovery easier after duty pressure.',
      tasks: const [
        'Use one pre-sleep cue such as dim light, reduced phone use, or quiet breathing.',
        'Keep caffeine and high-stimulation tasks away from the chosen rest window where possible.',
      ],
    ),
    OccupationalPlanDay(
      day: 3,
      title: 'Manage Workload',
      explanation: workloadFocus
          ? 'Focus on one pressure point that can be clarified, sequenced, or discussed.'
          : 'Keep workload visible before it becomes harder to manage.',
      tasks: const [
        'Write the top work pressure for today in one sentence.',
        'Identify one next action: clarify, sequence, hand off, or pause for recovery.',
      ],
    ),
    OccupationalPlanDay(
      day: 4,
      title: 'Build Support',
      explanation: supportFocus
          ? 'Low support signals are easier to act on when the request is specific.'
          : 'Connection helps keep protective factors active during demanding weeks.',
      tasks: const [
        'Check in with one trusted peer, family member, supervisor, or support channel.',
        'Ask for one practical thing if support is needed.',
      ],
    ),
    OccupationalPlanDay(
      day: 5,
      title: 'Regain Control',
      explanation: lowControlFocus
          ? 'Small control points can reduce the feeling that the day is running you.'
          : 'Use a short planning loop to make the next duty block clearer.',
      tasks: const [
        'List what is fixed and what is flexible in the next duty block.',
        'Choose one flexible item to plan, clarify, or simplify.',
      ],
    ),
    OccupationalPlanDay(
      day: 6,
      title: 'Recharge',
      explanation: rewardFocus
          ? 'Effort-reward imbalance needs boundaries and awareness, not self-blame.'
          : 'A short recharge routine helps carry the plan into the final day.',
      tasks: const [
        'Do a short walk, stretch, breathing, prayer, mindfulness, or quiet decompression activity.',
        'Name one effort from this week that deserves recognition.',
      ],
    ),
    const OccupationalPlanDay(
      day: 7,
      title: 'Reflect & Continue',
      explanation:
          'Close the week by noticing what helped and what still needs attention.',
      tasks: [
        'Review which plan actions were realistic.',
        'Pick one routine to continue next week.',
        'Retake the assessment later if you want a fresh current-risk snapshot.',
      ],
    ),
  ];
}

class OccupationalWellnessPlanScreen extends StatefulWidget {
  final OccupationalAssessmentResult? assessment;

  const OccupationalWellnessPlanScreen({super.key, this.assessment});

  @override
  State<OccupationalWellnessPlanScreen> createState() =>
      _OccupationalWellnessPlanScreenState();
}

class _OccupationalWellnessPlanScreenState
    extends State<OccupationalWellnessPlanScreen> {
  final OccupationalPlanProgress _progress = OccupationalPlanProgress.instance;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_refresh);
    _progress.load();
  }

  @override
  void dispose() {
    _progress.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final days = buildOccupationalPlanDays(widget.assessment);
    final nextDay = _progress.nextOpenDay();
    final riskLevel = widget.assessment?.riskLevel ?? 'Assessment pending';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '7-Day Wellness Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                  _PlanHeader(
                    completed: _progress.completedCount,
                    started: _progress.started,
                    riskLevel: riskLevel,
                    onStart: _progress.start,
                    onNext: () => _progress.setDayCompleted(nextDay, true),
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
                          final completed = _progress.completedDays.contains(
                            day.day,
                          );
                          return SizedBox(
                            width: twoColumns
                                ? (constraints.maxWidth - 14) / 2
                                : constraints.maxWidth,
                            child: OccupationalPlanDayCard(
                              day: day,
                              enabled: _progress.started,
                              completed: completed,
                              onChanged: (value) => _progress.setDayCompleted(
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final int completed;
  final bool started;
  final String riskLevel;
  final int nextDay;
  final VoidCallback onStart;
  final VoidCallback onNext;

  const _PlanHeader({
    required this.completed,
    required this.started,
    required this.riskLevel,
    required this.nextDay,
    required this.onStart,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = completed >= 7;
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
                    const Text(
                      'Interactive 7-day wellness plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current risk context: $riskLevel. Progress is stored locally on this device.',
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
            value: completed / 7,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white10,
            color: const Color(0xFF3DDC97),
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / 7 days completed',
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
            ],
          ),
        ],
      ),
    );
  }
}

class OccupationalPlanDayCard extends StatelessWidget {
  final OccupationalPlanDay day;
  final bool enabled;
  final bool completed;
  final ValueChanged<bool?> onChanged;

  const OccupationalPlanDayCard({
    super.key,
    required this.day,
    required this.enabled,
    required this.completed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.62,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFF10251E) : const Color(0xFF101116),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completed
                ? const Color(0xFF3DDC97).withValues(alpha: 0.45)
                : Colors.white10,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: completed,
              onChanged: enabled ? onChanged : null,
              activeColor: const Color(0xFF3DDC97),
              side: const BorderSide(color: Colors.white38),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.day} - ${day.title}',
                    style: TextStyle(
                      color: completed ? const Color(0xFF9CF0CC) : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day.explanation,
                    style: const TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  ...day.tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: completed
                                ? const Color(0xFF3DDC97)
                                : Colors.white30,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
