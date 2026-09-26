from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

import torch
import torch.nn as nn
import pickle
import joblib
import numpy as np
from typing import List

import tensorflow as tf

from api.routes.occupational import router as occupational_router
from api.routes.organizational import router as organizational_router
from core.config import settings
from services.lstm_report import build_baseline_report
from database import Base, engine
import models  # noqa: F401 — registers User + OccupationalAssessment on Base
from services.hrms_synthetic_service import HRMSSyntheticService

app = FastAPI()

# Creates any tables that don't exist yet (users, occupational_assessments, organizational tables).
# Safe to call on every startup — no-ops for tables that already exist.
Base.metadata.create_all(bind=engine)

# Seed synthetic demonstration data on startup if empty
try:
    HRMSSyntheticService().seed_demo_dataset_if_empty()
except Exception as e:
    print(f"Demo seeding notice: {e}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────────────────────
# Schemas
# ─────────────────────────────────────────────────────────────────────────────

class BurnoutInput(BaseModel):
    sleep_hours: float
    sleep_quality: float
    app_switches_per_hour: float
    social_app_ratio: float
    productivity_ratio: float
    unique_apps_per_day: float
    call_count: float
    total_call_min: float
    missed_call_ratio: float
    sms_count: float
    sms_sent_ratio: float
    screen_time_hours: float
    exercise_min_per_week: float
    social_hours_per_week: float

class DayInput(BaseModel):
    screen_time_hours: float
    app_switches_per_hour: float
    unique_apps_per_day: float
    social_app_ratio: float
    work_app_ratio: float
    entertainment_ratio: float
    wellness_ratio: float
    sleep_hours: float
    sleep_quality: float
    exercise_min_per_week: float
    social_hours_per_week: float
    call_count: float
    missed_call_ratio: float
    sms_count: float

class PersonalisedPredictInput(BaseModel):
    history: List[DayInput]  # exactly 7 days, oldest first
    today: DayInput


# ─────────────────────────────────────────────────────────────────────────────
# Load Manual PyTorch model
# ─────────────────────────────────────────────────────────────────────────────

class BurnoutModel(nn.Module):
    def __init__(self, n_features):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_features, 64), nn.ReLU(), nn.Dropout(0.2),
            nn.Linear(64, 32),         nn.ReLU(), nn.Dropout(0.1),
            nn.Linear(32, 1)
        )
    def forward(self, x):
        return self.net(x).squeeze(-1)

with open(settings.manual_feature_cols_path, "rb") as f:
    manual_feature_cols = pickle.load(f)

manual_scaler = joblib.load(settings.burnout_scaler_path)
manual_model  = BurnoutModel(n_features=len(manual_feature_cols))
manual_model.load_state_dict(
    torch.load(settings.burnout_model_path, map_location="cpu", weights_only=True))
manual_model.eval()


# ─────────────────────────────────────────────────────────────────────────────
# Load Personalised LSTM
# ─────────────────────────────────────────────────────────────────────────────

_lstm_saved    = tf.saved_model.load(str(settings.lstm_saved_model_path))
_lstm_infer    = _lstm_saved.signatures["serving_default"]
_output_key    = list(_lstm_infer.structured_outputs.keys())[0]

day_scaler     = joblib.load(settings.lstm_day_scaler_path)
today_scaler   = joblib.load(settings.lstm_today_scaler_path)
DAY_FEATURES   = joblib.load(settings.lstm_day_features_path)
TODAY_FEATURES = joblib.load(settings.lstm_today_features_path)
SEQ_LEN        = joblib.load(settings.lstm_seq_len_path)

print(f"LSTM loaded [OK]  |  seq_len={SEQ_LEN}  |  output key: '{_output_key}'")


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def get_burnout_level_manual(score: float) -> str:
    if score < 4: return "Low 🟢"
    if score < 7: return "Moderate 🟠"
    return "High 🔴"

def get_burnout_level_lstm(score_01: float) -> str:
    if score_01 < 0.35: return "Low 🟢"
    if score_01 < 0.65: return "Moderate 🟠"
    return "High 🔴"

def compute_user_baseline(history: List[DayInput]) -> dict:
    def vals(attr): return [getattr(d, attr) for d in history]
    def safe_std(v): return max(float(np.std(v)), 1e-6)
    screens  = vals("screen_time_hours")
    switches = vals("app_switches_per_hour")
    socials  = vals("social_app_ratio")
    works    = vals("work_app_ratio")
    sleeps   = vals("sleep_hours")
    return {
        "mean_screen":   float(np.mean(screens)),
        "std_screen":    safe_std(screens),
        "p75_screen":    float(np.percentile(screens, 75)),
        "mean_switches": float(np.mean(switches)),
        "std_switches":  safe_std(switches),
        "p75_switches":  float(np.percentile(switches, 75)),
        "mean_social":   float(np.mean(socials)),
        "std_social":    safe_std(socials),
        "p75_social":    float(np.percentile(socials, 75)),
        "mean_work":     float(np.mean(works)),
        "mean_sleep":    float(np.mean(sleeps)),
        "std_sleep":     safe_std(sleeps),
    }

