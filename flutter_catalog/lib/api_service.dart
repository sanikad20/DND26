export 'features/burnout/models/burnout_result.dart';
export 'features/burnout/models/day_usage.dart';
export 'features/occupational/models/occupational_answers.dart';
export 'features/occupational/models/occupational_assessment_result.dart';

import 'features/burnout/models/burnout_result.dart';
import 'features/burnout/models/day_usage.dart';
import 'features/burnout/services/burnout_service.dart';
import 'features/occupational/models/occupational_answers.dart';
import 'features/occupational/models/occupational_assessment_result.dart';
import 'features/occupational/services/occupational_service.dart';

class ApiService {
  ApiService._()
    : _burnoutService = BurnoutService(),
      _occupationalService = OccupationalService();

  static final ApiService instance = ApiService._();

  final BurnoutService _burnoutService;
  final OccupationalService _occupationalService;

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
}
