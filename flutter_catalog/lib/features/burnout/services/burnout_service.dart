import '../../../core/network/api_client.dart';
import '../models/burnout_result.dart';
import '../models/day_usage.dart';

class BurnoutService {
  BurnoutService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<BurnoutResult> predictManual(DayUsage day) async {
    final data = await _apiClient.postJson('/predict', {
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
    });

    return BurnoutResult(
      score: double.parse(data['prediction'].toString()),
      level: data['stress_level'].toString(),
      source: 'Manual',
    );
  }

  Future<BurnoutResult> predictLSTM({
    required List<DayUsage> pastDays,
    required DayUsage today,
  }) async {
    if (pastDays.length != 7) {
      throw ApiException(
        'predictLSTM needs exactly 7 past days, got ${pastDays.length}',
      );
    }

    final data = await _apiClient.postJson('/predict_lstm', {
      'history': pastDays.map((day) => day.toJson()).toList(),
      'today': today.toJson(),
    });

    final personalBaseline = (data['user_baseline'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, double.parse(value.toString())));
    final todayVsBaseline = (data['today_vs_baseline'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, double.parse(value.toString())));

    return BurnoutResult(
      score: double.parse(data['prediction'].toString()),
      level: data['stress_level'].toString(),
      source: 'LSTM',
      personalBaseline: personalBaseline,
      todayVsBaseline: todayVsBaseline,
    );
  }
}