def weighted_app_burnout(d: DayInput) -> float:
    return float(np.clip(
        d.social_app_ratio    * 0.85
      + d.entertainment_ratio * 0.60
      - d.work_app_ratio      * 0.25
      - d.wellness_ratio      * 0.40,
      -1.0, 1.0))

def day_to_raw_features(d: DayInput) -> list:
    wab = weighted_app_burnout(d)
    return [
        d.screen_time_hours, d.app_switches_per_hour, d.unique_apps_per_day,
        d.social_app_ratio, d.work_app_ratio, d.entertainment_ratio,
        d.wellness_ratio, wab, d.sleep_hours, d.sleep_quality,
        d.exercise_min_per_week, d.social_hours_per_week,
        d.call_count, d.missed_call_ratio, d.sms_count,
    ]

def build_today_features(today: DayInput, baseline: dict) -> list:
    raw      = day_to_raw_features(today)
    d_screen = today.screen_time_hours     - baseline["mean_screen"]
    d_switch = today.app_switches_per_hour - baseline["mean_switches"]
    d_social = today.social_app_ratio      - baseline["mean_social"]
    d_work   = today.work_app_ratio        - baseline["mean_work"]
    d_sleep  = today.sleep_hours           - baseline["mean_sleep"]
    z_screen = d_screen / baseline["std_screen"]
    z_switch = d_switch / baseline["std_switches"]
    z_social = d_social / baseline["std_social"]
    ex_screen = 1.0 if today.screen_time_hours     > baseline["p75_screen"]   else 0.0
    ex_social = 1.0 if today.social_app_ratio      > baseline["p75_social"]   else 0.0
    ex_switch = 1.0 if today.app_switches_per_hour > baseline["p75_switches"] else 0.0
    trend_screen = d_screen / max(baseline["mean_screen"], 1e-6)
    trend_social = d_social / max(baseline["mean_social"], 1e-6)
    deviation = [
        d_screen, d_switch, d_social, d_work, d_sleep,
        z_screen, z_switch, z_social,
        ex_screen, ex_social, ex_switch,
        trend_screen, trend_social,
    ]
    return raw + deviation


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/")
def home():
    return {"message": "BrainLag backend running"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict")
def predict(data: BurnoutInput):
    row    = [float(data.dict()[c]) for c in manual_feature_cols]
    scaled = manual_scaler.transform(np.array([row], dtype=np.float32))
    tensor = torch.tensor(scaled, dtype=torch.float32)
    with torch.no_grad():
        raw = manual_model(tensor).item()
    score = float(np.clip(raw, 1, 10))
    return {
        "raw_prediction": round(raw, 4),
        "prediction":     round(score, 2),
        "stress_level":   get_burnout_level_manual(score),
    }

@app.post("/predict_lstm")
def predict_lstm(data: PersonalisedPredictInput):
    try:
        if len(data.history) != SEQ_LEN:
            raise HTTPException(
                400,
                f"history must have exactly {SEQ_LEN} days, got {len(data.history)}"
            )

        baseline     = compute_user_baseline(data.history)
        hist_rows    = np.array([day_to_raw_features(d) for d in data.history], dtype=np.float32)
        today_vec    = np.array(build_today_features(data.today, baseline), dtype=np.float32)
        hist_scaled  = day_scaler.transform(hist_rows)
        today_scaled = today_scaler.transform(today_vec.reshape(1, -1))

        hist_tensor  = tf.constant(
            hist_scaled.reshape(1, SEQ_LEN, len(DAY_FEATURES)), dtype=tf.float32)
        today_tensor = tf.constant(today_scaled, dtype=tf.float32)

        result  = _lstm_infer(history_input=hist_tensor, today_input=today_tensor)
        score01 = float(np.clip(float(result[_output_key].numpy()[0][0]), 0.0, 1.0))
        score10 = round(1 + score01 * 9, 1)

        user_baseline, today_vs_baseline = build_baseline_report(data.today, baseline)

        return {
            "prediction":  score10,
            "score_raw":   score01,
            "stress_level": get_burnout_level_lstm(score01),
            "user_baseline":     user_baseline,
            "today_vs_baseline": today_vs_baseline,
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))


# ─────────────────────────────────────────────────────────────────────────────
# Occupational Stress / Force Wellness (NEW, additive — Section 3 of plan)
# Everything above this line is unchanged from the existing Digital Burnout
# backend: /, /health, /predict, /predict_lstm all behave exactly as before.
# ─────────────────────────────────────────────────────────────────────────────

app.include_router(occupational_router)
app.include_router(organizational_router)
