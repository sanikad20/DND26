from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from database import SessionLocal
from models import AuditLog, HRDemoRecord, PersonnelProfile, WelfareAlert


class OrganizationalRepository:
    def __init__(self, session_factory=SessionLocal):
        self._session_factory = session_factory

    def _get_db(self) -> Session:
        return self._session_factory()

    # ─────────────────────────────────────────────────────────────────────────
    # Personnel Profiles
    # ─────────────────────────────────────────────────────────────────────────

    def get_profile_by_firebase_uid(
        self, firebase_uid: str, db: Optional[Session] = None
    ) -> Optional[PersonnelProfile]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return (
                session.query(PersonnelProfile)
                .filter(PersonnelProfile.firebase_uid == firebase_uid)
                .first()
            )
        finally:
            if own_db:
                session.close()

    def get_or_create_profile(
        self,
        firebase_uid: str,
        default_role: str = "personnel",
        default_unit: str = "UNIT-ALPHA",
        default_pid: Optional[str] = None,
        db: Optional[Session] = None,
    ) -> PersonnelProfile:
        own_db = db is None
        session = db or self._get_db()
        try:
            profile = (
                session.query(PersonnelProfile)
                .filter(PersonnelProfile.firebase_uid == firebase_uid)
                .first()
            )
            if profile is not None:
                return profile

            # Auto-assign a unique demo personnel ID
            if not default_pid:
                count = session.query(PersonnelProfile).count()
                default_pid = f"PERS-{1000 + count + 1}"

            # If the UID contains role hints (e.g. for testing 'uid:welfare_officer_1')
            assigned_role = default_role
            if "welfare" in firebase_uid.lower():
                assigned_role = "welfare_officer"
            elif "commander" in firebase_uid.lower():
                assigned_role = "commander"
            elif "admin" in firebase_uid.lower():
                assigned_role = "admin"

            profile = PersonnelProfile(
                firebase_uid=firebase_uid,
                personnel_id=default_pid,
                role=assigned_role,
                unit_id=default_unit,
                rank_designation="Member",
                opt_in_optional_wellness=False,
            )
            session.add(profile)
            session.commit()
            session.refresh(profile)
            return profile
        finally:
            if own_db:
                session.close()

    def update_profile_role(
        self, firebase_uid: str, role: str, db: Optional[Session] = None
    ) -> Optional[PersonnelProfile]:
        own_db = db is None
        session = db or self._get_db()
        try:
            profile = (
                session.query(PersonnelProfile)
                .filter(PersonnelProfile.firebase_uid == firebase_uid)
                .first()
            )
            if not profile:
                profile = self.get_or_create_profile(
                    firebase_uid, default_role=role, db=session
                )
            profile.role = role
            session.commit()
            session.refresh(profile)
            return profile
        finally:
            if own_db:
                session.close()

    def update_profile_opt_in(
        self, firebase_uid: str, opt_in: bool, db: Optional[Session] = None
    ) -> Optional[PersonnelProfile]:
        own_db = db is None
        session = db or self._get_db()
        try:
            profile = (
                session.query(PersonnelProfile)
                .filter(PersonnelProfile.firebase_uid == firebase_uid)
                .first()
            )
            if not profile:
                profile = self.get_or_create_profile(firebase_uid, db=session)
            profile.opt_in_optional_wellness = opt_in
            session.commit()
            session.refresh(profile)
            return profile
        finally:
            if own_db:
                session.close()

    # ─────────────────────────────────────────────────────────────────────────
    # HR Demo Records
    # ─────────────────────────────────────────────────────────────────────────

    def count_hr_demo_records(self, db: Optional[Session] = None) -> int:
        own_db = db is None
        session = db or self._get_db()
        try:
            return session.query(HRDemoRecord).count()
        finally:
            if own_db:
                session.close()

    def get_all_hr_demo_records(
        self, db: Optional[Session] = None
    ) -> List[HRDemoRecord]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return session.query(HRDemoRecord).all()
        finally:
            if own_db:
                session.close()

    def get_hr_demo_records_by_unit(
        self, unit_id: str, db: Optional[Session] = None
    ) -> List[HRDemoRecord]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return (
                session.query(HRDemoRecord)
                .filter(HRDemoRecord.unit_id == unit_id)
                .all()
            )
        finally:
            if own_db:
                session.close()

    def get_hr_demo_record_by_pid(
        self, personnel_id: str, db: Optional[Session] = None
    ) -> Optional[HRDemoRecord]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return (
                session.query(HRDemoRecord)
                .filter(HRDemoRecord.personnel_id == personnel_id)
                .first()
            )
        finally:
            if own_db:
                session.close()

    def bulk_insert_hr_demo_records(
        self, records_data: List[Dict[str, Any]], db: Optional[Session] = None
    ) -> None:
        own_db = db is None
        session = db or self._get_db()
        try:
            records = [HRDemoRecord(**d) for d in records_data]
            session.bulk_save_objects(records)
            session.commit()
        finally:
            if own_db:
                session.close()

    # ─────────────────────────────────────────────────────────────────────────
    # Welfare Alerts
    # ─────────────────────────────────────────────────────────────────────────

    def get_active_alerts(
        self, unit_id: Optional[str] = None, db: Optional[Session] = None
    ) -> List[WelfareAlert]:
        own_db = db is None
        session = db or self._get_db()
        try:
            query = session.query(WelfareAlert).filter(WelfareAlert.status == "active")
            if unit_id:
                query = query.filter(WelfareAlert.unit_id == unit_id)
            return query.order_by(WelfareAlert.created_at.desc()).all()
        finally:
            if own_db:
                session.close()

    def count_active_alerts(
        self, unit_id: Optional[str] = None, db: Optional[Session] = None
    ) -> int:
        own_db = db is None
        session = db or self._get_db()
        try:
            query = session.query(WelfareAlert).filter(WelfareAlert.status == "active")
            if unit_id:
                query = query.filter(WelfareAlert.unit_id == unit_id)
            return query.count()
        finally:
            if own_db:
                session.close()

    def get_alert_by_id(
        self, alert_id: str, db: Optional[Session] = None
    ) -> Optional[WelfareAlert]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return (
                session.query(WelfareAlert)
                .filter(WelfareAlert.alert_id == alert_id)
                .first()
            )
        finally:
            if own_db:
                session.close()

    def acknowledge_alert(
        self, alert_id: str, db: Optional[Session] = None
    ) -> Optional[WelfareAlert]:
        own_db = db is None
        session = db or self._get_db()
        try:
            alert = (
                session.query(WelfareAlert)
                .filter(WelfareAlert.alert_id == alert_id)
                .first()
            )
            if alert:
                alert.status = "acknowledged"
                alert.resolved_at = datetime.now(timezone.utc)
                session.commit()
                session.refresh(alert)
            return alert
        finally:
            if own_db:
                session.close()

    def create_alert(
        self, alert_dict: Dict[str, Any], db: Optional[Session] = None
    ) -> WelfareAlert:
        own_db = db is None
        session = db or self._get_db()
        try:
            alert = WelfareAlert(**alert_dict)
            session.add(alert)
            session.commit()
            session.refresh(alert)
            return alert
        finally:
            if own_db:
                session.close()

    # ─────────────────────────────────────────────────────────────────────────
    # Audit Logs
    # ─────────────────────────────────────────────────────────────────────────

    def log_audit(
        self,
        actor_uid: str,
        actor_role: str,
        action: str,
        target_type: str,
        target_id: Optional[str] = None,
        db: Optional[Session] = None,
    ) -> AuditLog:
        own_db = db is None
        session = db or self._get_db()
        try:
            entry = AuditLog(
                actor_uid=actor_uid,
                actor_role=actor_role,
                action=action,
                target_type=target_type,
                target_id=target_id,
            )
            session.add(entry)
            session.commit()
            session.refresh(entry)
            return entry
        finally:
            if own_db:
                session.close()

    def get_audit_logs(
        self, limit: int = 50, db: Optional[Session] = None
    ) -> List[AuditLog]:
        own_db = db is None
        session = db or self._get_db()
        try:
            return (
                session.query(AuditLog)
                .order_by(AuditLog.timestamp.desc())
                .limit(limit)
                .all()
            )
        finally:
            if own_db:
                session.close()
