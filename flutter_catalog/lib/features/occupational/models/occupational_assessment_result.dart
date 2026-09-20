import 'occupational_plan_day.dart';

class OccupationalFactor {
  final String label;
  final String layer;

  const OccupationalFactor({required this.label, required this.layer});

  factory OccupationalFactor.fromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return OccupationalFactor(
        label: value['label']?.toString() ?? 'Unknown factor',
        layer: value['layer']?.toString() ?? '',
      );
    }
    return OccupationalFactor(label: value.toString(), layer: '');
  }

  Map<String, dynamic> toJson() => {'label': label, 'layer': layer};
}

/// A recommendation from the backend, tied to the contributor that
/// triggered it (e.g. label "High workload").
class OccupationalRecommendation {
  final String label;
  final String text;

  const OccupationalRecommendation({required this.label, required this.text});

  factory OccupationalRecommendation.fromJson(Map<String, dynamic> data) {
    return OccupationalRecommendation(
      label: data['label']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'text': text};
}

class OccupationalAssessmentResult {
  final String riskLevel;
  final int score;
  final List<OccupationalFactor> modelContributors;
  final List<OccupationalFactor> contextContributors;
  final List<String> protectiveFactors;
  final String modelVersion;
  final bool placeholderScoring;
  final DateTime generatedAt;

  /// Recommendations and plan come from the backend (single source of truth).
  /// Empty for assessments saved by an older app version.
  final List<OccupationalRecommendation> recommendationItems;
  final List<OccupationalPlanDay> plan;

  const OccupationalAssessmentResult({
    required this.riskLevel,
    required this.score,
    required this.modelContributors,
    required this.contextContributors,
    required this.protectiveFactors,
    required this.modelVersion,
    required this.placeholderScoring,
    required this.generatedAt,
    this.recommendationItems = const [],
    this.plan = const [],
  });

  factory OccupationalAssessmentResult.fromJson(Map<String, dynamic> data) {
    final modelItems = (data['model_contributors'] as List<dynamic>? ?? [])
        .map(OccupationalFactor.fromJson)
        .toList();
    final contextItems = (data['context_contributors'] as List<dynamic>? ?? [])
        .map(OccupationalFactor.fromJson)
        .toList();
    final protectiveItems = (data['protective_factors'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    final recommendationItems =
        (data['recommendation_items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(OccupationalRecommendation.fromJson)
            .toList();
    final planItems = (data['plan'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => OccupationalPlanDay(
            day: int.tryParse(item['day'].toString()) ?? 0,
            title: item['title']?.toString() ?? '',
            explanation: item['detail']?.toString() ?? '',
            tasks: (item['tasks'] as List<dynamic>? ?? [])
                .map((task) => task.toString())
                .toList(),
          ),
        )
        .toList();

    return OccupationalAssessmentResult(
      riskLevel: data['risk_level']?.toString() ?? 'Unknown',
      score: int.tryParse(data['score'].toString()) ?? 0,
      modelContributors: modelItems,
      contextContributors: contextItems,
      protectiveFactors: protectiveItems,
      modelVersion: data['model_version']?.toString() ?? '',
      placeholderScoring: data['placeholder_scoring'] == true,
      generatedAt:
          DateTime.tryParse(data['generated_at']?.toString() ?? '') ??
          DateTime.now(),
      recommendationItems: recommendationItems,
      plan: planItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'risk_level': riskLevel,
    'score': score,
    'model_contributors': modelContributors
        .map((item) => item.toJson())
        .toList(),
    'context_contributors': contextContributors
        .map((item) => item.toJson())
        .toList(),
    'protective_factors': protectiveFactors,
    'model_version': modelVersion,
    'placeholder_scoring': placeholderScoring,
    'generated_at': generatedAt.toIso8601String(),
    'recommendation_items': recommendationItems
        .map((item) => item.toJson())
        .toList(),
    'plan': plan
        .map(
          (day) => {
            'day': day.day,
            'title': day.title,
            'detail': day.explanation,
            'tasks': day.tasks,
          },
        )
        .toList(),
  };

  List<String> get contributorLabels => [
    ...modelContributors.map((item) => item.label),
    ...contextContributors.map((item) => item.label),
  ];
}
