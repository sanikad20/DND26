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

class OccupationalAssessmentResult {
  final String riskLevel;
  final int score;
  final List<OccupationalFactor> modelContributors;
  final List<OccupationalFactor> contextContributors;
  final List<String> protectiveFactors;
  final String modelVersion;
  final bool placeholderScoring;
  final DateTime generatedAt;

  const OccupationalAssessmentResult({
    required this.riskLevel,
    required this.score,
    required this.modelContributors,
    required this.contextContributors,
    required this.protectiveFactors,
    required this.modelVersion,
    required this.placeholderScoring,
    required this.generatedAt,
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
  };

  List<String> get contributorLabels => [
    ...modelContributors.map((item) => item.label),
    ...contextContributors.map((item) => item.label),
  ];
}
