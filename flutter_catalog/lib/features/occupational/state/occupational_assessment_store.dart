import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/occupational_assessment_result.dart';

/// Holds the most recently fetched assessment result in memory and persists to
/// SharedPreferences so the dashboard retains current assessment risk, score,
/// indicators, and recommendations across app restarts.
class OccupationalAssessmentStore {
  OccupationalAssessmentStore._();

  static final OccupationalAssessmentStore instance =
      OccupationalAssessmentStore._();

  static const String _storageKey = 'latest_occupational_assessment_v1';

  OccupationalAssessmentResult? _latestAssessment;

  OccupationalAssessmentResult? get latestAssessment => _latestAssessment;

  /// Loads the persisted latest assessment from SharedPreferences if present.
  Future<OccupationalAssessmentResult?> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final data = jsonDecode(rawJson) as Map<String, dynamic>;
        _latestAssessment = OccupationalAssessmentResult.fromJson(data);
      }
    } catch (_) {
      // Graceful fallback if storage corrupted
    }
    return _latestAssessment;
  }

  /// Sets and persists the latest assessment result.
  Future<void> setLatestAssessment(OccupationalAssessmentResult result) async {
    _latestAssessment = result;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(result.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    _latestAssessment = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
