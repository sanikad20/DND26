import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';
import '../models/occupational_answers.dart';
import '../models/occupational_assessment_result.dart';
import '../models/occupational_history.dart';
import '../models/occupational_plan_progress_response.dart';

class OccupationalService {
  OccupationalService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, String>> _authHeaders({bool required = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (required) {
        throw const ApiException(
          'Please sign in to access occupational wellness.',
        );
      }
      return const {};
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      if (required) {
        throw const ApiException(
          'Unable to obtain Firebase authorization token. Please sign in again.',
        );
      }
      return const {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<OccupationalAssessmentResult> assess(
    OccupationalAnswers answers,
  ) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.postJson(
      '/occupational/assess',
      answers.toJson(),
      headers: headers,
      timeout: const Duration(seconds: 60),
    );
    return OccupationalAssessmentResult.fromJson(data);
  }

  /// Question wording from the server, keyed by question number (1-12), so
  /// wording can be edited without an app release.
  Future<Map<int, String>> getQuestionTexts() async {
    final headers = await _authHeaders(required: false);
    final data = await _apiClient.getJson(
      '/occupational/questionnaire',
      headers: headers.isNotEmpty ? headers : null,
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

  Future<OccupationalHistory> getHistory([String? firebaseUid]) async {
    final headers = await _authHeaders(required: true);
    final uid = firebaseUid ?? FirebaseAuth.instance.currentUser?.uid;
    final path = (uid != null && uid.isNotEmpty)
        ? '/occupational/history/$uid'
        : '/occupational/history';
    final data = await _apiClient.getJson(
      path,
      headers: headers,
      timeout: const Duration(seconds: 30),
    );
    return OccupationalHistory.fromJson(data);
  }

  /// Fetches per-day completion state for a specific plan (one plan per
  /// assessment - see AssessmentResult.planId).
  Future<OccupationalPlanProgressResponse> getPlanProgress(int planId) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.getJson(
      '/occupational/plans/$planId/progress',
      headers: headers,
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
    final headers = await _authHeaders(required: true);
    await _apiClient.postJson(
      '/occupational/plans/$planId/progress',
      {
        'day_number': dayNumber,
        'completed': completed,
      },
      headers: headers,
      timeout: const Duration(seconds: 15),
    );
  }
}
