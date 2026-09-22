import 'package:flutter/material.dart';
import 'occupational_stress_screen.dart';
import 'features/occupational/models/occupational_assessment_result.dart';
import 'widgets/veer_mitra_app_bar.dart';

class OccupationalConsentScreen extends StatelessWidget {
  final ValueChanged<OccupationalAssessmentResult>? onAssessmentComplete;

  const OccupationalConsentScreen({super.key, this.onAssessmentComplete});

  Widget _point(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 6, color: theme.colorScheme.tertiary),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue(BuildContext context) async {
    final result = await Navigator.push<OccupationalAssessmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OccupationalStressScreen(onAssessmentComplete: onAssessmentComplete),
      ),
    );
    if (context.mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: const VeerMitraAppBar(
        showProfileButton: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you begin',
                style: TextStyle(
                  color: textTheme.titleLarge?.color,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Occupational Stress & Wellness Assessment — a short, voluntary self-assessment of workload and recovery indicators.',
                style: TextStyle(
                  color: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What we collect',
                          style: TextStyle(
                            color: textTheme.titleMedium?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _point(
                          context,
                          'Your answers to 12 questions about duty hours, recovery, workload, control, support, effort and reward.',
                        ),
                        _point(
                          context,
                          'Your account ID only — never your name, email, rank, or unit. Nothing here identifies you to anyone else in your organisation.',
                        ),
                        _point(
                          context,
                          'Your risk result, score, and your raw answers are saved to your account so past assessments and re-scoring on a future model version are possible.',
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Where the numbers come from',
                          style: TextStyle(
                            color: textTheme.titleMedium?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _point(
                          context,
                          'The prediction model was trained on a published, peer-reviewed police-occupational-stress dataset. Treat this as an early-warning screen, not a diagnosis.',
                        ),
                        _point(
                          context,
                          'Every explanation you see (which factors mattered, and how much) is computed directly from the model\'s own math — nothing is invented or approximated after the fact.',
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'What this is not',
                          style: TextStyle(
                            color: textTheme.titleMedium?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _point(
                          context,
                          'It does not diagnose depression, anxiety, PTSD, or any medical or psychological condition.',
                        ),
                        _point(
                          context,
                          'It is not shared with, or visible to, anyone in your chain of command.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _continue(context),
                  child: const Text(
                    'I understand, continue',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Not now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
