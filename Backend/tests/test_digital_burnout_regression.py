"""Regression guard: the original Digital Burnout endpoints must behave
exactly as before the Occupational Stress work was added (plan, Day 4)."""
import pytest

MANUAL = dict(
    sleep_hours=6,
    sleep_quality=3,
    app_switches_per_hour=20,
    social_app_ratio=0.4,
    productivity_ratio=0.6,
    unique_apps_per_day=12,
    call_count=5,
    total_call_min=30,
    missed_call_ratio=0.1,
    sms_count=20,
    sms_sent_ratio=0.5,
    screen_time_hours=6,
    exercise_min_per_week=120,
    social_hours_per_week=10,
)

DAY = dict(
    screen_time_hours=6,
    app_switches_per_hour=18,
    unique_apps_per_day=22,
    social_app_ratio=0.35,
    work_app_ratio=0.2,
    entertainment_ratio=0.25,
    wellness_ratio=0.05,
    sleep_hours=6.5,
    sleep_quality=3,
    exercise_min_per_week=90,
    social_hours_per_week=5,
    call_count=3,
    missed_call_ratio=0.1,
    sms_count=8,
)

LEVELS = ("Low", "Moderate", "High")


def test_original_routes_still_exist(main_client):
    # openapi.json lists every registered path regardless of FastAPI version.
    paths = set(main_client.get("/openapi.json").json()["paths"])
    assert {"/", "/health", "/predict", "/predict_lstm"} <= paths
    assert {"/occupational/questionnaire", "/occupational/assess"} <= paths


def test_root_and_health(main_client):
    assert main_client.get("/").json() == {"message": "BrainLag backend running"}
    assert main_client.get("/health").json() == {"status": "ok"}


def test_predict_manual(main_client):
    r = main_client.post("/predict", json=MANUAL)
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) == {"raw_prediction", "prediction", "stress_level"}
    assert 1 <= body["prediction"] <= 10
    assert any(level in body["stress_level"] for level in LEVELS)


def test_predict_manual_rejects_missing_fields(main_client):
    bad = {k: v for k, v in MANUAL.items() if k != "sleep_hours"}
    assert main_client.post("/predict", json=bad).status_code == 422


def test_predict_lstm(main_client):
    import main

    r = main_client.post("/predict_lstm", json={"history": [DAY] * main.SEQ_LEN, "today": DAY})
    assert r.status_code == 200, r.text
    body = r.json()
    # The original three fields are unchanged; the baseline blocks are additive
    # and are what the Flutter monitoring screen reads.
    assert {"prediction", "score_raw", "stress_level"} <= set(body)
    assert 1 <= body["prediction"] <= 10
    assert 0 <= body["score_raw"] <= 1
    assert any(level in body["stress_level"] for level in LEVELS)
    assert {"avg_screen_time", "avg_social_ratio", "avg_work_ratio", "avg_app_switches"} <= set(
        body["user_baseline"]
    )
    assert {
        "screen_zscore", "social_zscore", "screen_time_delta",
        "social_ratio_delta", "work_ratio_delta", "sleep_delta",
    } <= set(body["today_vs_baseline"])


def test_predict_lstm_requires_exact_history_length(main_client):
    r = main_client.post("/predict_lstm", json={"history": [DAY] * 3, "today": DAY})
    assert r.status_code == 400
