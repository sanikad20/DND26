import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved Digital Burnout result (score is on the model's 1-10 scale).
class BurnoutHistoryPoint {
  final DateTime timestamp;
  final double score;
  final String level;
  final String source; // 'Manual' or 'LSTM'

  const BurnoutHistoryPoint({
    required this.timestamp,
    required this.score,
    required this.level,
    required this.source,
  });

  factory BurnoutHistoryPoint.fromJson(Map<String, dynamic> data) {
    return BurnoutHistoryPoint(
      timestamp:
          DateTime.tryParse(data['t']?.toString() ?? '') ?? DateTime.now(),
      score: double.tryParse(data['s'].toString()) ?? 0,
      level: data['l']?.toString() ?? '',
      source: data['src']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    't': timestamp.toIso8601String(),
    's': score,
    'l': level,
    'src': source,
  };
}

/// Keeps a short, on-device history of Digital Burnout scores so the Wellness
/// Dashboard can chart them. Stored per Firebase user, scores only — nothing
/// is sent to the backend.
class BurnoutHistoryStore {
  BurnoutHistoryStore._();

  static final BurnoutHistoryStore instance = BurnoutHistoryStore._();

  static const _maxPoints = 30;

  String? get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : 'burnout_history_$uid';
  }

  Future<List<BurnoutHistoryPoint>> load() async {
    final key = _key;
    if (key == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final points = list
          .whereType<Map<String, dynamic>>()
          .map(BurnoutHistoryPoint.fromJson)
          .toList();
      points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return points;
    } catch (_) {
      await prefs.remove(key);
      return const [];
    }
  }

  /// Save a new result. Continuous-monitoring (LSTM) results refresh often,
  /// so they replace the earlier LSTM point from the same day instead of
  /// piling up; every manual prediction is its own point.
  Future<void> record({
    required double score,
    required String level,
    required String source,
  }) async {
    final key = _key;
    if (key == null) return;
    try {
      final points = (await load()).toList();
      final now = DateTime.now();
      if (source == 'LSTM') {
        points.removeWhere(
          (p) =>
              p.source == 'LSTM' &&
              p.timestamp.year == now.year &&
              p.timestamp.month == now.month &&
              p.timestamp.day == now.day,
        );
      }
      points.add(
        BurnoutHistoryPoint(
          timestamp: now,
          score: score,
          level: level,
          source: source,
        ),
      );
      final trimmed = points.length > _maxPoints
          ? points.sublist(points.length - _maxPoints)
          : points;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(trimmed.map((p) => p.toJson()).toList()),
      );
    } catch (_) {
      // History is a convenience; never let it break a prediction.
    }
  }
}
