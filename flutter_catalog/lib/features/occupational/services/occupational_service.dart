import '../../../core/network/api_client.dart';
import '../models/occupational_answers.dart';
import '../models/occupational_assessment_result.dart';
import '../models/occupational_history.dart';
import '../models/occupational_plan_progress_response.dart';

class OccupationalService {
  OccupationalService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<OccupationalAssessmentResult> assess(
    OccupationalAnswers answers,
  ) async {
    final data = await _apiClient.postJson(
      '/occupational/assess',
      answers.toJson(),
      timeout: const Duration(seconds: 60),
    );
    return OccupationalAssessmentResult.fromJson(data);
  }

  /// Question wording from the server, keyed by question number (1-12), so
  /// wording can be edited without an app release.
  Future<Map<int, String>> getQuestionTexts() async {
    final data = await _apiClient.getJson(
      '/occupational/questionnaire',
      timeout: const Duration(seconds: 15),
    );
    final texts = <int, String>{};
    for (final item in (data['questions'] as List<dynamic>? ?? [])) {
      if (item is Map<String, dynamic>) {
        final id = int.tryParse(item['id'].toString());
        final text = item['text']?.toString();
        if (id != null && text != null && text.isNotEmpty) {
          texts[id] = text;
        }
      }
    }
    return texts;
  }

  Future<OccupationalHistory> getHistory() async {
    final data = await _apiClient.getJson(
      '/occupational/history',
      timeout: const Duration(seconds: 30),
    );
    return OccupationalHistory.fromJson(data);
  }

  /// Fetches per-day completion state for a specific plan (one plan per
  /// assessment - see AssessmentResult.planId).
  Future<OccupationalPlanProgressResponse> getPlanProgress(int planId) async {
    final data = await _apiClient.getJson(
      '/occupational/plans/$planId/progress',
      timeout: const Duration(seconds: 15),
    );
    return OccupationalPlanProgressResponse.fromJson(data);
  }

  /// Marks a single day of a specific plan complete/incomplete. Scoped to
  /// planId so toggling a day on one assessment's plan never touches any
  /// other assessment's plan.
  Future<void> setPlanDayCompleted(
    int planId,
    int dayNumber,
    bool completed,
  ) async {
    await _apiClient.postJson('/occupational/plans/$planId/progress', {
      'day_number': dayNumber,
      'completed': completed,
    }, timeout: const Duration(seconds: 15));
  }
}
