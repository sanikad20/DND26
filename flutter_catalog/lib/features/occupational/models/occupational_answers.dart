class OccupationalAnswers {
  final String firebaseUid;
  final double dutyHoursPerDay;
  final double nightDutiesLast2wks;
  final double consecutiveDaysNoRest;
  final double daysSinceLastLeave;
  final double leaveDaysTaken3mo;
  final int recoveryQuality;
  final int familyTime;
  final int demand;
  final int control;
  final int support;
  final int effort;
  final int reward;

  const OccupationalAnswers({
    required this.firebaseUid,
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
  });

  Map<String, dynamic> toJson() => {
    'firebase_uid': firebaseUid,
    'duty_hours_per_day': dutyHoursPerDay,
    'night_duties_last_2wks': nightDutiesLast2wks,
    'consecutive_days_no_rest': consecutiveDaysNoRest,
    'days_since_last_leave': daysSinceLastLeave,
    'leave_days_taken_3mo': leaveDaysTaken3mo,
    'recovery_quality': recoveryQuality,
    'family_time': familyTime,
    'demand': demand,
    'control': control,
    'support': support,
    'effort': effort,
    'reward': reward,
  };
}
