"""Personal-baseline report returned alongside the LSTM prediction.

The Flutter monitoring screen reads `user_baseline` and `today_vs_baseline`
from /predict_lstm to draw the "vs your 7-day normal" rows and the σ alerts.
Kept free of torch/tensorflow so it can be unit-tested on its own.
"""

# The model input uses the raw z-score, but a user whose 7 history days are
# identical has ~0 std, which would otherwise show up as "1,000,000σ" in the UI.
Z_DISPLAY_LIMIT = 5.0


def _clip(value: float, limit: float) -> float:
    return max(-limit, min(limit, value))


def build_baseline_report(today, baseline: dict) -> tuple[dict, dict]:
    """Return (user_baseline, today_vs_baseline) as plain float dicts.

    `today` is a DayInput; `baseline` is the dict from compute_user_baseline().
    """
    screen_delta = today.screen_time_hours - baseline["mean_screen"]
    social_delta = today.social_app_ratio - baseline["mean_social"]
    work_delta = today.work_app_ratio - baseline["mean_work"]
    sleep_delta = today.sleep_hours - baseline["mean_sleep"]

    user_baseline = {
        "avg_screen_time": baseline["mean_screen"],
        "avg_social_ratio": baseline["mean_social"],
        "avg_work_ratio": baseline["mean_work"],
        "avg_app_switches": baseline["mean_switches"],
        "avg_sleep": baseline["mean_sleep"],
    }
    today_vs_baseline = {
        "screen_time_delta": screen_delta,
        "social_ratio_delta": social_delta,
        "work_ratio_delta": work_delta,
        "sleep_delta": sleep_delta,
        "screen_zscore": _clip(screen_delta / baseline["std_screen"], Z_DISPLAY_LIMIT),
        "social_zscore": _clip(social_delta / baseline["std_social"], Z_DISPLAY_LIMIT),
    }
    return (
        {k: round(float(v), 4) for k, v in user_baseline.items()},
        {k: round(float(v), 4) for k, v in today_vs_baseline.items()},
    )
