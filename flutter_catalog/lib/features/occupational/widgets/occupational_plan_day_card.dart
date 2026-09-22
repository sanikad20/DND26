import 'package:flutter/material.dart';
import '../models/occupational_plan_day.dart';
import '../../../theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.65,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? AppColors.greenAccent.withValues(alpha: 0.12) : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? AppColors.greenAccent.withValues(alpha: 0.5)
                : theme.dividerColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: completed,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.greenAccent,
              side: BorderSide(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.day} — ${day.title}',
                    style: TextStyle(
                      color: completed ? (isDark ? AppColors.greenLight : AppColors.greenAccent) : primaryTextColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.explanation,
                    style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4),
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
                                ? (isDark ? AppColors.greenLight : AppColors.greenAccent)
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 13,
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
