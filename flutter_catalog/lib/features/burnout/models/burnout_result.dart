class BurnoutResult {
  final double score;
  final String level;
  final String source;
  final Map<String, double>? personalBaseline;
  final Map<String, double>? todayVsBaseline;

  const BurnoutResult({
    required this.score,
    required this.level,
    required this.source,
    this.personalBaseline,
    this.todayVsBaseline,
  });
}
