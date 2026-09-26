// Data models for the Veer Mitra Organizational & Welfare Layer.

class UserProfileRole {
  final int id;
  final String firebaseUid;
  final String personnelId;
  final String role;
  final String unitId;
  final String? rankDesignation;
  final bool optInOptionalWellness;
  final String createdAt;

  UserProfileRole({
    required this.id,
    required this.firebaseUid,
    required this.personnelId,
    required this.role,
    required this.unitId,
    this.rankDesignation,
    required this.optInOptionalWellness,
    required this.createdAt,
  });

  factory UserProfileRole.fromJson(Map<String, dynamic> json) {
    return UserProfileRole(
      id: json['id'] as int? ?? 0,
      firebaseUid: json['firebase_uid'] as String? ?? '',
      personnelId: json['personnel_id'] as String? ?? '',
      role: json['role'] as String? ?? 'personnel',
      unitId: json['unit_id'] as String? ?? 'UNIT-ALPHA',
      rankDesignation: json['rank_designation'] as String?,
      optInOptionalWellness: json['opt_in_optional_wellness'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isPersonnel => role == 'personnel';
  bool get isWelfareOfficer => role == 'welfare_officer';
  bool get isCommander => role == 'commander';
  bool get isAdmin => role == 'admin';
}

class TopContributor {
  final String label;
  final int affectedCount;
  final double percentage;

  TopContributor({
    required this.label,
    required this.affectedCount,
    required this.percentage,
  });

  factory TopContributor.fromJson(Map<String, dynamic> json) {
    return TopContributor(
      label: json['label'] as String? ?? '',
      affectedCount: json['affected_count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UnitOverview {
  final String unitId;
  final int personnelCount;
  final int averageStress;
  final int lowRiskCount;
  final int moderateRiskCount;
  final int highRiskCount;
  final double highRiskPct;
  final int worseningTrendCount;
  final int activeAlertsCount;
  final String workloadPressure;
  final String nightDutyLoad;
  final String recoveryStatus;

  UnitOverview({
    required this.unitId,
    required this.personnelCount,
    required this.averageStress,
    required this.lowRiskCount,
    required this.moderateRiskCount,
    required this.highRiskCount,
    required this.highRiskPct,
    required this.worseningTrendCount,
    required this.activeAlertsCount,
    required this.workloadPressure,
    required this.nightDutyLoad,
    required this.recoveryStatus,
  });

  factory UnitOverview.fromJson(Map<String, dynamic> json) {
    return UnitOverview(
      unitId: json['unit_id'] as String? ?? '',
      personnelCount: json['personnel_count'] as int? ?? 0,
      averageStress: json['average_stress'] as int? ?? 0,
      lowRiskCount: json['low_risk_count'] as int? ?? 0,
      moderateRiskCount: json['moderate_risk_count'] as int? ?? 0,
      highRiskCount: json['high_risk_count'] as int? ?? 0,
      highRiskPct: (json['high_risk_pct'] as num?)?.toDouble() ?? 0.0,
      worseningTrendCount: json['worsening_trend_count'] as int? ?? 0,
      activeAlertsCount: json['active_alerts_count'] as int? ?? 0,
      workloadPressure: json['workload_pressure'] as String? ?? 'Normal',
      nightDutyLoad: json['night_duty_load'] as String? ?? 'Normal',
      recoveryStatus: json['recovery_status'] as String? ?? 'Low',
    );
  }
}

class WelfareOverview {
  final int totalPersonnelMonitored;
  final int lowRiskCount;
  final double lowRiskPct;
  final int moderateRiskCount;
  final double moderateRiskPct;
  final int highRiskCount;
  final double highRiskPct;
  final int worseningTrendCount;
  final int activeAlertsCount;
  final int averageStressScore;
  final List<TopContributor> topContributors;
  final List<UnitOverview> unitOverviews;
  final String disclaimer;

  WelfareOverview({
    required this.totalPersonnelMonitored,
    required this.lowRiskCount,
    required this.lowRiskPct,
    required this.moderateRiskCount,
    required this.moderateRiskPct,
    required this.highRiskCount,
    required this.highRiskPct,
    required this.worseningTrendCount,
    required this.activeAlertsCount,
    required this.averageStressScore,
    required this.topContributors,
    required this.unitOverviews,
    required this.disclaimer,
  });

  factory WelfareOverview.fromJson(Map<String, dynamic> json) {
    return WelfareOverview(
      totalPersonnelMonitored: json['total_personnel_monitored'] as int? ?? 0,
      lowRiskCount: json['low_risk_count'] as int? ?? 0,
      lowRiskPct: (json['low_risk_pct'] as num?)?.toDouble() ?? 0.0,
      moderateRiskCount: json['moderate_risk_count'] as int? ?? 0,
      moderateRiskPct: (json['moderate_risk_pct'] as num?)?.toDouble() ?? 0.0,
      highRiskCount: json['high_risk_count'] as int? ?? 0,
      highRiskPct: (json['high_risk_pct'] as num?)?.toDouble() ?? 0.0,
      worseningTrendCount: json['worsening_trend_count'] as int? ?? 0,
      activeAlertsCount: json['active_alerts_count'] as int? ?? 0,
      averageStressScore: json['average_stress_score'] as int? ?? 50,
      topContributors: (json['top_contributors'] as List<dynamic>? ?? [])
          .map((e) => TopContributor.fromJson(e as Map<String, dynamic>))
          .toList(),
      unitOverviews: (json['unit_overviews'] as List<dynamic>? ?? [])
          .map((e) => UnitOverview.fromJson(e as Map<String, dynamic>))
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? 'Synthetic demonstration data',
    );
  }
}

class WelfareAlertItem {
  final int id;
  final String alertId;
  final String personnelId;
  final String unitId;
  final String alertType;
  final String severity; // 'low', 'moderate', 'high'
  final String title;
  final String message;
  final String status; // 'active', 'acknowledged', 'resolved'
  final String createdAt;

  WelfareAlertItem({
    required this.id,
    required this.alertId,
    required this.personnelId,
    required this.unitId,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory WelfareAlertItem.fromJson(Map<String, dynamic> json) {
    return WelfareAlertItem(
      id: json['id'] as int? ?? 0,
      alertId: json['alert_id'] as String? ?? '',
      personnelId: json['personnel_id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      alertType: json['alert_type'] as String? ?? '',
      severity: json['severity'] as String? ?? 'moderate',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isActive => status == 'active';
  bool get isHigh => severity.toLowerCase() == 'high';
}

class PersonnelWelfareSummary {
  final String personnelId;
  final String unitId;
  final String riskLevel; // 'Low', 'Moderate', 'High'
  final int score;
  final String trend; // 'Improving', 'Stable', 'Worsening', 'Not enough data'
  final int activeAlertsCount;
  final String workloadLevel;
  final double dutyHours;
  final int consecutiveDutyDays;
  final String? lastAssessed;
  final bool optInOptionalWellness;

  PersonnelWelfareSummary({
    required this.personnelId,
    required this.unitId,
    required this.riskLevel,
    required this.score,
    required this.trend,
    required this.activeAlertsCount,
    required this.workloadLevel,
    required this.dutyHours,
    required this.consecutiveDutyDays,
    this.lastAssessed,
    required this.optInOptionalWellness,
  });

  factory PersonnelWelfareSummary.fromJson(Map<String, dynamic> json) {
    return PersonnelWelfareSummary(
      personnelId: json['personnel_id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'Low',
      score: json['score'] as int? ?? 0,
      trend: json['trend'] as String? ?? 'Stable',
      activeAlertsCount: json['active_alerts_count'] as int? ?? 0,
      workloadLevel: json['workload_level'] as String? ?? 'Normal',
      dutyHours: (json['duty_hours'] as num?)?.toDouble() ?? 8.0,
      consecutiveDutyDays: json['consecutive_duty_days'] as int? ?? 0,
      lastAssessed: json['last_assessed'] as String?,
      optInOptionalWellness: json['opt_in_optional_wellness'] as bool? ?? false,
    );
  }
}

class CommanderUnitSummary {
  final String unitId;
  final int averageStress;
  final double highRiskPct;
  final Map<String, int> riskDistribution;
  final String workloadPressure;
  final String nightDutyLoad;
  final String recoveryStatus;
  final String deploymentLoad;
  final String trainingLoad;
  final List<String> recommendations;
  final String privacyNotice;
  final String disclaimer;

  CommanderUnitSummary({
    required this.unitId,
    required this.averageStress,
    required this.highRiskPct,
    required this.riskDistribution,
    required this.workloadPressure,
    required this.nightDutyLoad,
    required this.recoveryStatus,
    required this.deploymentLoad,
    required this.trainingLoad,
    required this.recommendations,
    required this.privacyNotice,
    required this.disclaimer,
  });

  factory CommanderUnitSummary.fromJson(Map<String, dynamic> json) {
    final distMap = <String, int>{};
    if (json['risk_distribution'] is Map) {
      (json['risk_distribution'] as Map).forEach((key, val) {
        distMap[key.toString()] = (val as num?)?.toInt() ?? 0;
      });
    }

    final recsList = (json['recommendations'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return CommanderUnitSummary(
      unitId: json['unit_id'] as String? ?? '',
      averageStress: json['average_stress'] as int? ?? 0,
      highRiskPct: (json['high_risk_pct'] as num?)?.toDouble() ?? 0.0,
      riskDistribution: distMap,
      workloadPressure: json['workload_pressure'] as String? ?? 'Normal',
      nightDutyLoad: json['night_duty_load'] as String? ?? 'Normal',
      recoveryStatus: json['recovery_status'] as String? ?? 'Low',
      deploymentLoad: json['deployment_load'] as String? ?? 'Standard',
      trainingLoad: json['training_load'] as String? ?? 'Balanced',
      recommendations: recsList,
      privacyNotice: json['privacy_notice'] as String? ??
          'Privacy Protected: Aggregate metrics only.',
      disclaimer: json['disclaimer'] as String? ?? 'Synthetic demonstration data',
    );
  }
}

class OrgRecommendation {
  final String category;
  final String trigger;
  final String recommendation;
  final String scope;
  final bool isAdvisoryOnly;

  OrgRecommendation({
    required this.category,
    required this.trigger,
    required this.recommendation,
    required this.scope,
    required this.isAdvisoryOnly,
  });

  factory OrgRecommendation.fromJson(Map<String, dynamic> json) {
    return OrgRecommendation(
      category: json['category'] as String? ?? '',
      trigger: json['trigger'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
      scope: json['scope'] as String? ?? 'Unit Command',
      isAdvisoryOnly: json['is_advisory_only'] as bool? ?? true,
    );
  }
}

class AuditLogItem {
  final int id;
  final String actorUid;
  final String actorRole;
  final String action;
  final String targetType;
  final String? targetId;
  final String timestamp;

  AuditLogItem({
    required this.id,
    required this.actorUid,
    required this.actorRole,
    required this.action,
    required this.targetType,
    this.targetId,
    required this.timestamp,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] as int? ?? 0,
      actorUid: json['actor_uid'] as String? ?? '',
      actorRole: json['actor_role'] as String? ?? '',
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}
