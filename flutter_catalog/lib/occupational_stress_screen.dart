import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'config/api_config.dart';

class OccupationalStressScreen extends StatefulWidget {
  const OccupationalStressScreen({super.key});

  @override
  State<OccupationalStressScreen> createState() =>
      _OccupationalStressScreenState();
}

class _OccupationalStressScreenState extends State<OccupationalStressScreen> {
  bool isLoading = false;

  // [CONTEXT] items
  double dutyHoursPerDay = 8;
  double nightDutiesLast2wks = 2;
  double consecutiveDaysNoRest = 3;
  double daysSinceLastLeave = 20;
  double leaveDaysTaken3mo = 5;
  double recoveryQuality = 3;
  double familyTime = 3;

  // [MODEL] items
  double demand = 3;
  double control = 3;
  double support = 3;
  double effort = 3;
  double reward = 3;

  // Result state
  String? riskLevel;
  int? score;
  List<dynamic> modelContributors = [];
  List<dynamic> contextContributors = [];
  List<dynamic> protectiveFactors = [];
  String? errorText;

  Future<void> runAssessment() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

    final body = {
      "firebase_uid": uid,
      "duty_hours_per_day": dutyHoursPerDay,
      "night_duties_last_2wks": nightDutiesLast2wks,
      "consecutive_days_no_rest": consecutiveDaysNoRest,
      "days_since_last_leave": daysSinceLastLeave,
      "leave_days_taken_3mo": leaveDaysTaken3mo,
      "recovery_quality": recoveryQuality.round(),
      "family_time": familyTime.round(),
      "demand": demand.round(),
      "control": control.round(),
      "support": support.round(),
      "effort": effort.round(),
      "reward": reward.round(),
    };

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.instance.baseUrl}/occupational/assess'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          riskLevel = data["risk_level"].toString();
          score = data["score"] as int;
          modelContributors = data["model_contributors"] ?? [];
          contextContributors = data["context_contributors"] ?? [];
          protectiveFactors = data["protective_factors"] ?? [];
        });
      } else {
        setState(() => errorText = 'API failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void resetFields() {
    setState(() {
      dutyHoursPerDay = 8;
      nightDutiesLast2wks = 2;
      consecutiveDaysNoRest = 3;
      daysSinceLastLeave = 20;
      leaveDaysTaken3mo = 5;
      recoveryQuality = 3;
      familyTime = 3;
      demand = 3;
      control = 3;
      support = 3;
      effort = 3;
      reward = 3;
      riskLevel = null;
      score = null;
      modelContributors = [];
      contextContributors = [];
      protectiveFactors = [];
      errorText = null;
    });
  }

  Color getRiskColor() {
    switch (riskLevel) {
      case 'Low':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  Widget buildSliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF232325),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(
              width: 30,
              child: Text(
                min % 1 == 0 ? min.toInt().toString() : min.toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: displayValue,
                activeColor: Colors.orange,
                inactiveColor: Colors.white24,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                max % 1 == 0 ? max.toInt().toString() : max.toString(),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(displayValue,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }

  // 5-point Likert rendered the same as a slider card, but locked to
  // integer steps 1-5 with a fixed low/high caption instead of raw numbers.
  Widget buildLikertCard({
    required String title,
    required String lowLabel,
    required String highLabel,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF232325),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Slider(
                value: value,
                min: 1,
                max: 5,
                divisions: 4,
                label: value.round().toString(),
                activeColor: Colors.orange,
                inactiveColor: Colors.white24,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(value.round().toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lowLabel, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text(highLabel, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }

  Widget buildQuestions() {
    return Column(children: [
      buildSectionHeader('DUTY & RECOVERY'),
      buildSliderCard(
          title: 'Hours actively on duty per day',
          value: dutyHoursPerDay, min: 4, max: 16, divisions: 12,
          displayValue: dutyHoursPerDay.toStringAsFixed(0),
          onChanged: (v) => setState(() => dutyHoursPerDay = v)),
      buildSliderCard(
          title: 'Night duties/shifts (last 2 weeks)',
          value: nightDutiesLast2wks, min: 0, max: 14, divisions: 14,
          displayValue: nightDutiesLast2wks.toStringAsFixed(0),
          onChanged: (v) => setState(() => nightDutiesLast2wks = v)),
      buildSliderCard(
          title: 'Consecutive days without a full rest day',
          value: consecutiveDaysNoRest, min: 0, max: 30, divisions: 30,
          displayValue: consecutiveDaysNoRest.toStringAsFixed(0),
          onChanged: (v) => setState(() => consecutiveDaysNoRest = v)),
      buildSliderCard(
          title: 'Days since your last leave/off day',
          value: daysSinceLastLeave, min: 0, max: 180, divisions: 36,
          displayValue: daysSinceLastLeave.toStringAsFixed(0),
          onChanged: (v) => setState(() => daysSinceLastLeave = v)),
      buildSliderCard(
          title: 'Leave days actually taken (last 3 months)',
          value: leaveDaysTaken3mo, min: 0, max: 30, divisions: 30,
          displayValue: leaveDaysTaken3mo.toStringAsFixed(0),
          onChanged: (v) => setState(() => leaveDaysTaken3mo = v)),
      buildLikertCard(
          title: 'Sleep/recovery quality this week',
          lowLabel: 'Very poor', highLabel: 'Excellent',
          value: recoveryQuality,
          onChanged: (v) => setState(() => recoveryQuality = v)),
      buildLikertCard(
          title: 'Quality time with family/loved ones (2 weeks)',
          lowLabel: 'None', highLabel: 'Plenty',
          value: familyTime,
          onChanged: (v) => setState(() => familyTime = v)),

      buildSectionHeader('WORKLOAD & SUPPORT'),
      buildLikertCard(
          title: 'How demanding is your current workload?',
          lowLabel: 'Very light', highLabel: 'Very demanding',
          value: demand,
          onChanged: (v) => setState(() => demand = v)),
      buildLikertCard(
          title: 'How much control/say over how & when you work?',
          lowLabel: 'None', highLabel: 'A great deal',
          value: control,
          onChanged: (v) => setState(() => control = v)),
      buildLikertCard(
          title: 'How supported do you feel by supervisors/organisation?',
          lowLabel: 'Not at all', highLabel: 'Fully',
          value: support,
          onChanged: (v) => setState(() => support = v)),
      buildLikertCard(
          title: "Effort required relative to what's expected?",
          lowLabel: 'Much less', highLabel: 'Much more',
          value: effort,
          onChanged: (v) => setState(() => effort = v)),
      buildLikertCard(
          title: 'How adequately recognised/rewarded for that effort?',
          lowLabel: 'Not at all', highLabel: 'Very well',
          value: reward,
          onChanged: (v) => setState(() => reward = v)),
    ]);
  }

  Widget buildChipList(List<dynamic> items, Color color, IconData icon) {
    if (items.isEmpty) {
      return const Text('None flagged',
          style: TextStyle(color: Colors.white38, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final label = item is Map ? (item['label'] ?? item.toString()) : item.toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ]),
        );
      }).toList(),
    );
  }

  Widget buildResultPanel() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A5CE6).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_outlined, color: Color(0xFF8A5CE6), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ApiConfig.instance.baseUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF232325),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Occupational stress risk',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(riskLevel ?? '--',
                    style: TextStyle(
                        color: getRiskColor(), fontSize: 22, fontWeight: FontWeight.bold)),
                Text(score != null ? '$score / 100' : '--',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],

          if (riskLevel != null) ...[
            const SizedBox(height: 18),
            const Text('Main contributors',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            buildChipList(modelContributors, Colors.redAccent, Icons.trending_up),

            const SizedBox(height: 16),
            const Text('Context factors',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            buildChipList(contextContributors, Colors.orangeAccent, Icons.info_outline),

            const SizedBox(height: 16),
            const Text('Protective factors',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            buildChipList(protectiveFactors, Colors.greenAccent, Icons.shield_outlined),
          ],

          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : runAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45199D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Assess', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : resetFields,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          const Text(
            'This is an early-warning wellness/stress-risk indicator based on '
            'self-reported information. It does not diagnose depression, '
            'anxiety, PTSD, or any medical or psychological condition.',
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text('Occupational Stress',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return SingleChildScrollView(
                child: Column(children: [
                  buildQuestions(),
                  const SizedBox(height: 16),
                  buildResultPanel(),
                ]),
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: SingleChildScrollView(child: buildQuestions())),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: SingleChildScrollView(child: buildResultPanel())),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
