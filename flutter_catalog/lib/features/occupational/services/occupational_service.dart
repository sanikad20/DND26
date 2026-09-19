import '../../../core/network/api_client.dart';
import '../models/occupational_answers.dart';
import '../models/occupational_assessment_result.dart';

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
}
