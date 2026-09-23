"""Unit tests for the personal-baseline report (no torch/tensorflow needed)."""
from types import SimpleNamespace

import pytest

from services.lstm_report import Z_DISPLAY_LIMIT, build_baseline_report

BASELINE = dict(
    mean_screen=3.0, std_screen=0.5, mean_social=0.36, std_social=0.1,
    mean_work=0.03, mean_switches=55.0, mean_sleep=7.0,
)


def day(**kw):
    base = dict(screen_time_hours=3.0, social_app_ratio=0.36, work_app_ratio=0.03, sleep_hours=7.0)
    base.update(kw)
    return SimpleNamespace(**base)


def test_keys_match_what_flutter_reads():
    ub, tv = build_baseline_report(day(), BASELINE)
    assert {"avg_screen_time", "avg_social_ratio", "avg_work_ratio", "avg_app_switches"} <= set(ub)
    assert {
        "screen_zscore", "social_zscore", "screen_time_delta",
        "social_ratio_delta", "work_ratio_delta", "sleep_delta",
    } <= set(tv)


def test_deltas_and_zscores():
    _, tv = build_baseline_report(day(screen_time_hours=4.0, social_app_ratio=0.52), BASELINE)
    assert tv["screen_time_delta"] == pytest.approx(1.0)
    assert tv["screen_zscore"] == pytest.approx(2.0)
    assert tv["social_ratio_delta"] == pytest.approx(0.16)
    assert tv["social_zscore"] == pytest.approx(1.6)


def test_zscore_is_clipped_when_history_is_flat():
    flat = dict(BASELINE, std_screen=1e-6, std_social=1e-6)
    _, tv = build_baseline_report(day(screen_time_hours=9.0, social_app_ratio=0.9), flat)
    assert tv["screen_zscore"] == Z_DISPLAY_LIMIT
    assert tv["social_zscore"] == Z_DISPLAY_LIMIT
    _, tv = build_baseline_report(day(screen_time_hours=0.0), flat)
    assert tv["screen_zscore"] == -Z_DISPLAY_LIMIT
