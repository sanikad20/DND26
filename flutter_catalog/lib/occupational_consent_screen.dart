import 'package:flutter/material.dart';
import 'occupational_stress_screen.dart';
import 'features/occupational/models/occupational_assessment_result.dart';

class OccupationalConsentScreen extends StatelessWidget {
  final ValueChanged<OccupationalAssessmentResult>? onAssessmentComplete;

  const OccupationalConsentScreen({super.key, this.onAssessmentComplete});

  Widget _point(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 6, color: Colors.white54),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text(
          'Occupational Stress',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before you begin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a short, voluntary self-assessment of occupational '
              'stress — not a medical or psychological evaluation.',
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What we collect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _point(
                      'Your answers to 12 questions about duty hours, recovery, '
                      'workload, control, support, effort and reward.',
                    ),
                    _point(
                      'Your account ID only — never your name, email, rank, or '
                      'unit. Nothing here identifies you to anyone else in your '
                      'organisation.',
                    ),
                    _point(
                      'Your risk result, score, and your raw answers are saved '
                      'to your account so past assessments and re-scoring on a '
                      'future model version are possible.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Where the numbers come from',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _point(
                      'The prediction model was trained on a published, '
                      'peer-reviewed police-occupational-stress dataset — not '
                      'on CAPF-specific data, since none is publicly available. '
                      'Treat this as an early-warning screen, not a diagnosis.',
                    ),
                    _point(
                      'Every explanation you see (which factors mattered, and '
                      'how much) is computed directly from the model\'s own '
                      'math — nothing is invented or approximated after the '
                      'fact.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'What this is not',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _point(
                      'It does not diagnose depression, anxiety, PTSD, or any '
                      'medical or psychological condition.',
                    ),
                    _point(
                      'It is not shared with, or visible to, anyone in your '
                      'chain of command.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _continue(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45199D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'I understand, continue',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
