from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, ConfigDict, Field


RoleType = Literal["personnel", "welfare_officer", "commander", "admin"]


class ProfileOut(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    id: int
    firebase_uid: str
    personnel_id: str
    role: RoleType
    unit_id: str
    rank_designation: Optional[str] = None
    opt_in_optional_wellness: bool = False
    created_at: str


class RoleUpdateRequest(BaseModel):
    role: RoleType


class OptInUpdateRequest(BaseModel):
    opt_in: bool


class HRDemoRecordOut(BaseModel):
    id: int
    personnel_id: str
    unit_id: str
    duty_hours: float
    night_shift_count: int
    consecutive_duty_days: int
    leave_days: int
    deployment_days: int
    transfer_count: int
    training_days: int
    workload_level: str
    is_synthetic: bool = True
    data_notice: str = "Synthetic demonstration data"
    record_date: str


class WelfareAlertOut(BaseModel):
    id: int
    alert_id: str
    personnel_id: str
    unit_id: str
    alert_type: str
    severity: Literal["low", "moderate", "high"]
    title: str
    message: str
    status: Literal["active", "acknowledged", "resolved"]
    created_at: str


class AlertAcknowledgeRequest(BaseModel):
    notes: Optional[str] = None


class OrgIndicatorsOut(BaseModel):
    workload_pressure: Literal["Normal", "Elevated", "High"]
    recovery_deficit: Literal["Low", "Moderate", "Needs Attention"]
    night_duty_load: Literal["Normal", "Elevated", "High"]
    deployment_burden: Literal["Standard", "Moderate", "Extended"]
    training_load: Literal["Balanced", "Optimal", "Demanding"]
    notes: str = "Organizational indicator derived from administrative workload patterns."


class UnitOverviewItem(BaseModel):
    unit_id: str
    personnel_count: int
    average_stress: int
    low_risk_count: int
    moderate_risk_count: int
    high_risk_count: int
    high_risk_pct: float
    worsening_trend_count: int
    active_alerts_count: int
    workload_pressure: str
    night_duty_load: str
    recovery_status: str


class TopContributorItem(BaseModel):
    label: str
    affected_count: int
    percentage: float


class WelfareOverviewOut(BaseModel):
    total_personnel_monitored: int
    low_risk_count: int
    low_risk_pct: float
    moderate_risk_count: int
    moderate_risk_pct: float
    high_risk_count: int
    high_risk_pct: float
    worsening_trend_count: int
    active_alerts_count: int
    average_stress_score: int
    top_contributors: List[TopContributorItem]
    unit_overviews: List[UnitOverviewItem]
    disclaimer: str = "Synthetic demonstration data - Not real CRPF/CAPF personnel data"


class PersonnelWelfareSummaryOut(BaseModel):
    personnel_id: str
    unit_id: str
    risk_level: Literal["Low", "Moderate", "High"]
    score: int
    trend: Literal["Improving", "Stable", "Worsening", "Not enough data"]
    active_alerts_count: int
    workload_level: str
    duty_hours: float
    consecutive_duty_days: int
    last_assessed: Optional[str] = None
    opt_in_optional_wellness: bool = False


class CommanderUnitSummaryOut(BaseModel):
    unit_id: str
    average_stress: int
    high_risk_pct: float
    risk_distribution: Dict[str, int]
    workload_pressure: str
    night_duty_load: str
    recovery_status: str
    deployment_load: str
    training_load: str
    recommendations: List[str]
    privacy_notice: str = (
        "Privacy Protected: Aggregate metrics only. Individual questionnaire "
        "responses are strictly confidential."
    )
    disclaimer: str = "Synthetic demonstration data"


class OrgRecommendationItem(BaseModel):
    category: str
    trigger: str
    recommendation: str
    scope: str = "Unit Command / Welfare Officer"
    is_advisory_only: bool = True


class AuditLogOut(BaseModel):
    id: int
    actor_uid: str
    actor_role: str
    action: str
    target_type: str
    target_id: Optional[str] = None
    timestamp: str


class OptionalWellnessDemoOut(BaseModel):
    personnel_id: str
    opted_in: bool
    status_notice: str
    data_notice: str = "Synthetic demonstration data - Not real biometric collection"
    synthetic_metrics: Optional[Dict[str, Any]] = None
