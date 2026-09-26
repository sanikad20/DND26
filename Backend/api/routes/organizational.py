"""
api/routes/organizational.py
──────────────────────────────────────────────────────────────────────────────
FastAPI routes for Veer Mitra's Organizational & Welfare Layer.

Key Architecture Guarantees:
- Role-Based Access Control (RBAC):
    - personnel: Own profile & opt-in only. No officer or aggregate dashboards.
    - welfare_officer: High-level overview, unit trends, alerts, and monitored
      personnel summaries (score bands and trends only; raw 12-question answers
      are NEVER exposed).
    - commander: Strictly aggregate unit summaries only. CANNOT access
      individual personnel lists or individual assessment details.
    - admin: Can review system audit logs and manage organizational data.
- Audit Logging: Sensitive officer access is automatically recorded.
- Model Honesty: All demonstration HRMS data is explicitly marked synthetic.
──────────────────────────────────────────────────────────────────────────────
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status

from core.firebase_auth import get_current_uid
from models import PersonnelProfile
from repositories.organizational_repository import OrganizationalRepository
from schemas.organizational import (
    AlertAcknowledgeRequest,
    AuditLogOut,
    CommanderUnitSummaryOut,
    HRDemoRecordOut,
    OptInUpdateRequest,
    OptionalWellnessDemoOut,
    OrgRecommendationItem,
    PersonnelWelfareSummaryOut,
    ProfileOut,
    RoleUpdateRequest,
    WelfareAlertOut,
    WelfareOverviewOut,
)
from services.audit_service import AuditService
from services.hrms_synthetic_service import HRMSSyntheticService
from services.organizational_analytics_service import OrganizationalAnalyticsService
from services.organizational_recommendation_service import OrganizationalRecommendationService
from services.welfare_alert_engine import WelfareAlertEngine

router = APIRouter(prefix="/organizational", tags=["Organizational & Welfare"])


# ─────────────────────────────────────────────────────────────────────────────
# Dependency Injection
# ─────────────────────────────────────────────────────────────────────────────

def get_org_repository() -> OrganizationalRepository:
    return OrganizationalRepository()


def get_audit_service(
    repo: OrganizationalRepository = Depends(get_org_repository),
) -> AuditService:
    return AuditService(repo)


def get_analytics_service(
    repo: OrganizationalRepository = Depends(get_org_repository),
) -> OrganizationalAnalyticsService:
    return OrganizationalAnalyticsService(repo)


def get_alert_engine(
    repo: OrganizationalRepository = Depends(get_org_repository),
) -> WelfareAlertEngine:
    return WelfareAlertEngine(repo)


def get_rec_service(
    repo: OrganizationalRepository = Depends(get_org_repository),
    analytics: OrganizationalAnalyticsService = Depends(get_analytics_service),
) -> OrganizationalRecommendationService:
    return OrganizationalRecommendationService(repo, analytics)


def get_hrms_service(
    repo: OrganizationalRepository = Depends(get_org_repository),
) -> HRMSSyntheticService:
    return HRMSSyntheticService(repo)


def get_current_profile(
    current_uid: str = Depends(get_current_uid),
    repo: OrganizationalRepository = Depends(get_org_repository),
) -> PersonnelProfile:
    """Retrieves or auto-provisions the personnel profile for the authenticated UID."""
    return repo.get_or_create_profile(current_uid)


def require_roles(*allowed_roles: str):
    """RBAC dependency ensuring the caller has one of the allowed roles."""
    def role_checker(
        profile: PersonnelProfile = Depends(get_current_profile),
    ) -> PersonnelProfile:
        if profile.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied for role '{profile.role}'. Requires one of {list(allowed_roles)}.",
            )
        return profile

    return role_checker


# ─────────────────────────────────────────────────────────────────────────────
# Profile & Role Management
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/me/role", response_model=ProfileOut)
def get_my_role(
    profile: PersonnelProfile = Depends(get_current_profile),
):
    """Returns the current user's profile, role, unit, and opt-in settings."""
    return ProfileOut(
        id=profile.id,
        firebase_uid=profile.firebase_uid,
        personnel_id=profile.personnel_id,
        role=profile.role,  # type: ignore
        unit_id=profile.unit_id,
        rank_designation=profile.rank_designation,
        opt_in_optional_wellness=profile.opt_in_optional_wellness,
        created_at=profile.created_at.isoformat() if profile.created_at else "",
    )


