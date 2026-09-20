from typing import List, Literal

from pydantic import BaseModel, ConfigDict, Field


class OccupationalAnswers(BaseModel):
    firebase_uid: str

    duty_hours_per_day: float = Field(..., ge=4, le=16)
    night_duties_last_2wks: float = Field(..., ge=0, le=14)
    consecutive_days_no_rest: float = Field(..., ge=0, le=30)
    days_since_last_leave: float = Field(..., ge=0, le=180)
    leave_days_taken_3mo: float = Field(..., ge=0, le=30)
    recovery_quality: int = Field(..., ge=1, le=5)
    family_time: int = Field(..., ge=1, le=5)

    demand: int = Field(..., ge=1, le=5)
    control: int = Field(..., ge=1, le=5)
    support: int = Field(..., ge=1, le=5)
    effort: int = Field(..., ge=1, le=5)
    reward: int = Field(..., ge=1, le=5)


class ContributorItem(BaseModel):
    label: str
    layer: Literal["MODEL", "CONTEXT"]


class DayPlanItem(BaseModel):
    day: int
    title: str
    detail: str


class AssessmentResult(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    risk_level: Literal["Low", "Moderate", "High"]
    score: int
    model_contributors: List[ContributorItem]
    context_contributors: List[ContributorItem]
    protective_factors: List[str]
    recommendations: List[str]
    plan: List[DayPlanItem]
    model_version: str
    placeholder_scoring: bool
    generated_at: str


class HistoryPoint(BaseModel):
    timestamp: str
    score: int
    risk_level: str


class HistoryResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    firebase_uid: str
    assessments: List[HistoryPoint]
    trend: Literal["Improving", "Stable", "Worsening", "Not enough data"]
    model_version: str
    placeholder_data: bool