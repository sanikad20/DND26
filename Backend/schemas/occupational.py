from typing import List, Literal

from pydantic import BaseModel, ConfigDict, Field


class OccupationalAnswers(BaseModel):
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
    # Concrete actions for the day. Optional so older clients that only read
    # day/title/detail keep working.
    tasks: List[str] = Field(default_factory=list)


class RecommendationItem(BaseModel):
    """A recommendation tied to the contributor that triggered it, so the
    app can show a title without guessing from list position."""

    label: str
    text: str


class AssessmentResult(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    # DB id of the saved occupational_assessments row. Lets the client tie
    # this result (and its plan) to a specific assessment instead of only
    # ever knowing "the latest one".
    id: int
    risk_level: Literal["Low", "Moderate", "High"]
    score: int
    model_contributors: List[ContributorItem]
    context_contributors: List[ContributorItem]
    protective_factors: List[str]
    recommendations: List[str]
    recommendation_items: List[RecommendationItem] = Field(default_factory=list)
    plan: List[DayPlanItem]
    # id of the wellness_plans row created alongside this assessment. Every
    # progress call (GET/POST .../plans/{plan_id}/progress) is keyed off this.
    plan_id: int
    model_version: str
    placeholder_scoring: bool
    generated_at: str


class HistoryPoint(BaseModel):
    id: int
    timestamp: str
    score: int
    risk_level: str
    plan_id: int | None = None


class HistoryResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    firebase_uid: str
    assessments: List[HistoryPoint]
    trend: Literal["Improving", "Stable", "Worsening", "Not enough data"]
    model_version: str
    placeholder_data: bool


class WellnessPlanOut(BaseModel):
    id: int
    assessment_id: int
    firebase_uid: str
    created_at: str


class DayProgress(BaseModel):
    day_number: int = Field(..., ge=1, le=7)
    completed: bool
    completed_at: str | None = None


class PlanProgressResponse(BaseModel):
    plan_id: int
    days: List[DayProgress]


class PlanProgressUpdate(BaseModel):
    day_number: int = Field(..., ge=1, le=7)
    completed: bool