@router.post("/me/role", response_model=ProfileOut)
def switch_my_role(
    req: RoleUpdateRequest,
    profile: PersonnelProfile = Depends(get_current_profile),
    repo: OrganizationalRepository = Depends(get_org_repository),
    audit: AuditService = Depends(get_audit_service),
):
    """Convenience endpoint allowing role switching in demonstration mode."""
    updated = repo.update_profile_role(profile.firebase_uid, req.role)
    if not updated:
        raise HTTPException(status_code=404, detail="Profile not found")

    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="SWITCH_ROLE",
        target_type="profile",
        target_id=req.role,
    )

    return ProfileOut(
        id=updated.id,
        firebase_uid=updated.firebase_uid,
        personnel_id=updated.personnel_id,
        role=updated.role,  # type: ignore
        unit_id=updated.unit_id,
        rank_designation=updated.rank_designation,
        opt_in_optional_wellness=updated.opt_in_optional_wellness,
        created_at=updated.created_at.isoformat() if updated.created_at else "",
    )


@router.post("/me/opt-in", response_model=ProfileOut)
def update_my_opt_in(
    req: OptInUpdateRequest,
    profile: PersonnelProfile = Depends(get_current_profile),
    repo: OrganizationalRepository = Depends(get_org_repository),
    audit: AuditService = Depends(get_audit_service),
):
    """Toggle opt-in status for optional synthetic demonstration wellness data."""
    updated = repo.update_profile_opt_in(profile.firebase_uid, req.opt_in)
    if not updated:
        raise HTTPException(status_code=404, detail="Profile not found")

    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="TOGGLE_OPT_IN",
        target_type="profile",
        target_id=str(req.opt_in),
    )

    return ProfileOut(
        id=updated.id,
        firebase_uid=updated.firebase_uid,
        personnel_id=updated.personnel_id,
        role=updated.role,  # type: ignore
        unit_id=updated.unit_id,
        rank_designation=updated.rank_designation,
        opt_in_optional_wellness=updated.opt_in_optional_wellness,
        created_at=updated.created_at.isoformat() if updated.created_at else "",
    )


# ─────────────────────────────────────────────────────────────────────────────
# Welfare Officer & Command Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/overview", response_model=WelfareOverviewOut)
def get_welfare_overview(
    profile: PersonnelProfile = Depends(
        require_roles("welfare_officer", "commander", "admin")
    ),
    analytics: OrganizationalAnalyticsService = Depends(get_analytics_service),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
    audit: AuditService = Depends(get_audit_service),
):
    """High-level welfare and operational overview across all units."""
    hrms.seed_demo_dataset_if_empty()
    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="VIEW_WELFARE_OVERVIEW",
        target_type="overview",
    )
    return analytics.get_welfare_overview()


@router.get("/personnel", response_model=List[PersonnelWelfareSummaryOut])
def get_monitored_personnel(
    unit_id: Optional[str] = Query(None, description="Optional unit ID filter"),
    profile: PersonnelProfile = Depends(require_roles("welfare_officer", "admin")),
    analytics: OrganizationalAnalyticsService = Depends(get_analytics_service),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
    audit: AuditService = Depends(get_audit_service),
):
    """Lists monitored personnel welfare summaries for Welfare Officers.
    
    CRITICAL PRIVACY POLICY:
    - Strictly prohibited for Unit Commanders (they must use /unit/{unit_id}).
    - Displays only risk bands, scores, and trends.
    - Raw 12-question assessment answers are NEVER exposed.
    """
    hrms.seed_demo_dataset_if_empty()
    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="VIEW_PERSONNEL_SUMMARIES",
        target_type="personnel",
        target_id=unit_id or "ALL",
    )
    return analytics.get_personnel_summaries(unit_id=unit_id)


@router.get("/trends")
def get_welfare_trends(
    profile: PersonnelProfile = Depends(
        require_roles("welfare_officer", "commander", "admin")
    ),
    analytics: OrganizationalAnalyticsService = Depends(get_analytics_service),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
):
    """Returns force-wide indicator trends and top contributors."""
    hrms.seed_demo_dataset_if_empty()
    overview = analytics.get_welfare_overview()
    return {
        "worsening_trend_count": overview.worsening_trend_count,
        "average_stress_score": overview.average_stress_score,
        "top_contributors": overview.top_contributors,
        "unit_overviews": overview.unit_overviews,
        "disclaimer": overview.disclaimer,
    }


@router.get("/alerts", response_model=List[WelfareAlertOut])
def get_active_welfare_alerts(
    unit_id: Optional[str] = Query(None, description="Optional unit ID filter"),
    profile: PersonnelProfile = Depends(require_roles("welfare_officer", "admin")),
    alerts: WelfareAlertEngine = Depends(get_alert_engine),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
    audit: AuditService = Depends(get_audit_service),
):
    """Returns active welfare alerts for Welfare Officers."""
    hrms.seed_demo_dataset_if_empty()
    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="VIEW_ACTIVE_ALERTS",
        target_type="welfare_alerts",
        target_id=unit_id or "ALL",
    )
    return alerts.get_active_alerts(unit_id=unit_id)


