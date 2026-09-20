import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OccupationalPlanProgress extends ChangeNotifier {
  OccupationalPlanProgress._();

  static final OccupationalPlanProgress instance = OccupationalPlanProgress._();

  static const _startedKey = 'occupational_plan_started';
  static const _completedDaysKey = 'occupational_plan_completed_days';

  bool _loaded = false;
  bool _started = false;
  final Set<int> _completedDays = {};

  bool get started => _started;
  Set<int> get completedDays => Set.unmodifiable(_completedDays);
  int get completedCount => _completedDays.length;
  double get progress => completedCount / 7;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _started = prefs.getBool(_startedKey) ?? false;
    _completedDays
      ..clear()
      ..addAll(
        (prefs.getStringList(_completedDaysKey) ?? const [])
            .map(int.tryParse)
            .whereType<int>()
            .where((day) => day >= 1 && day <= 7),
      );
    _loaded = true;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    notifyListeners();
    await _save();
  }

  Future<void> resetForNewAssessment() async {
    _started = false;
    _completedDays.clear();
    _loaded = true;
    notifyListeners();
    await _save();
  }

  Future<void> setDayCompleted(int day, bool completed) async {
    if (day < 1 || day > 7) return;
    if (!_started) _started = true;
    final changed = completed
        ? _completedDays.add(day)
        : _completedDays.remove(day);
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  int nextOpenDay([int totalDays = 7]) {
    for (var day = 1; day <= totalDays; day++) {
      if (!_completedDays.contains(day)) return day;
    }
    return totalDays;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startedKey, _started);
    await prefs.setStringList(
      _completedDaysKey,
      _completedDays.map((day) => day.toString()).toList()..sort(),
    );
  }
}
