import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_catalog/config/api_config.dart';
// ─── Day usage model ──────────────────────────────────────────────────────────

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

// ─── Results ──────────────────────────────────────────────────────────────────

class BurnoutResult {
  final double score;
  final String level;
  final String source;
  final Map<String, double>? personalBaseline;
  final Map<String, double>? todayVsBaseline;

  const BurnoutResult({
    required this.score,
    required this.level,
    required this.source,
    this.personalBaseline,
    this.todayVsBaseline,
  });
}

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

class OccupationalFactor {
  final String label;
  final String layer;

  const OccupationalFactor({required this.label, required this.layer});

  factory OccupationalFactor.fromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return OccupationalFactor(
        label: value['label']?.toString() ?? 'Unknown factor',
        layer: value['layer']?.toString() ?? '',
      );
    }
    return OccupationalFactor(label: value.toString(), layer: '');
  }
}

class OccupationalAssessmentResult {
  final String riskLevel;
  final int score;
  final List<OccupationalFactor> modelContributors;
  final List<OccupationalFactor> contextContributors;
  final List<String> protectiveFactors;
  final String modelVersion;
  final bool placeholderScoring;
  final DateTime generatedAt;

  const OccupationalAssessmentResult({
    required this.riskLevel,
    required this.score,
    required this.modelContributors,
    required this.contextContributors,
    required this.protectiveFactors,
    required this.modelVersion,
    required this.placeholderScoring,
    required this.generatedAt,
  });

  factory OccupationalAssessmentResult.fromJson(Map<String, dynamic> data) {
    final modelItems = (data['model_contributors'] as List<dynamic>? ?? [])
        .map(OccupationalFactor.fromJson)
        .toList();
    final contextItems = (data['context_contributors'] as List<dynamic>? ?? [])
        .map(OccupationalFactor.fromJson)
        .toList();
    final protectiveItems = (data['protective_factors'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();

    return OccupationalAssessmentResult(
      riskLevel: data['risk_level']?.toString() ?? 'Unknown',
      score: int.tryParse(data['score'].toString()) ?? 0,
      modelContributors: modelItems,
      contextContributors: contextItems,
      protectiveFactors: protectiveItems,
      modelVersion: data['model_version']?.toString() ?? '',
      placeholderScoring: data['placeholder_scoring'] == true,
      generatedAt:
          DateTime.tryParse(data['generated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  List<String> get contributorLabels => [
    ...modelContributors.map((item) => item.label),
    ...contextContributors.map((item) => item.label),
  ];
}

// ─── API Service ──────────────────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Reads URL from ApiConfig (set by user in settings, persisted in prefs)
  String get _base => ApiConfig.instance.baseUrl;

  // ── Manual PyTorch /predict ───────────────────────────────────────────────
  Future<BurnoutResult> predictManual(DayUsage day) async {
    final response = await http
        .post(
          Uri.parse('$_base/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sleep_hours': day.sleepHours,
            'sleep_quality': day.sleepQuality,
            'app_switches_per_hour': day.appSwitchesPerHour,
            'social_app_ratio': day.socialAppRatio,
            'productivity_ratio': day.workAppRatio,
            'unique_apps_per_day': day.uniqueAppsPerDay,
            'call_count': day.callCount,
            'total_call_min': day.callCount * 5.0,
            'missed_call_ratio': day.missedCallRatio,
            'sms_count': day.smsCount,
            'sms_sent_ratio': 0.5,
            'screen_time_hours': day.screenTimeHours,
            'exercise_min_per_week': day.exerciseMinPerWeek,
            'social_hours_per_week': day.socialHoursPerWeek,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BurnoutResult(
        score: double.parse(data['prediction'].toString()),
        level: data['stress_level'].toString(),
        source: 'Manual',
      );
    }
    throw Exception('/predict error ${response.statusCode}: ${response.body}');
  }

  // ── LSTM /predict_lstm ────────────────────────────────────────────────────
  Future<BurnoutResult> predictLSTM({
    required List<DayUsage> pastDays,
    required DayUsage today,
  }) async {
    if (pastDays.length != 7) {
      throw Exception(
        'predictLSTM needs exactly 7 past days, got ${pastDays.length}',
      );
    }

    final body = {
      'history': pastDays.map((d) => d.toJson()).toList(),
      'today': today.toJson(),
    };

    final response = await http.post(
      Uri.parse('$_base/predict_lstm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final pb = (data['user_baseline'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, double.parse(v.toString())),
      );
      final tvb = (data['today_vs_baseline'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, double.parse(v.toString())),
      );

      return BurnoutResult(
        score: double.parse(data['prediction'].toString()),
        level: data['stress_level'].toString(),
        source: 'LSTM',
        personalBaseline: pb,
        todayVsBaseline: tvb,
      );
    }
    throw Exception(
      '/predict_lstm error ${response.statusCode}: ${response.body}',
    );
  }

  Future<OccupationalAssessmentResult> assessOccupational(
    OccupationalAnswers answers,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_base/occupational/assess'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(answers.toJson()),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OccupationalAssessmentResult.fromJson(data);
    }
    throw Exception(
      '/occupational/assess error ${response.statusCode}: ${response.body}',
    );
  }
}
