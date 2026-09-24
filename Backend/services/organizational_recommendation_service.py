"""
organizational_recommendation_service.py
──────────────────────────────────────────────────────────────────────────────
Generates operational workload and welfare recommendations for Unit Commanders
and Welfare Officers.

STRICT ADVISORY NOTICE:
- These recommendations are advisory only.
- They do NOT automatically modify duty rosters or operational assignments.
──────────────────────────────────────────────────────────────────────────────
"""

from typing import List, Optional
from repositories.organizational_repository import OrganizationalRepository
from schemas.organizational import OrgIndicatorsOut, OrgRecommendationItem
from services.organizational_analytics_service import OrganizationalAnalyticsService


class OrganizationalRecommendationService:
    def __init__(
        self,
        repository: Optional[OrganizationalRepository] = None,
        analytics: Optional[OrganizationalAnalyticsService] = None,
    ):
        self._repo = repository or OrganizationalRepository()
        self._analytics = analytics or OrganizationalAnalyticsService(self._repo)

    def get_organizational_recommendations(
        self, unit_id: Optional[str] = None
    ) -> List[OrgRecommendationItem]:
        records = (
            self._repo.get_hr_demo_records_by_unit(unit_id)
            if unit_id
            else self._repo.get_all_hr_demo_records()
        )
        indicators: OrgIndicatorsOut = self._analytics.calculate_indicators(records)

        recommendations: List[OrgRecommendationItem] = []

        # High workload
        if indicators.workload_pressure in ("High", "Elevated"):
            recommendations.append(
                OrgRecommendationItem(
                    category="Workload Optimization",
                    trigger=f"Unit workload pressure is {indicators.workload_pressure}",
                    recommendation="Review workload distribution where operationally feasible.",
                    scope="Command & Operations",
                    is_advisory_only=True,
                )
            )

        # High night duty
        if indicators.night_duty_load in ("High", "Elevated"):
            recommendations.append(
                OrgRecommendationItem(
                    category="Duty Shift Fatigue",
                    trigger=f"Night duty load is {indicators.night_duty_load}",
                    recommendation="Review duty rotation and recovery scheduling.",
                    scope="Unit Welfare & Rostering",
                    is_advisory_only=True,
                )
            )

        # Low recovery
        if indicators.recovery_deficit in ("Needs Attention", "Moderate"):
            recommendations.append(
                OrgRecommendationItem(
                    category="Recovery & Rest Management",
                    trigger=f"Recovery indicators indicate {indicators.recovery_deficit}",
                    recommendation="Consider appropriate recovery/leave planning.",
                    scope="Unit Command & HR",
                    is_advisory_only=True,
                )
            )

        # Long deployment
        if indicators.deployment_burden in ("Extended", "Moderate"):
            recommendations.append(
                OrgRecommendationItem(
                    category="Deployment Resilience",
                    trigger=f"Deployment duration is {indicators.deployment_burden}",
                    recommendation="Review recovery opportunities following extended deployment.",
                    scope="Command Leadership",
                    is_advisory_only=True,
                )
            )

        # General baseline recommendation if everything is normal
        if not recommendations:
            recommendations.append(
                OrgRecommendationItem(
                    category="Routine Wellness Maintenance",
                    trigger="Indicators within standard parameters",
                    recommendation="Maintain balanced shift rotation and promote regular recovery check-ins.",
                    scope="Unit Welfare Officer",
                    is_advisory_only=True,
                )
            )

        return recommendations
