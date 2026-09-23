import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'core/network/api_client.dart';
import 'usage_service.dart';
import 'features/burnout/state/burnout_history_store.dart';
import 'theme/app_theme.dart';
import 'widgets/veer_mitra_app_bar.dart';

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

  double? _lstmScore;
  String  _lstmLevel   = '--';

  Map<String, double>? _serverBaseline;
  Map<String, double>? _todayVsBaseline;

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

  Future<void> _loadAll() async {
    if (_isFetching) return;
    if (mounted) {
      setState(() {
        _isFetching = true;
        _statusMsg  = 'Reading 7-day Digital Wellbeing data…';
      });
    }

    try {
      await UsageService.instance.getInstallDate();
      final history = await UsageService.instance.fetchHistory(forceRefresh: true);
      final live    = await UsageService.instance.fetchLiveScreenTime();

      if (history.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMsg  = 'No usage data found.';
            _isFetching = false;
          });
        }
        return;
      }

      final baseline = UsageService.instance.baseline!;

      if (mounted) {
        setState(() {
          _history        = history;
          _baseline       = baseline;
          _liveScreenTime = live;
          _statusMsg      = 'Running burnout models…';
        });
      }

      if (mounted) {
        setState(() => _statusMsg = 'Running LSTM personalised prediction…');
      }

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

          BurnoutHistoryStore.instance.record(
            score:  result.score,
            level:  result.level,
            source: 'LSTM',
          );

          if (mounted) {
            setState(() {
              _lstmScore       = result.score;
              _lstmLevel       = result.level;
              _serverBaseline  = result.personalBaseline;
              _todayVsBaseline = result.todayVsBaseline;
            });
          }

        } catch (e, st) {
          debugPrint("========== LSTM FAILED ==========");
          debugPrint(e.toString());
          debugPrint(st.toString());
          if (mounted) {
            setState(() => _lstmLevel =
                (e is ApiException && e.isNetworkError)
                    ? 'Server unreachable'
                    : 'Prediction failed');
          }
        }
      } else {
        if (mounted) {
          setState(() =>
              _lstmLevel = 'Need ${8 - history.length + 1} more days for LSTM');
        }
      }

      if (mounted) {
        setState(() =>
            _statusMsg = 'Updated ${_fmt(DateTime.now())}  · ${history.length} days');
      }

    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
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

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  List<String> get _alerts {
    if (_history.isEmpty || _baseline == null) return [];
    final d = _history.first;
    final liveScreen = _liveScreenTime ?? d.screenTimeHours;
    final b = _baseline!;
    final a = <String>[];

    final avgScreen = _serverBaseline?['avg_screen_time'] ?? b.avgScreenTime;
    final screenZ   = _todayVsBaseline?['screen_zscore']  ?? 0.0;
    final socialZ   = _todayVsBaseline?['social_zscore']  ?? 0.0;

    if (liveScreen > b.thresholdScreenTime) {
      a.add('📱 Screen time ${liveScreen.toStringAsFixed(1)}h > your threshold ${b.thresholdScreenTime.toStringAsFixed(1)}h');
    }
    if (screenZ.abs() > 1.5) {
      a.add('⚠️ Screen time is ${screenZ.toStringAsFixed(1)}σ ${screenZ > 0 ? "above" : "below"} your 7-day average');
    }
    if (socialZ.abs() > 1.5) {
      a.add('⚠️ Social usage is ${socialZ.toStringAsFixed(1)}σ ${socialZ > 0 ? "above" : "below"} your 7-day average');
    }
    if (d.socialAppRatio > b.thresholdSocialRatio) {
      a.add('📲 Social apps ${(d.socialAppRatio * 100).toStringAsFixed(0)}% > your threshold ${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%');
    }
    if (d.appSwitchesPerHour > b.thresholdAppSwitches) {
      a.add('🔀 App switches ${d.appSwitchesPerHour}/hr > your threshold ${b.thresholdAppSwitches}/hr');
    }
    final liveDelta = liveScreen - avgScreen;
    if (liveDelta > 1.5) {
      a.add('📈 Screen time up ${liveDelta.toStringAsFixed(1)}h vs your 7-day avg (${avgScreen.toStringAsFixed(1)}h)');
    }
    return a;
  }

  Color _scoreColor(double s) {
    if (s < 4) return AppColors.riskLow;
    if (s < 7) return AppColors.riskModerate;
    return AppColors.riskHigh;
  }

  Color _levelColor(String l) {
    if (l.contains('Low'))      return AppColors.riskLow;
    if (l.contains('Moderate')) return AppColors.riskModerate;
    if (l.contains('High'))     return AppColors.riskHigh;
    return ThemeController.instance.isDarkMode ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  }

  Widget _card({
    required String   title,
    required String   value,
    required IconData icon,
    Color?   valueColor,
    String?  subtitle,
    bool     highlight = false,
  }) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.saffronAccent.withValues(alpha: 0.08) : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.saffronAccent.withValues(alpha: 0.4) : theme.dividerColor,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: highlight ? AppColors.saffronAccent : primaryTextColor, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle, style: TextStyle(color: mutedTextColor, fontSize: 12)),
          ],
        )),
        Text(value, style: TextStyle(color: valueColor ?? primaryTextColor, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }

  Widget _lstmScoreCard() {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryTextColor.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.health_and_safety_outlined, color: primaryTextColor, size: 20),
          const SizedBox(width: 8),
          Text("Today's Burnout Score  (LSTM 7-day)",
              style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        Center(
          child: Column(children: [
            Text(
              _lstmScore != null ? '${_lstmScore!.toStringAsFixed(1)}/10' : '--',
              style: TextStyle(
                color: _lstmScore != null ? _scoreColor(_lstmScore!) : mutedTextColor,
                fontSize: 44, fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _levelColor(_lstmLevel).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _levelColor(_lstmLevel).withValues(alpha: 0.3)),
              ),
              child: Text(_lstmLevel,
                  style: TextStyle(color: _levelColor(_lstmLevel), fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        if (_todayVsBaseline != null) ...[
          const SizedBox(height: 14),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 8),
          Text('Today vs Your 7-Day Average', style: TextStyle(color: mutedTextColor, fontSize: 12)),
          const SizedBox(height: 8),
          _deltaRow('Screen time', _todayVsBaseline!['screen_time_delta'] ?? 0, suffix: 'h', higherIsBad: true),
          _deltaRow('Social usage', (_todayVsBaseline!['social_ratio_delta'] ?? 0) * 100, suffix: '%', higherIsBad: true),
          _deltaRow('Work usage', (_todayVsBaseline!['work_ratio_delta'] ?? 0) * 100, suffix: '%', higherIsBad: false),
          _deltaRow('Sleep', _todayVsBaseline!['sleep_delta'] ?? 0, suffix: 'h', higherIsBad: false),
        ],
      ]),
    );
  }

  Widget _deltaRow(String label, double delta, {required String suffix, required bool higherIsBad}) {
    final isDark = ThemeController.instance.isDarkMode;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final isPositive = delta >= 0;
    final isBad      = higherIsBad ? isPositive : !isPositive;
    final color      = delta.abs() < 0.05
        ? mutedTextColor
        : isBad ? AppColors.riskHigh : AppColors.riskLow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 13))),
        Text(
          '${isPositive ? "▲" : "▼"} ${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(suffix == "%" ? 0 : 1)}$suffix',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Widget _chart({
    required String       title,
    required List<FlSpot> spots,
    required double       maxY,
    bool    isInt   = false,
    Color?  color,
    double? threshY,
    double? avgY,
  }) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final chartColor = color ?? primaryTextColor;
    final showEvery = spots.length > 5 ? 2 : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(title, style: TextStyle(color: primaryTextColor, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        spots.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No data yet', style: TextStyle(color: mutedTextColor))))
            : SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble().clamp(1.0, 7.0),
                  minY: 0,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(color: theme.dividerColor, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: maxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          isInt ? v.toInt().toString() : v.toStringAsFixed(1),
                          style: TextStyle(color: mutedTextColor, fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _history.length) return const SizedBox.shrink();
                          if (i % showEvery != 0 && i != 0) return const SizedBox.shrink();
                          final d = _history[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(d.daysAgo == 0 ? 'Today' : d.dateLabel, style: TextStyle(color: mutedTextColor, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: chartColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: chartColor.withValues(alpha: 0.08)),
                    ),
                  ],
                )),
              ),
      ]),
    );
  }

  Widget _baselineCard() {
    if (_baseline == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final b         = _baseline!;
    final avgScreen = _serverBaseline?['avg_screen_time'] ?? b.avgScreenTime;
    final avgSocial = _serverBaseline?['avg_social_ratio'] ?? b.avgSocialRatio;
    final avgWork   = _serverBaseline?['avg_work_ratio']   ?? b.avgWorkRatio;
    final avgSwitch = _serverBaseline?['avg_app_switches'] ?? b.avgAppSwitchesPerHour.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_outline, color: primaryTextColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Your Personal Baseline  (7 days)', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: b.daysOfData >= 5 ? AppColors.riskLow.withValues(alpha: 0.12) : AppColors.riskModerate.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(b.qualityLabel, style: TextStyle(color: b.daysOfData >= 5 ? AppColors.riskLow : AppColors.riskModerate, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        _bRow('Avg screen time',  '${avgScreen.toStringAsFixed(1)} h/day'),
        _bRow('Avg social usage', '${(avgSocial * 100).toStringAsFixed(0)}%'),
        _bRow('Avg work usage',   '${(avgWork * 100).toStringAsFixed(0)}%'),
        _bRow('Avg app switches', '${avgSwitch.toStringAsFixed(0)} /hr'),
        Divider(color: theme.dividerColor, height: 16),
        Row(children: [
          Icon(Icons.tune, color: mutedTextColor, size: 14),
          const SizedBox(width: 6),
          Text('Dynamic Thresholds  (personalised)', style: TextStyle(color: mutedTextColor, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        _bRow('Screen time',  '${b.thresholdScreenTime.toStringAsFixed(1)} h'),
        _bRow('Social ratio', '${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%'),
        _bRow('App switches', '${b.thresholdAppSwitches} /hr'),
      ]),
    );
  }

  Widget _bRow(String l, String v) {
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(child: Text(l, style: TextStyle(color: secondaryTextColor, fontSize: 13))),
        Text(v, style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final today         = _history.isNotEmpty ? _history.first : null;
    final b             = _baseline;
    final alerts        = _alerts;
    final screenDisplay = _liveScreenTime ?? today?.screenTimeHours;
    final screenAbove   = b != null && screenDisplay != null &&
        screenDisplay > b.thresholdScreenTime;

    final screenSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.screenTimeHours)).toList();

    final socialSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.socialAppRatio)).toList();

    final switchSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.appSwitchesPerHour.toDouble())).toList();

    return Scaffold(
      appBar: VeerMitraAppBar(
        extraActions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _isFetching
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: theme.appBarTheme.foregroundColor,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: theme.appBarTheme.foregroundColor,
                  ),
            onPressed: _isFetching ? null : _loadAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(children: [
                Icon(Icons.access_time, color: mutedTextColor, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(_statusMsg, style: TextStyle(color: secondaryTextColor, fontSize: 12))),
              ]),
            ),

            _baselineCard(),
            _lstmScoreCard(),

            _card(
              title: 'Screen Time Today  (live)',
              value: screenDisplay != null ? '${screenDisplay.toStringAsFixed(1)} h' : '--',
              icon: Icons.phone_android_outlined,
              valueColor: screenAbove ? AppColors.saffronAccent : null,
              subtitle: b != null ? 'avg: ${b.avgScreenTime.toStringAsFixed(1)}h  · threshold: ${b.thresholdScreenTime.toStringAsFixed(1)}h' : null,
              highlight: screenAbove,
            ),

            _card(
              title: 'App Switches / hr',
              value: today != null ? '${today.appSwitchesPerHour}' : '--',
              icon: Icons.swap_horiz_outlined,
              subtitle: b != null ? 'avg: ${b.avgAppSwitchesPerHour}/hr  · threshold: ${b.thresholdAppSwitches}/hr' : null,
              valueColor: (today != null && b != null && today.appSwitchesPerHour > b.thresholdAppSwitches) ? AppColors.saffronAccent : null,
              highlight: today != null && b != null && today.appSwitchesPerHour > b.thresholdAppSwitches,
            ),

            _card(
              title: 'Social App Usage',
              value: today != null ? '${(today.socialAppRatio * 100).toStringAsFixed(0)}%' : '--',
              icon: Icons.people_outline,
              subtitle: b != null ? 'avg: ${(b.avgSocialRatio * 100).toStringAsFixed(0)}%  · threshold: ${(b.thresholdSocialRatio * 100).toStringAsFixed(0)}%' : null,
              valueColor: (today != null && b != null && today.socialAppRatio > b.thresholdSocialRatio) ? AppColors.saffronAccent : null,
            ),

            _card(
              title: 'Work App Usage',
              value: today != null ? '${(today.workAppRatio * 100).toStringAsFixed(0)}%' : '--',
              icon: Icons.work_outline,
              subtitle: b != null ? 'avg: ${(b.avgWorkRatio * 100).toStringAsFixed(0)}%' : null,
            ),

            const SizedBox(height: 6),

            if (alerts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.saffronAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.saffronAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.warning_amber_outlined, color: AppColors.saffronAccent, size: 18),
                      SizedBox(width: 8),
                      Text('Deviation from Your 7-Day Normal', style: TextStyle(color: AppColors.saffronAccent, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ...alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(a, style: TextStyle(color: primaryTextColor, fontSize: 13)),
                        )),
                  ],
                ),
              ),

            _chart(
              title: 'Screen Time  (hours)',
              spots: screenSpots,
              maxY: screenSpots.isEmpty ? 16.0 : (screenSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.4).clamp(4.0, 24.0),
              color: primaryTextColor,
              threshY: b?.thresholdScreenTime,
              avgY:    b?.avgScreenTime,
            ),
            const SizedBox(height: 14),
            _chart(
              title: 'App Switches / hr',
              spots: switchSpots,
              maxY: switchSpots.isEmpty ? 80.0 : (switchSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.4).clamp(20.0, 120.0),
              isInt: true,
              color: AppColors.saffronAccent,
              threshY: b?.thresholdAppSwitches.toDouble(),
              avgY:    b?.avgAppSwitchesPerHour.toDouble(),
            ),
            const SizedBox(height: 14),
            _chart(
              title: 'Social App Usage',
              spots: socialSpots,
              maxY: socialSpots.isEmpty ? 1.0 : (socialSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.4).clamp(0.5, 1.5),
              color: AppColors.greenAccent,
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