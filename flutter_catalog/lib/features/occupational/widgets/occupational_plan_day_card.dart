import 'package:flutter/material.dart';

import '../models/occupational_plan_day.dart';

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
