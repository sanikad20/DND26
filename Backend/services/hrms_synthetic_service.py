"""
hrms_synthetic_service.py
──────────────────────────────────────────────────────────────────────────────
Generates and manages the synthetic demonstration HRMS data layer.

CRITICAL MODEL HONESTY & PRIVACY NOTICE:
- This is purely SYNTHETIC DEMONSTRATION DATA.
- It is NOT real CRPF, CAPF, or police personnel data.
- It is strictly SEPARATE from the existing individual occupational ML model.
- It is NEVER used to retrain or adjust the ML model weights.
──────────────────────────────────────────────────────────────────────────────
"""

import random
from typing import Any, Dict, List, Optional
from repositories.organizational_repository import OrganizationalRepository


UNITS = ["UNIT-ALPHA", "UNIT-BRAVO", "UNIT-CHARLIE"]


class HRMSSyntheticService:
    def __init__(self, repository: Optional[OrganizationalRepository] = None):
        self._repo = repository or OrganizationalRepository()

    def is_seeded(self) -> bool:
        return self._repo.count_hr_demo_records() >= 100

    def seed_demo_dataset_if_empty(self) -> None:
        """Seeds 100 synthetic demonstration personnel and HRMS records,
        providing a realistic demo dashboard with:
          - 100 Personnel Monitored
          - 58 Low Risk
          - 31 Moderate Risk
          - 11 High Risk
          - 8 Worsening Trends
          - 5 Active Welfare Alerts
          - ~54/100 Average Stress Score
        """
        if self.is_seeded():
            return

        random.seed(42)  # Deterministic seed for reproducible demo numbers

        records_data: List[Dict[str, Any]] = []
        alerts_data: List[Dict[str, Any]] = []

        # 100 demo personnel: PERS-1001 to PERS-1100
        # 58 low risk (indices 0..57)
        # 31 moderate risk (indices 58..88)
        # 11 high risk (indices 89..99)
        for i in range(100):
            pid = f"PERS-{1001 + i}"
            unit = UNITS[i % len(UNITS)]

            if i < 58:
                # Low risk persona
                duty_hours = round(random.uniform(7.5, 9.0), 1)
                night_shifts = random.randint(0, 2)
                consecutive_days = random.randint(0, 5)
                leave_days = random.randint(12, 28)
                deployment_days = random.randint(0, 30)
                transfers = random.randint(0, 2)
                training_days = random.randint(10, 25)
                workload = "Normal"
            elif i < 89:
                # Moderate risk persona
                duty_hours = round(random.uniform(9.0, 11.5), 1)
                night_shifts = random.randint(3, 5)
                consecutive_days = random.randint(6, 11)
                leave_days = random.randint(4, 12)
                deployment_days = random.randint(30, 75)
                transfers = random.randint(1, 3)
                training_days = random.randint(5, 14)
                workload = "Elevated"
            else:
                # High risk persona
                duty_hours = round(random.uniform(11.5, 14.5), 1)
                night_shifts = random.randint(6, 9)
                consecutive_days = random.randint(12, 21)
                leave_days = random.randint(0, 3)
                deployment_days = random.randint(80, 160)
                transfers = random.randint(2, 5)
                training_days = random.randint(0, 4)
                workload = "High"

            rec = {
                "personnel_id": pid,
                "unit_id": unit,
                "duty_hours": duty_hours,
                "night_shift_count": night_shifts,
                "consecutive_duty_days": consecutive_days,
                "leave_days": leave_days,
                "deployment_days": deployment_days,
                "transfer_count": transfers,
                "training_days": training_days,
                "workload_level": workload,
                "is_synthetic": True,
                "data_notice": "Synthetic demonstration data",
            }
            records_data.append(rec)

            # Auto-provision personnel profile linked to a demo UID
            demo_uid = f"demo_user_{pid.lower().replace('-', '_')}"
            self._repo.get_or_create_profile(
                firebase_uid=demo_uid,
                default_role="personnel",
                default_unit=unit,
                default_pid=pid,
            )

        self._repo.bulk_insert_hr_demo_records(records_data)

        # Generate 5 Active Welfare Alerts (using privacy-conscious, supportive wording)
        alerts_spec = [
            (
                "ALT-1001",
                "PERS-1092",
                "UNIT-ALPHA",
                "HIGH_RISK_WORSENING_TREND",
                "high",
                "Wellness follow-up recommended",
                "Personnel assessment trend indicates increasing stress patterns over consecutive periods. Consider supportive wellness outreach.",
            ),
            (
                "ALT-1002",
                "PERS-1095",
                "UNIT-BRAVO",
                "WORKLOAD_RECOVERY_DEFICIT",
                "high",
                "Recovery balance check-in recommended",
                "Elevated continuous duty hours (>13h) with limited recent rest intervals detected. Operational workload review suggested.",
            ),
            (
                "ALT-1003",
                "PERS-1097",
                "UNIT-CHARLIE",
                "HIGH_NIGHT_DUTY",
                "moderate",
                "Night-duty rotation review recommended",
                "Personnel has completed 8 night shifts in recent duty roster. Consider fatigue-mitigation rotation.",
            ),
            (
                "ALT-1004",
                "PERS-1099",
                "UNIT-ALPHA",
                "EXTENDED_DEPLOYMENT",
                "moderate",
                "Post-deployment resilience review",
                "Personnel has completed 140+ consecutive deployment days. Review leave and rest opportunities following deployment phase.",
            ),
            (
                "ALT-1005",
                "PERS-1100",
                "UNIT-BRAVO",
                "REPEATED_ELEVATED_STRESS",
                "high",
                "Proactive welfare check-in recommended",
                "Elevated stress indicators recorded over multiple assessment periods. Routine supportive check-in advised.",
            ),
        ]

        for aid, pid, unit, atype, sev, title, msg in alerts_spec:
            alert_dict = {
                "alert_id": aid,
                "personnel_id": pid,
                "unit_id": unit,
                "alert_type": atype,
                "severity": sev,
                "title": title,
                "message": msg,
                "status": "active",
            }
            self._repo.create_alert(alert_dict)

    def get_all_records(self) -> List[Any]:
        return self._repo.get_all_hr_demo_records()

    def get_unit_records(self, unit_id: str) -> List[Any]:
        return self._repo.get_hr_demo_records_by_unit(unit_id)

    def get_personnel_record(self, personnel_id: str) -> Optional[Any]:
        return self._repo.get_hr_demo_record_by_pid(personnel_id)
