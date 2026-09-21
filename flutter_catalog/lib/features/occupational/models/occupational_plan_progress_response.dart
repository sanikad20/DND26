class OccupationalDayProgress {
  final int dayNumber;
  final bool completed;
  final DateTime? completedAt;

  const OccupationalDayProgress({
    required this.dayNumber,
    required this.completed,
    this.completedAt,
  });

  factory OccupationalDayProgress.fromJson(Map<String, dynamic> data) {
    return OccupationalDayProgress(
      dayNumber: int.tryParse(data['day_number'].toString()) ?? 0,
      completed: data['completed'] == true,
      completedAt: data['completed_at'] == null
          ? null
          : DateTime.tryParse(data['completed_at'].toString()),
    );
  }
}

class OccupationalPlanProgressResponse {
  final int planId;
  final List<OccupationalDayProgress> days;

  const OccupationalPlanProgressResponse({
    required this.planId,
    required this.days,
  });

  factory OccupationalPlanProgressResponse.fromJson(Map<String, dynamic> data) {
    final days = (data['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(OccupationalDayProgress.fromJson)
        .toList();
    return OccupationalPlanProgressResponse(
      planId: int.tryParse(data['plan_id'].toString()) ?? 0,
      days: days,
    );
  }

  Set<int> get completedDayNumbers => days
      .where((d) => d.completed)
      .map((d) => d.dayNumber)
      .toSet();
}
