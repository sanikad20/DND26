import 'package:flutter/foundation.dart';

import '../services/occupational_service.dart';

/// Tracks per-day completion for ONE wellness plan (one plan per
/// assessment - see AssessmentResult.planId / WellnessPlanOut).
///
/// This replaces the old SharedPreferences-backed singleton, which stored
/// progress under two fixed keys shared by every assessment - so taking a
/// new assessment had to explicitly wipe the old progress
/// (resetForNewAssessment()) or the new plan would inherit the old one's
/// completed days. Now each plan gets its own instance, keyed by planId,
/// and progress is persisted server-side via
/// GET/POST /occupational/plans/{plan_id}/progress, so nothing needs to be
/// "reset" - a new assessment's plan simply starts with no progress rows.
class OccupationalPlanProgress extends ChangeNotifier {
  OccupationalPlanProgress({
    required this.planId,
    OccupationalService? service,
  }) : _service = service ?? OccupationalService();

  final int planId;
  final OccupationalService _service;

  bool _loaded = false;
  // Session-only "the person tapped Start" flag. There's no backend column
  // for this (plan_progress only tracks day completion), so unlike
  // completedDays it does not survive an app restart - it's just enough to
  // preserve the old "started but 0 days done yet" UI state within a
  // session. Completing any day also counts as started.
  bool _startedThisSession = false;
  final Set<int> _completedDays = {};

  bool get loaded => _loaded;
  bool get started => _startedThisSession || _completedDays.isNotEmpty;
  Set<int> get completedDays => Set.unmodifiable(_completedDays);
  int get completedCount => _completedDays.length;
  double get progress => completedCount / 7;

  /// Fetches this plan's current progress from the backend. Safe to call
  /// more than once; only hits the network the first time unless
  /// [force] is set (e.g. pull-to-refresh).
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    final response = await _service.getPlanProgress(planId);
    _completedDays
      ..clear()
      ..addAll(response.completedDayNumbers);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDayCompleted(int day, bool completed) async {
    if (day < 1 || day > 7) return;
    final changed = completed
        ? _completedDays.add(day)
        : _completedDays.remove(day);
    if (!changed) return;

    // Optimistic update, then sync; roll back on failure so the UI never
    // shows a day as done when the server didn't actually record it.
    notifyListeners();
    try {
      await _service.setPlanDayCompleted(planId, day, completed);
    } catch (_) {
      if (completed) {
        _completedDays.remove(day);
      } else {
        _completedDays.add(day);
      }
      notifyListeners();
      rethrow;
    }
  }

  void start() {
    if (_startedThisSession) return;
    _startedThisSession = true;
    notifyListeners();
  }

  /// Clears every completed day on THIS plan back to incomplete. Distinct
  /// from the old resetForNewAssessment(): that used to be called because
  /// a new assessment shared this same progress state and had to wipe it.
  /// Now every assessment gets its own plan/progress, so this is only for
  /// a person deliberately wanting to restart the plan they're currently
  /// on.
  Future<void> resetProgress() async {
    final daysToClear = List<int>.from(_completedDays);
    _completedDays.clear();
    _startedThisSession = false;
    notifyListeners();
    for (final day in daysToClear) {
      await _service.setPlanDayCompleted(planId, day, false);
    }
  }

  int nextOpenDay([int totalDays = 7]) {
    for (var day = 1; day <= totalDays; day++) {
      if (!_completedDays.contains(day)) return day;
    }
    return totalDays;
  }
}
