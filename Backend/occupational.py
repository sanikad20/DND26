"""
occupational.py
────────────────────────────────────────────────────────────────────────────
BrainLag — Occupational Stress / Force Wellness (NEW, additive feature)

Day 1 scope (per plan, Section 11):
  - Drop-in file, does not touch main.py's existing models/routes.
  - 3 routes, all returning valid JSON on dummy input:
        GET  /occupational/questionnaire
        POST /occupational/assess
        GET  /occupational/history/{firebase_uid}
  - Scoring here is a RULE-BASED PLACEHOLDER only. Day 2 replaces
    score_with_placeholder_rules() with the trained Logistic Regression /
    Random Forest model (Section 4.5) without changing the route contracts
    below, so the frontend built against this skeleton keeps working.
  - No database writes yet (persistence + /history trend logic is Day 4,
    Section 11). /assess and /history return well-formed placeholder JSON
    so frontend + Day-1 integration testing can proceed in parallel.

This module has ZERO imports from main.py and no torch/tensorflow
dependency, so it cannot change the behaviour of the existing
/predict or /predict_lstm routes (Digital Burnout, unchanged).
────────────────────────────────────────────────────────────────────────────
"""

from datetime import datetime, timedelta
from typing import List, Literal

from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/occupational", tags=["Occupational Stress"])

MODEL_VERSION = "placeholder-day1"  # bumped to a real model tag on Day 2


# ─────────────────────────────────────────────────────────────────────────────
# 1. The 12-question schema (Section 5 of the plan)
#    Server-driven: wording/ranges can change without an app release.
# ─────────────────────────────────────────────────────────────────────────────

QUESTIONNAIRE = [
    {"id": 1,  "text": "How many hours are you actively on duty per day?",
     "input_type": "slider", "min": 4, "max": 16, "maps_to": "Operational load", "layer": "CONTEXT"},
    {"id": 2,  "text": "Night duties/shifts in the last 2 weeks?",
     "input_type": "slider", "min": 0, "max": 14, "maps_to": "Circadian/recovery load", "layer": "CONTEXT"},
    {"id": 3,  "text": "Consecutive days without a full rest day?",
     "input_type": "slider", "min": 0, "max": 30, "maps_to": "Recovery deficit", "layer": "CONTEXT"},
    {"id": 4,  "text": "Days since your last leave/off day?",
     "input_type": "slider", "min": 0, "max": 180, "maps_to": "Recovery/family access", "layer": "CONTEXT"},
    {"id": 5,  "text": "Leave days actually taken in the last 3 months?",
     "input_type": "number", "min": 0, "max": 30, "maps_to": "Recovery access", "layer": "CONTEXT"},
    {"id": 6,  "text": "How demanding is your current workload?",
     "input_type": "likert_5", "maps_to": "Demand (DCS)", "layer": "MODEL"},
    {"id": 7,  "text": "How much control/say over how & when you work?",
     "input_type": "likert_5", "maps_to": "Control (DCS)", "layer": "MODEL"},
    {"id": 8,  "text": "How supported do you feel by supervisors/organisation?",
     "input_type": "likert_5", "maps_to": "Support (DCS)", "layer": "MODEL"},
    {"id": 9,  "text": "Effort required relative to what's expected?",
     "input_type": "likert_5", "maps_to": "Effort (ERI)", "layer": "MODEL"},
    {"id": 10, "text": "How adequately recognised/rewarded for that effort?",
     "input_type": "likert_5", "maps_to": "Reward (ERI)", "layer": "MODEL"},
    {"id": 11, "text": "Sleep/recovery quality this week?",
     "input_type": "likert_5", "maps_to": "Recovery quality", "layer": "CONTEXT"},
    {"id": 12, "text": "Quality time with family/loved ones (2 weeks)?",
     "input_type": "likert_5", "maps_to": "Family separation", "layer": "CONTEXT"},
]


# ─────────────────────────────────────────────────────────────────────────────
# 2. Schemas
# ─────────────────────────────────────────────────────────────────────────────

class OccupationalAnswers(BaseModel):
    firebase_uid: str

    # [CONTEXT] items
    duty_hours_per_day: float = Field(..., ge=4, le=16)
    night_duties_last_2wks: float = Field(..., ge=0, le=14)
    consecutive_days_no_rest: float = Field(..., ge=0, le=30)
    days_since_last_leave: float = Field(..., ge=0, le=180)
    leave_days_taken_3mo: float = Field(..., ge=0, le=30)
    recovery_quality: int = Field(..., ge=1, le=5)
    family_time: int = Field(..., ge=1, le=5)

    # [MODEL] items
    demand: int = Field(..., ge=1, le=5)
    control: int = Field(..., ge=1, le=5)
    support: int = Field(..., ge=1, le=5)
    effort: int = Field(..., ge=1, le=5)
    reward: int = Field(..., ge=1, le=5)


class ContributorItem(BaseModel):
    label: str
    layer: Literal["MODEL", "CONTEXT"]


class AssessmentResult(BaseModel):
    risk_level: Literal["Low", "Moderate", "High"]
    score: int
    model_contributors: List[ContributorItem]
    context_contributors: List[ContributorItem]
    protective_factors: List[str]
    model_version: str
    placeholder_scoring: bool
    generated_at: str


