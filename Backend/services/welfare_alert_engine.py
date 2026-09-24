"""
welfare_alert_engine.py
──────────────────────────────────────────────────────────────────────────────
Generates and manages welfare alerts for authorized Welfare Officers.

STRICT TERMINOLOGY & ETHICAL GUIDELINES:
- Uses welfare-oriented, supportive language exclusively.
- NEVER uses disciplinary language.
- NEVER diagnoses depression, anxiety, PTSD, or any medical/psychological condition.
──────────────────────────────────────────────────────────────────────────────
"""

from datetime import datetime, timezone
import uuid
from typing import Any, Dict, List, Optional
from repositories.organizational_repository import OrganizationalRepository
from schemas.organizational import WelfareAlertOut


class WelfareAlertEngine:
    def __init__(self, repository: Optional[OrganizationalRepository] = None):
        self._repo = repository or OrganizationalRepository()

    def get_active_alerts(self, unit_id: Optional[str] = None) -> List[WelfareAlertOut]:
        alerts = self._repo.get_active_alerts(unit_id=unit_id)
        return [
            WelfareAlertOut(
                id=a.id,
                alert_id=a.alert_id,
                personnel_id=a.personnel_id,
                unit_id=a.unit_id,
                alert_type=a.alert_type,
                severity=a.severity,  # type: ignore
                title=a.title,
                message=a.message,
                status=a.status,  # type: ignore
                created_at=a.created_at.isoformat() if a.created_at else datetime.now(timezone.utc).isoformat(),
            )
            for a in alerts
        ]

    def acknowledge_alert(self, alert_id: str) -> Optional[WelfareAlertOut]:
        alert = self._repo.acknowledge_alert(alert_id)
        if not alert:
            return None
        return WelfareAlertOut(
            id=alert.id,
            alert_id=alert.alert_id,
            personnel_id=alert.personnel_id,
            unit_id=alert.unit_id,
            alert_type=alert.alert_type,
            severity=alert.severity,  # type: ignore
            title=alert.title,
            message=alert.message,
            status=alert.status,  # type: ignore
            created_at=alert.created_at.isoformat() if alert.created_at else datetime.now(timezone.utc).isoformat(),
        )

    def evaluate_personnel_for_alert(
        self,
        personnel_id: str,
        unit_id: str,
        risk_level: str,
        trend: str,
        duty_hours: float,
        consecutive_days: int,
        night_shifts: int,
        deployment_days: int,
    ) -> Optional[Dict[str, Any]]:
        """Evaluates operational indicators to generate a welfare alert if criteria are met."""
        alert_id = f"ALT-{uuid.uuid4().hex[:8].upper()}"

        # 1. High risk + worsening trend
        if risk_level == "High" and trend == "Worsening":
            return {
                "alert_id": alert_id,
                "personnel_id": personnel_id,
                "unit_id": unit_id,
                "alert_type": "HIGH_RISK_WORSENING_TREND",
                "severity": "high",
                "title": "Wellness follow-up recommended",
                "message": (
                    "Personnel assessment trend indicates increasing stress patterns over "
                    "consecutive periods. Consider supportive wellness outreach."
                ),
                "status": "active",
            }

        # 2. High workload + low recovery
        if duty_hours >= 12.0 and consecutive_days >= 12:
            return {
                "alert_id": alert_id,
                "personnel_id": personnel_id,
                "unit_id": unit_id,
                "alert_type": "WORKLOAD_RECOVERY_DEFICIT",
                "severity": "high",
                "title": "Recovery balance check-in recommended",
                "message": (
                    "Elevated continuous duty hours with limited recent rest intervals detected. "
                    "Operational workload review suggested."
                ),
                "status": "active",
            }

        # 3. High night duty load
        if night_shifts >= 7:
            return {
                "alert_id": alert_id,
                "personnel_id": personnel_id,
                "unit_id": unit_id,
                "alert_type": "HIGH_NIGHT_DUTY",
                "severity": "moderate",
                "title": "Night-duty rotation review recommended",
                "message": (
                    "Personnel has completed elevated night shifts in recent duty roster. "
                    "Consider fatigue-mitigation rotation."
                ),
                "status": "active",
            }

        # 4. Long deployment
        if deployment_days >= 120:
            return {
                "alert_id": alert_id,
                "personnel_id": personnel_id,
                "unit_id": unit_id,
                "alert_type": "EXTENDED_DEPLOYMENT",
                "severity": "moderate",
                "title": "Post-deployment resilience review",
                "message": (
                    "Personnel has completed extended deployment duration. "
                    "Review rest and family reintegration opportunities."
                ),
                "status": "active",
            }

        return None
