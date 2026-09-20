import '../../../core/network/api_client.dart';
import '../models/occupational_answers.dart';
import '../models/occupational_assessment_result.dart';
import '../models/occupational_history.dart';

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

  Future<OccupationalHistory> getHistory(String firebaseUid) async {
    final data = await _apiClient.getJson(
      '/occupational/history/$firebaseUid',
      timeout: const Duration(seconds: 30),
    );
    return OccupationalHistory.fromJson(data);
  }
}
