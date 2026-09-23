import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/occupational_service.dart';

enum PlanStatus {
  notStarted,
  active,
  completed,
}

/// Persistent state model for ONE wellness plan (keyed by planId).
class OccupationalPlanProgress extends ChangeNotifier {
  OccupationalPlanProgress({
    required this.planId,
    OccupationalService? service,
  }) : _service = service ?? OccupationalService();

  final int planId;
  final OccupationalService _service;

  bool _loaded = false;
  PlanStatus _status = PlanStatus.notStarted;
  DateTime? _startDate;
  DateTime? _lastUpdated;
  final Set<int> _completedDays = {};

  bool get loaded => _loaded;
  PlanStatus get status => _status;
  bool get started => _status != PlanStatus.notStarted || _completedDays.isNotEmpty;
  bool get isCompleted => _status == PlanStatus.completed || _completedDays.length >= 7;

  DateTime? get startDate => _startDate;
  DateTime? get lastUpdated => _lastUpdated;
  Set<int> get completedDays => Set.unmodifiable(_completedDays);
  int get completedCount => _completedDays.length;
  double get progress => (completedCount / 7).clamp(0.0, 1.0);

  /// Current active day (1..7). If completed, returns 7.
  int get currentDay {
    if (isCompleted) return 7;
    for (var day = 1; day <= 7; day++) {
      if (!_completedDays.contains(day)) return day;
    }
    return 7;
  }

  /// Intended calendar day based on start date (date-aware), clamped 1..7.
  /// Does NOT automatically mark days complete.
  int get intendedDay {
    if (_startDate == null) return 1;
    final daysElapsed = DateTime.now().difference(_startDate!).inDays;
    return (daysElapsed + 1).clamp(1, 7);
  }

  String get _keyStatus => 'occupational_plan_status_$planId';
  String get _keyStartDate => 'occupational_plan_start_date_$planId';
  String get _keyCompletedDays => 'occupational_plan_completed_days_$planId';
  String get _keyLastUpdated => 'occupational_plan_last_updated_$planId';

  /// Loads plan progress from local SharedPreferences and syncs with backend.
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;

    // 1. Load local state first
    try {
      final prefs = await SharedPreferences.getInstance();

      final statusStr = prefs.getString(_keyStatus);
      if (statusStr != null) {
        _status = PlanStatus.values.firstWhere(
          (e) => e.name == statusStr,
          orElse: () => PlanStatus.notStarted,
        );
      }

      final startIso = prefs.getString(_keyStartDate);
      if (startIso != null && startIso.isNotEmpty) {
        _startDate = DateTime.tryParse(startIso);
      }

      final lastUpIso = prefs.getString(_keyLastUpdated);
      if (lastUpIso != null && lastUpIso.isNotEmpty) {
        _lastUpdated = DateTime.tryParse(lastUpIso);
      }

      final rawCompleted = prefs.getStringList(_keyCompletedDays);
      if (rawCompleted != null) {
        for (final item in rawCompleted) {
          final dayNum = int.tryParse(item);
          if (dayNum != null && dayNum >= 1 && dayNum <= 7) {
            _completedDays.add(dayNum);
          }
        }
      }
    } catch (_) {}

    // 2. Fetch server progress and merge
    try {
      final response = await _service.getPlanProgress(planId);
      for (final dayNum in response.completedDayNumbers) {
        if (dayNum >= 1 && dayNum <= 7) {
          _completedDays.add(dayNum);
        }
      }
    } catch (_) {}

    // 3. Re-evaluate status & enforce state invariant
    _reevaluateStatus();
    _loaded = true;
    await _saveToDisk();
    notifyListeners();
  }

  void _reevaluateStatus() {
    if (_completedDays.length >= 7) {
      _status = PlanStatus.completed;
    } else if (_completedDays.isNotEmpty || _status == PlanStatus.active) {
      _status = PlanStatus.active;
      _startDate ??= DateTime.now();
    } else {
      _status = PlanStatus.notStarted;
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStatus, _status.name);
      if (_startDate != null) {
        await prefs.setString(_keyStartDate, _startDate!.toIso8601String());
      } else {
        await prefs.remove(_keyStartDate);
      }
      if (_lastUpdated != null) {
        await prefs.setString(_keyLastUpdated, _lastUpdated!.toIso8601String());
      } else {
        await prefs.remove(_keyLastUpdated);
      }
      await prefs.setStringList(
        _keyCompletedDays,
        _completedDays.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  /// Taps "Start Plan"
  Future<void> start() async {
    if (_status == PlanStatus.active || _status == PlanStatus.completed) return;
    _status = PlanStatus.active;
    _startDate ??= DateTime.now();
    _lastUpdated = DateTime.now();
    await _saveToDisk();
    notifyListeners();
  }

  /// Toggles day completion status (1..7).
  Future<void> setDayCompleted(int day, bool completed) async {
    if (day < 1 || day > 7) return;

    final changed = completed
        ? _completedDays.add(day)
        : _completedDays.remove(day);
    if (!changed) return;

    if (_status == PlanStatus.notStarted) {
      _status = PlanStatus.active;
      _startDate ??= DateTime.now();
    }
    _lastUpdated = DateTime.now();
    _reevaluateStatus();

    await _saveToDisk();
    notifyListeners();

    // Sync optimistic update with server
    try {
      await _service.setPlanDayCompleted(planId, day, completed);
    } catch (_) {
      // Rollback on failure
      if (completed) {
        _completedDays.remove(day);
      } else {
        _completedDays.add(day);
      }
      _reevaluateStatus();
      await _saveToDisk();
      notifyListeners();
      rethrow;
    }
  }

  /// Resets plan back to notStarted.
  Future<void> resetProgress() async {
    final daysToClear = List<int>.from(_completedDays);
    _completedDays.clear();
    _status = PlanStatus.notStarted;
    _startDate = null;
    _lastUpdated = DateTime.now();
    await _saveToDisk();
    notifyListeners();

    for (final day in daysToClear) {
      try {
        await _service.setPlanDayCompleted(planId, day, false);
      } catch (_) {}
    }
  }

  int nextOpenDay([int totalDays = 7]) {
    return currentDay;
  }
}
