import '../models/occupational_assessment_result.dart';
import '../models/occupational_plan_day.dart';

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
