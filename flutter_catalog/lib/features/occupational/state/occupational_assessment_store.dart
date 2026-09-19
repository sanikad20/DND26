import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/occupational_assessment_result.dart';

class OccupationalAssessmentStore {
  OccupationalAssessmentStore._();

  static final OccupationalAssessmentStore instance =
      OccupationalAssessmentStore._();

  static const _latestAssessmentKey = 'occupational_latest_assessment';

  OccupationalAssessmentResult? _latestAssessment;

  OccupationalAssessmentResult? get latestAssessment => _latestAssessment;

  Future<OccupationalAssessmentResult?> loadLatestAssessment() async {
    if (_latestAssessment != null) return _latestAssessment;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestAssessmentKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _latestAssessment = OccupationalAssessmentResult.fromJson(data);
      return _latestAssessment;
    } catch (_) {
      await prefs.remove(_latestAssessmentKey);
      return null;
    }
  }

  Future<void> saveLatestAssessment(OccupationalAssessmentResult result) async {
    _latestAssessment = result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latestAssessmentKey, jsonEncode(result.toJson()));
  }
}
