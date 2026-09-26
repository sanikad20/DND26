export 'features/burnout/models/burnout_result.dart';
export 'features/burnout/models/day_usage.dart';
export 'features/occupational/models/occupational_answers.dart';
export 'features/occupational/models/occupational_assessment_result.dart';
export 'features/occupational/models/occupational_history.dart';
export 'features/organizational/models/organizational_models.dart';
export 'features/organizational/services/organizational_service.dart';

import 'features/burnout/models/burnout_result.dart';
import 'features/burnout/models/day_usage.dart';
import 'features/burnout/services/burnout_service.dart';
import 'features/occupational/models/occupational_answers.dart';
import 'features/occupational/models/occupational_assessment_result.dart';
import 'features/occupational/models/occupational_history.dart';
import 'features/occupational/services/occupational_service.dart';
import 'features/organizational/models/organizational_models.dart';
import 'features/organizational/services/organizational_service.dart';

class ApiService {
  ApiService._()
    : _burnoutService = BurnoutService(),
      _occupationalService = OccupationalService(),
      _organizationalService = OrganizationalService();

  static final ApiService instance = ApiService._();

  final BurnoutService _burnoutService;
  final OccupationalService _occupationalService;
  final OrganizationalService _organizationalService;

  OrganizationalService get organizational => _organizationalService;

  Future<BurnoutResult> predictManual(DayUsage day) {
    return _burnoutService.predictManual(day);
  }

  Future<BurnoutResult> predictLSTM({
    required List<DayUsage> pastDays,
    required DayUsage today,
  }) {
    return _burnoutService.predictLSTM(pastDays: pastDays, today: today);
  }

  Future<OccupationalAssessmentResult> assessOccupational(
    OccupationalAnswers answers,
  ) {
    return _occupationalService.assess(answers);
  }

  Future<Map<int, String>> getOccupationalQuestionTexts() {
    return _occupationalService.getQuestionTexts();
  }

  Future<OccupationalHistory> getOccupationalHistory([String? firebaseUid]) {
    return _occupationalService.getHistory(firebaseUid);
  }

  Future<UserProfileRole> getMyRole() {
    return _organizationalService.getMyRole();
  }

  Future<UserProfileRole> switchRole(String newRole) {
    return _organizationalService.switchRole(newRole);
  }

  Future<UserProfileRole> updateOptIn(bool optIn) {
    return _organizationalService.updateOptIn(optIn);
  }
}
