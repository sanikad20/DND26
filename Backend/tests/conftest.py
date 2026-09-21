"""Shared test setup.

DATABASE_URL must be set BEFORE any backend module is imported (database.py
reads it at import time), so tests never touch the real users.db.
"""
import os
import tempfile
from pathlib import Path

_TMP_DIR = tempfile.mkdtemp(prefix="brainlag_tests_")
os.environ["DATABASE_URL"] = "sqlite:///" + (Path(_TMP_DIR) / "test.db").as_posix()

import pytest  # noqa: E402
from fastapi import FastAPI, Header, HTTPException  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def make_answers(**overrides) -> dict:
    """A neutral 'all 3s' respondent; override any field per test."""
    base = dict(
        duty_hours_per_day=8,
        night_duties_last_2wks=2,
        consecutive_days_no_rest=3,
        days_since_last_leave=20,
        leave_days_taken_3mo=5,
        recovery_quality=3,
        family_time=3,
        demand=3,
        control=3,
        support=3,
        effort=3,
        reward=3,
    )
    base.update(overrides)
    return base


def auth_header(uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer uid:{uid}"}


def fake_current_uid(authorization: str | None = Header(default=None)) -> str:
    if authorization is None:
        raise HTTPException(status_code=401, detail="Missing authorization token")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.startswith("uid:"):
        raise HTTPException(status_code=401, detail="Invalid or expired authorization token")
    uid = token.removeprefix("uid:")
    if not uid or uid in {"invalid", "expired"}:
        raise HTTPException(status_code=401, detail="Invalid or expired authorization token")
    return uid


# Three personas for the Day 3 "contributor direction" check.
STRESSED = dict(
    duty_hours_per_day=14,
    night_duties_last_2wks=8,
    consecutive_days_no_rest=14,
    days_since_last_leave=90,
    leave_days_taken_3mo=0,
    recovery_quality=1,
    family_time=1,
    demand=5,
    control=1,
    support=1,
    effort=5,
    reward=1,
)
RELAXED = dict(
    duty_hours_per_day=7,
    night_duties_last_2wks=0,
    consecutive_days_no_rest=0,
    days_since_last_leave=5,
    leave_days_taken_3mo=12,
    recovery_quality=5,
    family_time=5,
    demand=1,
    control=5,
    support=5,
    effort=1,
    reward=5,
)
# Neutral work-experience answers, but a punishing duty pattern.
DUTY_STRAIN_ONLY = dict(
    duty_hours_per_day=14,
    night_duties_last_2wks=9,
    consecutive_days_no_rest=20,
    days_since_last_leave=120,
    leave_days_taken_3mo=0,
    recovery_quality=1,
    family_time=1,
)


@pytest.fixture(scope="session")
def occ_client():
    """Occupational routes only — no torch/tensorflow needed, so this is fast."""
    from database import Base, engine
    import models  # noqa: F401
    from api.routes.occupational import router
    from core.firebase_auth import get_current_uid

    Base.metadata.create_all(bind=engine)
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_uid] = fake_current_uid
    return TestClient(app)


@pytest.fixture(scope="session")
def main_client():
    """The full app, exactly as uvicorn runs it (needs torch + tensorflow)."""
    # Skip ONLY when the ML libraries themselves can't load on this machine.
    # Any error inside main.py after that is a real failure, not a skip.
    for lib in ("torch", "tensorflow"):
        try:
            __import__(lib)
        except Exception as exc:
            pytest.skip(f"{lib} is not usable here: {exc!r}")
    import main

    return TestClient(main.app)
