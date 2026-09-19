class DayUsage {
  final double screenTimeHours;
  final double appSwitchesPerHour;
  final double uniqueAppsPerDay;
  final double socialAppRatio;
  final double workAppRatio;
  final double entertainmentRatio;
  final double wellnessRatio;
  final double sleepHours;
  final double sleepQuality;
  final double exerciseMinPerWeek;
  final double socialHoursPerWeek;
  final double callCount;
  final double missedCallRatio;
  final double smsCount;

  const DayUsage({
    required this.screenTimeHours,
    required this.appSwitchesPerHour,
    required this.uniqueAppsPerDay,
    required this.socialAppRatio,
    required this.workAppRatio,
    required this.entertainmentRatio,
    required this.wellnessRatio,
    required this.sleepHours,
    required this.sleepQuality,
    required this.exerciseMinPerWeek,
    required this.socialHoursPerWeek,
    required this.callCount,
    required this.missedCallRatio,
    required this.smsCount,
  });

  Map<String, dynamic> toJson() => {
    'screen_time_hours': screenTimeHours,
    'app_switches_per_hour': appSwitchesPerHour,
    'unique_apps_per_day': uniqueAppsPerDay,
    'social_app_ratio': socialAppRatio,
    'work_app_ratio': workAppRatio,
    'entertainment_ratio': entertainmentRatio,
    'wellness_ratio': wellnessRatio,
    'sleep_hours': sleepHours,
    'sleep_quality': sleepQuality,
    'exercise_min_per_week': exerciseMinPerWeek,
    'social_hours_per_week': socialHoursPerWeek,
    'call_count': callCount,
    'missed_call_ratio': missedCallRatio,
    'sms_count': smsCount,
  };
}