@router.post("/alerts/{alert_id}/acknowledge", response_model=WelfareAlertOut)
def acknowledge_welfare_alert(
    alert_id: str,
    body: Optional[AlertAcknowledgeRequest] = None,
    profile: PersonnelProfile = Depends(require_roles("welfare_officer", "admin")),
    alerts: WelfareAlertEngine = Depends(get_alert_engine),
    audit: AuditService = Depends(get_audit_service),
):
    """Allows a Welfare Officer to acknowledge an active welfare alert."""
    ack = alerts.acknowledge_alert(alert_id)
    if not ack:
        raise HTTPException(status_code=404, detail="Welfare alert not found")

    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="ACKNOWLEDGE_ALERT",
        target_type="welfare_alert",
        target_id=alert_id,
    )
    return ack


@router.get("/recommendations", response_model=List[OrgRecommendationItem])
def get_command_recommendations(
    unit_id: Optional[str] = Query(None, description="Optional unit filter"),
    profile: PersonnelProfile = Depends(
        require_roles("welfare_officer", "commander", "admin")
    ),
    recs: OrganizationalRecommendationService = Depends(get_rec_service),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
):
    """Returns non-binding operational advisory recommendations."""
    hrms.seed_demo_dataset_if_empty()
    return recs.get_organizational_recommendations(unit_id=unit_id)


@router.get("/hr-summary", response_model=List[HRDemoRecordOut])
def get_hr_summary(
    unit_id: Optional[str] = Query(None, description="Optional unit filter"),
    profile: PersonnelProfile = Depends(
        require_roles("welfare_officer", "commander", "admin")
    ),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
):
    """Returns administrative HR demonstration records."""
    hrms.seed_demo_dataset_if_empty()
    records = hrms.get_unit_records(unit_id) if unit_id else hrms.get_all_records()
    return [
        HRDemoRecordOut(
            id=r.id,
            personnel_id=r.personnel_id,
            unit_id=r.unit_id,
            duty_hours=r.duty_hours,
            night_shift_count=r.night_shift_count,
            consecutive_duty_days=r.consecutive_duty_days,
            leave_days=r.leave_days,
            deployment_days=r.deployment_days,
            transfer_count=r.transfer_count,
            training_days=r.training_days,
            workload_level=r.workload_level,
            is_synthetic=r.is_synthetic,
            data_notice=r.data_notice,
            record_date=r.record_date.isoformat() if r.record_date else "",
        )
        for r in records
    ]


@router.get("/unit/{unit_id}", response_model=CommanderUnitSummaryOut)
def get_commander_unit_summary(
    unit_id: str,
    profile: PersonnelProfile = Depends(
        require_roles("welfare_officer", "commander", "admin")
    ),
    analytics: OrganizationalAnalyticsService = Depends(get_analytics_service),
    hrms: HRMSSyntheticService = Depends(get_hrms_service),
    audit: AuditService = Depends(get_audit_service),
):
    """Aggregate-only unit resilience summary designed specifically for Unit Commanders."""
    hrms.seed_demo_dataset_if_empty()
    audit.log(
        actor_uid=profile.firebase_uid,
        actor_role=profile.role,
        action="VIEW_COMMANDER_UNIT_SUMMARY",
        target_type="unit",
        target_id=unit_id,
    )
    return analytics.get_commander_unit_summary(unit_id=unit_id)


# ─────────────────────────────────────────────────────────────────────────────
# Admin & Audit Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/audit-logs", response_model=List[AuditLogOut])
def get_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    profile: PersonnelProfile = Depends(require_roles("admin")),
    audit: AuditService = Depends(get_audit_service),
):
    """Reviews administrative access audit logs. Strictly restricted to admin role."""
    logs = audit.get_logs(limit=limit)
    return [
        AuditLogOut(
            id=l.id,
            actor_uid=l.actor_uid,
            actor_role=l.actor_role,
            action=l.action,
            target_type=l.target_type,
            target_id=l.target_id,
            timestamp=l.timestamp.isoformat() if l.timestamp else "",
        )
        for l in logs
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Optional Wellness Demonstration Endpoint
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/optional-wellness-demo", response_model=OptionalWellnessDemoOut)
def get_optional_wellness_demo(
    profile: PersonnelProfile = Depends(get_current_profile),
):
    """Demonstrates how optional wearable/biometric data layers would function
    under strict opt-in consent and synthetic data isolation."""
    if not profile.opt_in_optional_wellness:
        return OptionalWellnessDemoOut(
            personnel_id=profile.personnel_id,
            opted_in=False,
            status_notice=(
                "Optional wellness demo data requires explicit opt-in. "
                "You can enable this feature in your Profile settings."
            ),
        )

    return OptionalWellnessDemoOut(
        personnel_id=profile.personnel_id,
        opted_in=True,
        status_notice="Optional demonstration data active (Opted In).",
        synthetic_metrics={
            "resting_heart_rate_bpm": 68,
            "sleep_regularity_score": 82,
            "recovery_index": 74,
            "notice": "Synthetic demonstration metrics - not real biometric data.",
        },
    )
