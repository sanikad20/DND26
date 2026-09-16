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
from pathlib import Path
from typing import List, Literal

import joblib
import numpy as np
from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/occupational", tags=["Occupational Stress"])

MODEL_VERSION = "lr-day2-v1"  # real trained model, replaces Day-1 placeholder

# ─────────────────────────────────────────────────────────────────────────────
# Day 2: load the trained Logistic Regression model + scaler + feature ranges.
# Trained in train_occupational_stress.py on the Dryad police-stress dataset
# (Garbarino & Magnavita, 2016), target = target_tertile (Low/Moderate/High).
# CV accuracy 93.95% (+/-1.6%), held-out test accuracy 87.93%, macro-F1 0.879 —
# outperformed Random Forest (82.7% CV / 77.6% test), so LR is the shipped model.
# ─────────────────────────────────────────────────────────────────────────────
_ARTIFACT_DIR = Path(__file__).parent
_MODEL = joblib.load(_ARTIFACT_DIR / "occupational_lr_model.pkl")
_SCALER = joblib.load(_ARTIFACT_DIR / "occupational_scaler.pkl")
_FEATURE_ANCHORS = joblib.load(_ARTIFACT_DIR / "occupational_feature_anchors.pkl")
_FEATURE_COLS = joblib.load(_ARTIFACT_DIR / "occupational_feature_cols.pkl")
# _FEATURE_COLS order: ['demandmedia','controlmedia','supportmedia','effortmedia','rewardmedia']
# _FEATURE_ANCHORS[feature] = (p5, p25, p50, p75, p95) of that feature in the
# real Dryad training data — used as 5 anchor points for Likert 1..5, so a
# "3" always lands on the population MEDIAN, not the middle of the raw
# min/max range (which is skewed for e.g. rewardmedia and silently pushed a
# neutral "all 3s" persona into a High reading during testing).

# Score buckets (0-100) matching target_tertile, used only to place the
# model's predicted probabilities on the same 0-100 scale the UI expects.
_BUCKET_MIDPOINT = {"Low": 17, "Moderate": 50, "High": 83}


def _likert_to_dcs_eri(value: int, feature: str) -> float:
    """Map a 1-5 Likert answer onto the Dryad dataset's DCS/ERI scale for
    that feature via piecewise-linear interpolation between 5 real
    percentile anchors (p5/p25/p50/p75/p95), so the model only ever sees
    values shaped like its real training distribution (Section 4.4)."""
    p5, p25, p50, p75, p95 = _FEATURE_ANCHORS[feature]
    anchor_x = [1, 2, 3, 4, 5]
    anchor_y = [p5, p25, p50, p75, p95]
    return float(np.interp(value, anchor_x, anchor_y))


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
# 3. Day 2: real trained-model scoring, wired into the same route contract
#    the Day-1 placeholder used (Section 6.1: model layer sets base score +
#    risk class, context layer only nudges by a capped, cited amount).
# ─────────────────────────────────────────────────────────────────────────────

def score_with_trained_model(a: OccupationalAnswers) -> AssessmentResult:
    # --- Model layer: the 5 [MODEL] Likert answers -> DCS/ERI scale ->
    #     trained Logistic Regression (93.95% CV accuracy) -> risk class
    #     + probability-weighted score.
    likert_by_feature = {
        "demandmedia": a.demand,
        "controlmedia": a.control,
        "supportmedia": a.support,
        "effortmedia": a.effort,
        "rewardmedia": a.reward,
    }
    x_raw = np.array([[_likert_to_dcs_eri(likert_by_feature[f], f) for f in _FEATURE_COLS]])
    x_scaled = _SCALER.transform(x_raw)

    predicted_class = _MODEL.predict(x_scaled)[0]  # risk LABEL always comes from the model (Section 6.1)
    proba = dict(zip(_MODEL.classes_, _MODEL.predict_proba(x_scaled)[0]))

    # Probability-weighted score keeps the 0-100 scale smooth/explainable
    # instead of a flat midpoint, while the risk_level below stays the
    # model's own argmax class — never re-derived from this score.
    base_score = sum(proba[cls] * _BUCKET_MIDPOINT[cls] for cls in proba)
    base_score = max(0.0, min(100.0, base_score))

    risk_level = predicted_class  # "Low" | "Moderate" | "High" — from the model, not recomputed

    # --- Context layer: capped +/-15 nudge (Section 6.1),
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

    nudged_score = base_score + nudge
    if risk_level == "Low":
        # Hard rule (Section 6.1): context layer can never flip a
        # confidently-Low model result into High — cap the display score
        # so it can visually read as Moderate-at-most, never High.
        nudged_score = min(nudged_score, 66.0)
    score = int(round(max(0.0, min(100.0, nudged_score))))

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
        placeholder_scoring=False,
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
    # NOTE: persistence + real /history trend computation is added Day 4
    # (Section 8: occupational_assessments table, keyed only by firebase_uid,
    # no name/email/rank). Scoring is now the real trained model (Day 2).
    return score_with_trained_model(answers)


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