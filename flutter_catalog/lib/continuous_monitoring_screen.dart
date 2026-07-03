import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'usage_service.dart';

class ContinuousMonitoringScreen extends StatefulWidget {
  const ContinuousMonitoringScreen({super.key});

  @override
  State<ContinuousMonitoringScreen> createState() =>
      _ContinuousMonitoringScreenState();
}

class _ContinuousMonitoringScreenState
    extends State<ContinuousMonitoringScreen> {

  bool   _isFetching = false;
  String _statusMsg  = 'Loading…';

  List<DayUsageRaw> _history  = [];
  PersonalBaseline? _baseline;
  double?           _liveScreenTime;

  double? _manualScore;
  String  _manualLevel = '--';
  double? _lstmScore;
  String  _lstmLevel   = '--';

  Map<String, double>? _serverBaseline;
  Map<String, double>? _todayVsBaseline;

  final Map<int, double> _dailyScores = {};

  Timer? _autoTimer;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
    _autoTimer = Timer.periodic(
        const Duration(minutes: 30), (_) { if (mounted) _loadAll(); });
    _liveTimer = Timer.periodic(
        const Duration(minutes: 5),  (_) { if (mounted) _refreshLive(); });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLive() async {
    final h = await UsageService.instance.fetchLiveScreenTime();
    if (mounted) setState(() => _liveScreenTime = h);
  }

  // ── Core load ─────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (_isFetching) return;
    if (mounted) setState(() {
      _isFetching = true;
      _statusMsg  = 'Reading 7-day Digital Wellbeing data…';
    });

    try {
      await UsageService.instance.getInstallDate();
      final history = await UsageService.instance.fetchHistory(forceRefresh: true);
      final live    = await UsageService.instance.fetchLiveScreenTime();

      if (history.isEmpty) {
        if (mounted) setState(() {
          _statusMsg  = 'No usage data found.';
          _isFetching = false;
        });
        return;
      }

      final baseline = UsageService.instance.baseline!;

      if (mounted) setState(() {
        _history        = history;
        _baseline       = baseline;
        _liveScreenTime = live;
        _statusMsg      = 'Running burnout models…';
      });

      // ── Step 1: Manual model per day ──────────────────────────────────────
      _dailyScores.clear();
      for (int i = 0; i < history.length; i++) {
        final day = history[i];
        if (!day.hasData) continue;
        try {
          final r = await ApiService.instance.predictManual(
              _toApiUsage(day, baseline));
          if (mounted) setState(() => _dailyScores[i] = r.score);
        } catch (_) {}
      }

      if (_dailyScores.containsKey(0) && mounted) {
        setState(() {
          _manualScore = _dailyScores[0];
          _manualLevel = _scoreToLevel(_manualScore!);
        });
      }

      // ── Step 2: LSTM model ────────────────────────────────────────────────
      if (mounted) setState(() => _statusMsg = 'Running LSTM personalised prediction…');

      if (history.length >= 8) {
        try {
          final pastDays = history
              .sublist(1, 8)
              .reversed
              .map((d) => _toApiUsage(d, baseline))
              .toList();

          final todayRaw    = history[0];
          final liveHours   = _liveScreenTime ?? 0.0;
          final screenHours = (liveHours > 0.1)
              ? liveHours
              : todayRaw.screenTimeHours;

          print("TODAY screen used for LSTM: $screenHours "
              "(live=$liveHours, raw=${todayRaw.screenTimeHours})");

          final todayUsage = DayUsage(
            screenTimeHours:    screenHours,
            appSwitchesPerHour: todayRaw.appSwitchesPerHour.toDouble(),
            uniqueAppsPerDay:   todayRaw.uniqueAppsPerDay.toDouble(),
            socialAppRatio:     todayRaw.socialAppRatio,
            workAppRatio:       todayRaw.workAppRatio,
            entertainmentRatio: todayRaw.entertainmentRatio,
            wellnessRatio:      todayRaw.wellnessRatio,
            sleepHours:         7.0,
            sleepQuality:       3.0,
            exerciseMinPerWeek: 90.0,
            socialHoursPerWeek: todayRaw.socialAppRatio * 40,
            callCount:          5.0,
            missedCallRatio:    0.1,
            smsCount:           20.0,
          );

          final result = await ApiService.instance.predictLSTM(
            pastDays: pastDays,
            today:    todayUsage,
          );

          if (mounted) setState(() {
            _lstmScore       = result.score;
            _lstmLevel       = result.level;
            _serverBaseline  = result.personalBaseline;
            _todayVsBaseline = result.todayVsBaseline;
          });

        } catch (e, st) {
          print("========== LSTM FAILED ==========");
          print(e); print(st);
          print("=================================");
        }
      } else {
        if (mounted) setState(() =>
            _lstmLevel = 'Need ${8 - history.length + 1} more days for LSTM');
      }

      if (mounted) setState(() =>
          _statusMsg = 'Updated ${_fmt(DateTime.now())}  · ${history.length} days');

    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  DayUsage _toApiUsage(DayUsageRaw d, PersonalBaseline b) => DayUsage(
        screenTimeHours:    d.screenTimeHours,
        appSwitchesPerHour: d.appSwitchesPerHour.toDouble(),
        uniqueAppsPerDay:   d.uniqueAppsPerDay.toDouble(),
        socialAppRatio:     d.socialAppRatio,
        workAppRatio:       d.workAppRatio,
        entertainmentRatio: d.entertainmentRatio,
        wellnessRatio:      d.wellnessRatio,
        sleepHours:         7.0,
        sleepQuality:       3.0,
        exerciseMinPerWeek: 90.0,
        socialHoursPerWeek: d.socialAppRatio * 40,
        callCount:          5.0,
        missedCallRatio:    0.1,
        smsCount:           20.0,
      );

  String _scoreToLevel(double s) {
    if (s < 4) return 'Low 🟢';
    if (s < 7) return 'Moderate 🟠';
    return 'High 🔴';
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  // ── Deviation alerts ──────────────────────────────────────────────────────

  List<String> get _alerts {
    if (_history.isEmpty || _baseline == null) return [];
    final d = _history.first;
    final liveScreen = _liveScreenTime ?? d.screenTimeHours;
    final b = _baseline!;
    final a = <String>[];

    final avgScreen = _serverBaseline?['avg_screen_time'] ?? b.avgScreenTime;
    final screenZ   = _todayVsBaseline?['screen_zscore']  ?? 0.0;
    final socialZ   = _todayVsBaseline?['social_zscore']  ?? 0.0;

    if (liveScreen > b.thresholdScreenTime)
      a.add('📱 Screen time ${liveScreen.toStringAsFixed(1)}h '
          '> your threshold ${b.thresholdScreenTime.toStringAsFixed(1)}h');
    if (screenZ.abs() > 1.5)
      a.add('⚠️ Screen time is ${screenZ.toStringAsFixed(1)}σ '
          '${screenZ > 0 ? "above" : "below"} your 7-day average');
    if (socialZ.abs() > 1.5)
      a.add('⚠️ Social usage is ${socialZ.toStringAsFixed(1)}σ '
          '${socialZ > 0 ? "above" : "below"} your 7-day average');
    if (d.socialAppRatio > b.thresholdSocialRatio)
      a.add('📲 Social apps ${(d.socialAppRatio * 100).toStringAsFixed(0)}% '
          '> your threshold ${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%');
    if (d.appSwitchesPerHour > b.thresholdAppSwitches)
      a.add('🔀 App switches ${d.appSwitchesPerHour}/hr '
          '> your threshold ${b.thresholdAppSwitches}/hr');
    final liveDelta = liveScreen - avgScreen;
    if (liveDelta > 1.5)
      a.add('📈 Screen time up ${liveDelta.toStringAsFixed(1)}h '
          'vs your 7-day avg (${avgScreen.toStringAsFixed(1)}h)');
    return a;
  }

  // ── Colours ───────────────────────────────────────────────────────────────

  Color _scoreColor(double s) {
    if (s < 4) return Colors.green;
    if (s < 7) return Colors.orange;
    return Colors.red;
  }

  Color _levelColor(String l) {
    if (l.contains('Low'))      return Colors.green;
    if (l.contains('Moderate')) return Colors.orange;
    if (l.contains('High'))     return Colors.red;
    return Colors.white54;
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _card({
    required String   title,
    required String   value,
    required IconData icon,
    Color?   valueColor,
    String?  subtitle,
    bool     highlight = false,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFF2A1A0A) : const Color(0xFF232325),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: highlight ? Colors.orange.withOpacity(0.5) : Colors.white12),
        ),
        child: Row(children: [
          Icon(icon,
              color: highlight ? Colors.orange : const Color(0xFF8A5CE6),
              size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          )),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ]),
      );

  Widget _dualScoreCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8A5CE6).withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.health_and_safety_outlined,
                color: Color(0xFF8A5CE6), size: 18),
            SizedBox(width: 8),
            Text("Today's Burnout Score",
                style: TextStyle(color: Color(0xFF8A5CE6),
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _scoreBox('Manual Model', _manualScore, _manualLevel)),
            const SizedBox(width: 10),
            Expanded(child: _scoreBox('LSTM  (7-day)', _lstmScore, _lstmLevel)),
          ]),
          if (_todayVsBaseline != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            const Text('Today vs Your 7-Day Average',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            _deltaRow('Screen time',
                _todayVsBaseline!['screen_time_delta'] ?? 0,
                suffix: 'h', higherIsBad: true),
            _deltaRow('Social usage',
                (_todayVsBaseline!['social_ratio_delta'] ?? 0) * 100,
                suffix: '%', higherIsBad: true),
            _deltaRow('Work usage',
                (_todayVsBaseline!['work_ratio_delta'] ?? 0) * 100,
                suffix: '%', higherIsBad: false),
            _deltaRow('Sleep',
                _todayVsBaseline!['sleep_delta'] ?? 0,
                suffix: 'h', higherIsBad: false),
          ],
        ]),
      );

  Widget _scoreBox(String label, double? score, String level) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF232325),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            score != null ? '${score.toStringAsFixed(1)}/10' : '--',
            style: TextStyle(
              color: score != null ? _scoreColor(score) : Colors.white38,
              fontSize: 24, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(level,
              style: TextStyle(color: _levelColor(level), fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _deltaRow(String label, double delta,
      {required String suffix, required bool higherIsBad}) {
    final isPositive = delta >= 0;
    final isBad      = higherIsBad ? isPositive : !isPositive;
    final color      = delta.abs() < 0.05
        ? Colors.white38
        : isBad ? Colors.redAccent : Colors.greenAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12))),
        Text(
          '${isPositive ? "▲" : "▼"} '
          '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(suffix == "%" ? 0 : 1)}$suffix',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }

  Widget _chart({
    required String       title,
    required List<FlSpot> spots,
    required double       maxY,
    bool    isInt   = false,
    Color   color   = const Color(0xFF8A5CE6),
    double? threshY,
    double? avgY,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF232325),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          spots.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No data yet',
                      style: TextStyle(color: Colors.white38))))
              : SizedBox(
                  height: 200,
                  child: LineChart(LineChartData(
                    minX: 0,
                    maxX: (spots.length - 1).toDouble().clamp(1.0, 6.0),
                    minY: 0, maxY: maxY,
                    gridData: FlGridData(
                      show: true, drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: Colors.white12, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(horizontalLines: [
                      if (threshY != null)
                        HorizontalLine(
                          y: threshY,
                          color: Colors.orange.withOpacity(0.8),
                          strokeWidth: 1.5, dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true, alignment: Alignment.topRight,
                            labelResolver: (_) => 'threshold',
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 9),
                          ),
                        ),
                      if (avgY != null)
                        HorizontalLine(
                          y: avgY,
                          color: Colors.green.withOpacity(0.6),
                          strokeWidth: 1, dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true, alignment: Alignment.bottomRight,
                            labelResolver: (_) => 'your avg',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 9),
                          ),
                        ),
                    ]),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 32,
                          getTitlesWidget: (v, _) => Text(
                            isInt ? v.toInt().toString() : v.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 9)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 22,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= _history.length)
                              return const SizedBox.shrink();
                            final d = _history[i];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                d.daysAgo == 0 ? 'Today' : d.dateLabel,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 9)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots, isCurved: true,
                        color: color, barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                            radius: 3, color: color,
                            strokeWidth: 1, strokeColor: Colors.white24),
                        ),
                        belowBarData: BarAreaData(
                            show: true, color: color.withOpacity(0.12)),
                      ),
                    ],
                  )),
                ),
        ]),
      );

  Widget _baselineCard() {
    if (_baseline == null) return const SizedBox.shrink();
    final b         = _baseline!;
    final avgScreen = _serverBaseline?['avg_screen_time'] ?? b.avgScreenTime;
    final avgSocial = _serverBaseline?['avg_social_ratio'] ?? b.avgSocialRatio;
    final avgWork   = _serverBaseline?['avg_work_ratio']   ?? b.avgWorkRatio;
    final avgSwitch = _serverBaseline?['avg_app_switches']
        ?? b.avgAppSwitchesPerHour.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8A5CE6).withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline, color: Color(0xFF8A5CE6), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Your Personal Baseline  (7 days)',
                style: TextStyle(color: Color(0xFF8A5CE6),
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: b.daysOfData >= 5
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(b.qualityLabel,
                style: TextStyle(
                    color: b.daysOfData >= 5 ? Colors.green : Colors.orange,
                    fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 10),
        _bRow('Avg screen time',  '${avgScreen.toStringAsFixed(1)} h/day'),
        _bRow('Avg social usage', '${(avgSocial * 100).toStringAsFixed(0)}%'),
        _bRow('Avg work usage',   '${(avgWork * 100).toStringAsFixed(0)}%'),
        _bRow('Avg app switches', '${avgSwitch.toStringAsFixed(0)} /hr'),
        const Divider(color: Colors.white12, height: 16),
        const Row(children: [
          Icon(Icons.tune, color: Colors.white38, size: 14),
          SizedBox(width: 6),
          Text('Dynamic Thresholds  (personalised)',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        _bRow('Screen time',  '${b.thresholdScreenTime.toStringAsFixed(1)} h'),
        _bRow('Social ratio', '${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%'),
        _bRow('App switches', '${b.thresholdAppSwitches} /hr'),
      ]),
    );
  }

  Widget _bRow(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Expanded(child: Text(l,
              style: const TextStyle(color: Colors.white60, fontSize: 13))),
          Text(v, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today         = _history.isNotEmpty ? _history.first : null;
    final b             = _baseline;
    final alerts        = _alerts;
    final screenDisplay = _liveScreenTime ?? today?.screenTimeHours;
    final screenAbove   = b != null && screenDisplay != null &&
        screenDisplay > b.thresholdScreenTime;

    final scoreSpots = _dailyScores.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    final screenSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.screenTimeHours)).toList();

    final socialSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.socialAppRatio)).toList();

    final switchSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(),
            e.value.appSwitchesPerHour.toDouble())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text('Continuous Monitoring',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _isFetching
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isFetching ? null : _loadAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(_statusMsg,
                    style: const TextStyle(color: Colors.white54, fontSize: 12))),
              ]),
            ),

            _baselineCard(),
            _dualScoreCard(),

            _card(
              title: 'Screen Time Today  (live)',
              value: screenDisplay != null
                  ? '${screenDisplay.toStringAsFixed(1)} h' : '--',
              icon: Icons.phone_android_outlined,
              valueColor: screenAbove ? Colors.orange : null,
              subtitle: b != null
                  ? 'avg: ${b.avgScreenTime.toStringAsFixed(1)}h  '
                    '· threshold: ${b.thresholdScreenTime.toStringAsFixed(1)}h'
                  : null,
              highlight: screenAbove,
            ),

            _card(
              title: 'App Switches / hr',
              value: today != null ? '${today.appSwitchesPerHour}' : '--',
              icon: Icons.swap_horiz_outlined,
              subtitle: b != null
                  ? 'avg: ${b.avgAppSwitchesPerHour}/hr  '
                    '· threshold: ${b.thresholdAppSwitches}/hr'
                  : null,
              valueColor: (today != null && b != null &&
                      today.appSwitchesPerHour > b.thresholdAppSwitches)
                  ? Colors.orange : null,
              highlight: today != null && b != null &&
                  today.appSwitchesPerHour > b.thresholdAppSwitches,
            ),

            _card(
              title: 'Social App Usage',
              value: today != null
                  ? '${(today.socialAppRatio * 100).toStringAsFixed(0)}%' : '--',
              icon: Icons.people_outline,
              subtitle: b != null
                  ? 'avg: ${(b.avgSocialRatio * 100).toStringAsFixed(0)}%  '
                    '· threshold: ${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%'
                  : null,
              valueColor: (today != null && b != null &&
                      today.socialAppRatio > b.thresholdSocialRatio)
                  ? Colors.orange : null,
            ),

            _card(
              title: 'Work App Usage',
              value: today != null
                  ? '${(today.workAppRatio * 100).toStringAsFixed(0)}%' : '--',
              icon: Icons.work_outline,
              subtitle: b != null
                  ? 'avg: ${(b.avgWorkRatio * 100).toStringAsFixed(0)}%' : null,
            ),

            const SizedBox(height: 6),

            if (alerts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1A0A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.warning_amber_outlined,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('Deviation from Your 7-Day Normal',
                          style: TextStyle(
                              color: Colors.orange, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ...alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(a, style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                        )),
                  ],
                ),
              ),

            _chart(
              title: 'Burnout Score  (1–10, 7 days)',
              spots: scoreSpots, maxY: 10,
              color: Colors.deepOrangeAccent,
              threshY: 4, avgY: 7,
            ),
            const SizedBox(height: 14),
            _chart(
              title: 'Screen Time  (hours)',
              spots: screenSpots, maxY: 16,
              color: const Color(0xFF8A5CE6),
              threshY: b?.thresholdScreenTime,
              avgY:    b?.avgScreenTime,
            ),
            const SizedBox(height: 14),
            _chart(
              title: 'App Switches / hr',
              spots: switchSpots, maxY: 60,
              isInt: true,
              color: Colors.tealAccent,
              threshY: b?.thresholdAppSwitches.toDouble(),
              avgY:    b?.avgAppSwitchesPerHour.toDouble(),
            ),
            const SizedBox(height: 14),
            _chart(
              title: 'Social App Usage',
              spots: socialSpots, maxY: 1.0,
              color: Colors.pinkAccent,
              threshY: b?.thresholdSocialRatio,
              avgY:    b?.avgSocialRatio,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}