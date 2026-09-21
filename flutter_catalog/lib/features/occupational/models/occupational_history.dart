class OccupationalHistoryPoint {
  final int id;
  final DateTime timestamp;
  final int score;
  final String riskLevel;
  /// null only for assessments saved before wellness_plans existed.
  final int? planId;

  const OccupationalHistoryPoint({
    required this.id,
    required this.timestamp,
    required this.score,
    required this.riskLevel,
    this.planId,
  });

  factory OccupationalHistoryPoint.fromJson(Map<String, dynamic> data) {
    return OccupationalHistoryPoint(
      id: int.tryParse(data['id'].toString()) ?? 0,
      timestamp:
          DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      score: int.tryParse(data['score'].toString()) ?? 0,
      riskLevel: data['risk_level']?.toString() ?? 'Unknown',
      planId: data['plan_id'] == null
          ? null
          : int.tryParse(data['plan_id'].toString()),
    );
  }
}

class OccupationalHistory {
  final String firebaseUid;
  final List<OccupationalHistoryPoint> assessments;
  final String trend; // Improving | Stable | Worsening | Not enough data
  final String modelVersion;
  final bool placeholderData;

  const OccupationalHistory({
    required this.firebaseUid,
    required this.assessments,
    required this.trend,
    required this.modelVersion,
    required this.placeholderData,
  });

  factory OccupationalHistory.fromJson(Map<String, dynamic> data) {
    final points = (data['assessments'] as List<dynamic>? ?? [])
        .map((e) => OccupationalHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return OccupationalHistory(
      firebaseUid: data['firebase_uid']?.toString() ?? '',
      assessments: points,
      trend: data['trend']?.toString() ?? 'Not enough data',
      modelVersion: data['model_version']?.toString() ?? '',
      placeholderData: data['placeholder_data'] == true,
    );
  }

  bool get hasEnoughForChart => assessments.length >= 2;
}
