import '../models/occupational_assessment_result.dart';

/// Holds the most recently fetched assessment result in memory for the
/// current app session only.
///
/// This intentionally no longer persists to SharedPreferences under a
/// single fixed key: that meant every new assessment silently overwrote
/// whatever was there before, with no link back to which assessment it
/// came from. Now that /occupational/assess returns `id` and `plan_id`
/// (see AssessmentResult / OccupationalAssessmentResult), each result can
/// be tied to its own plan instead of collapsing into one shared slot.
///
/// NOTE: the backend's /occupational/history endpoint only
/// returns lightweight points (id, timestamp, score, risk_level, plan_id) -
/// it does NOT return the full recommendation/plan detail. So this store
/// can only ever hold "the result of the assessment the user just took in
/// this session"; reconstructing full detail for a past assessment after
/// an app restart would need a new backend endpoint
/// (e.g. GET /occupational/assessments/{id}) that isn't in scope here.
/// Until that exists, screens needing "the latest assessment" after a
/// fresh app launch should fall back to prompting a new assessment rather
/// than pretending to recover full detail from history.
class OccupationalAssessmentStore {
  OccupationalAssessmentStore._();

  static final OccupationalAssessmentStore instance =
      OccupationalAssessmentStore._();

  OccupationalAssessmentResult? _latestAssessment;

  OccupationalAssessmentResult? get latestAssessment => _latestAssessment;

  /// Sets the in-memory "latest" pointer right after a fresh /assess call.
  /// Nothing is written to disk.
  void setLatestAssessment(OccupationalAssessmentResult result) {
    _latestAssessment = result;
  }

  void clear() {
    _latestAssessment = null;
  }
}