class HistoryPoint(BaseModel):
    timestamp: str
    score: int
    risk_level: str


class HistoryResponse(BaseModel):
    firebase_uid: str
    assessments: List[HistoryPoint]
    trend: Literal["Improving", "Stable", "Worsening", "Not enough data"]
    model_version: str
    placeholder_data: bool


# ─────────────────────────────────────────────────────────────────────────────
# 3. Rule-based PLACEHOLDER scoring (Day 1 only — replaced by trained
#    classifier on Day 2; route contract stays identical so nothing
#    downstream has to change).
# ─────────────────────────────────────────────────────────────────────────────

def score_with_placeholder_rules(a: OccupationalAnswers) -> AssessmentResult:
    # --- Model-layer placeholder: simple weighted average of the 5
    #     DCS/ERI Likert answers, standing in for the Day-2 trained model.
    #     High demand/effort push the score up; high control/support/reward
    #     pull it down — same directionality the real model is expected to learn.
    model_raw = (
        a.demand * 1.0
        + a.effort * 1.0
        - a.control * 1.0
        - a.support * 1.0
        - a.reward * 1.0
    )
    # model_raw ranges roughly [-15, 15] -> rescale to 0-100
    base_score = ((model_raw + 15) / 30) * 100
    base_score = max(0.0, min(100.0, base_score))

    # --- Context-layer placeholder: capped +/-15 nudge (Section 6.1),
    #     never allowed to flip a confidently-Low result into High.
    nudge = 0.0
    if a.duty_hours_per_day >= 12:
        nudge += 3
    if a.night_duties_last_2wks >= 6:
        nudge += 3
    if a.consecutive_days_no_rest >= 10:
        nudge += 3
    if a.days_since_last_leave >= 60:
        nudge += 2
    if a.recovery_quality <= 2:
        nudge += 2
    if a.family_time <= 2:
        nudge += 2
    nudge = max(-15.0, min(15.0, nudge))

    score = int(round(max(0.0, min(100.0, base_score + nudge))))

    if score < 34:
        risk_level = "Low"
    elif score < 67:
        risk_level = "Moderate"
    else:
        risk_level = "High"

    model_contributors = []
    if a.demand >= 4:
        model_contributors.append(ContributorItem(label="High workload", layer="MODEL"))
    if a.control <= 2:
        model_contributors.append(ContributorItem(label="Low control over work", layer="MODEL"))
    if a.support <= 2:
        model_contributors.append(ContributorItem(label="Low supervisor/org support", layer="MODEL"))
    if a.effort >= 4 and a.reward <= 2:
        model_contributors.append(ContributorItem(label="Effort-reward imbalance", layer="MODEL"))

    context_contributors = []
    if a.duty_hours_per_day >= 12:
        context_contributors.append(ContributorItem(label="Long duty hours", layer="CONTEXT"))
    if a.consecutive_days_no_rest >= 10:
        context_contributors.append(ContributorItem(label="Insufficient recovery", layer="CONTEXT"))
    if a.night_duties_last_2wks >= 6:
        context_contributors.append(ContributorItem(label="Heavy night-shift load", layer="CONTEXT"))

    protective_factors = []
    if a.leave_days_taken_3mo >= 5:
        protective_factors.append("Recent leave taken")
    if a.family_time >= 4:
        protective_factors.append("Good family/social connection")
    if a.support >= 4:
        protective_factors.append("Strong supervisor/org support")

    return AssessmentResult(
        risk_level=risk_level,
        score=score,
        model_contributors=model_contributors,
        context_contributors=context_contributors,
        protective_factors=protective_factors,
        model_version=MODEL_VERSION,
        placeholder_scoring=True,
        generated_at=datetime.utcnow().isoformat(),
    )


# ─────────────────────────────────────────────────────────────────────────────
# 4. Routes
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/questionnaire")
def get_questionnaire():
    return {"questions": QUESTIONNAIRE, "count": len(QUESTIONNAIRE)}


@router.post("/assess", response_model=AssessmentResult)
def assess(answers: OccupationalAnswers):
    # NOTE: Day 1 does not persist this record — persistence + real /history
    # trend computation is added Day 4 (Section 8: occupational_assessments
    # table, keyed only by firebase_uid, no name/email/rank).
    return score_with_placeholder_rules(answers)


@router.get("/history/{firebase_uid}", response_model=HistoryResponse)
def get_history(firebase_uid: str):
    # Day 1 placeholder: no DB table yet, so return a well-formed dummy
    # trend so frontend dashboard work isn't blocked. Day 4 swaps this
    # for a real query against occupational_assessments.
    now = datetime.utcnow()
    dummy_points = [
        HistoryPoint(
            timestamp=(now - timedelta(days=7)).isoformat(),
            score=55,
            risk_level="Moderate",
        ),
        HistoryPoint(
            timestamp=now.isoformat(),
            score=48,
            risk_level="Moderate",
        ),
    ]
    return HistoryResponse(
        firebase_uid=firebase_uid,
        assessments=dummy_points,
        trend="Improving",
        model_version=MODEL_VERSION,
        placeholder_data=True,
    )
