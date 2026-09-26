"""
test_organizational.py
──────────────────────────────────────────────────────────────────────────────
Tests for Veer Mitra's Organizational & Welfare Layer:
- Role-Based Access Control (RBAC):
    - Personnel restricted to personal data only.
    - Welfare Officer can view overview, alerts, and monitored personnel.
    - Commander restricted to AGGREGATE-ONLY views (blocked from individual lists).
    - Admin can view audit logs.
- Synthetic Demonstration Data isolation and disclaimers.
- Alert acknowledgement workflow.
- Audit logging hygiene (ensuring tokens and raw answers are never logged).
- Optional wellness demo opt-in enforcement.
──────────────────────────────────────────────────────────────────────────────
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import Base, engine
import models  # noqa: F401
from api.routes.organizational import router
from core.firebase_auth import get_current_uid
from services.hrms_synthetic_service import HRMSSyntheticService
from conftest import auth_header, fake_current_uid


@pytest.fixture(scope="module")
def org_client():
    Base.metadata.create_all(bind=engine)
    # Ensure synthetic dataset is seeded
    HRMSSyntheticService().seed_demo_dataset_if_empty()

    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_uid] = fake_current_uid
    return TestClient(app)


# ─────────────────────────────────────────────────────────────────────────────
# 1. Profile & Role Management Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_get_my_role_creates_default_profile(org_client):
    r = org_client.get("/organizational/me/role", headers=auth_header("personnel_auto_1"))
    assert r.status_code == 200
    data = r.json()
    assert data["role"] == "personnel"
    assert "PERS-" in data["personnel_id"]
    assert data["opt_in_optional_wellness"] is False


def test_role_switching_demo_endpoint(org_client):
    uid = "role_switch_user_1"
    # Initially personnel
    r1 = org_client.get("/organizational/me/role", headers=auth_header(uid))
    assert r1.status_code == 200
    assert r1.json()["role"] == "personnel"

    # Switch to welfare_officer
    r2 = org_client.post(
        "/organizational/me/role",
        json={"role": "welfare_officer"},
        headers=auth_header(uid),
    )
    assert r2.status_code == 200
    assert r2.json()["role"] == "welfare_officer"

    # Verify updated
    r3 = org_client.get("/organizational/me/role", headers=auth_header(uid))
    assert r3.json()["role"] == "welfare_officer"


def test_opt_in_toggle(org_client):
    uid = "opt_in_user_1"
    # Default is not opted in
    r1 = org_client.get("/organizational/optional-wellness-demo", headers=auth_header(uid))
    assert r1.status_code == 200
    assert r1.json()["opted_in"] is False
    assert "requires explicit opt-in" in r1.json()["status_notice"]

    # Toggle opt-in to True
    r2 = org_client.post(
        "/organizational/me/opt-in",
        json={"opt_in": True},
        headers=auth_header(uid),
    )
    assert r2.status_code == 200
    assert r2.json()["opt_in_optional_wellness"] is True

    # Now optional wellness demo returns synthetic metrics
    r3 = org_client.get("/organizational/optional-wellness-demo", headers=auth_header(uid))
    assert r3.status_code == 200
    assert r3.json()["opted_in"] is True
    assert "synthetic_metrics" in r3.json()
    assert "Synthetic" in r3.json()["data_notice"]


# ─────────────────────────────────────────────────────────────────────────────
# 2. RBAC Enforcement Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_personnel_cannot_access_welfare_overview(org_client):
    r = org_client.get("/organizational/overview", headers=auth_header("personnel_regular_1"))
    assert r.status_code == 403
    assert "Access denied" in r.json()["detail"]


def test_personnel_cannot_access_alerts(org_client):
    r = org_client.get("/organizational/alerts", headers=auth_header("personnel_regular_2"))
    assert r.status_code == 403


def test_personnel_cannot_access_personnel_list(org_client):
    r = org_client.get("/organizational/personnel", headers=auth_header("personnel_regular_3"))
    assert r.status_code == 403


def test_commander_CANNOT_access_individual_personnel_list(org_client):
    """CRITICAL PRIVACY TEST:
    Commanders must ONLY see aggregate unit data. Individual personnel
    summaries and assessments are strictly off-limits to prevent bias."""
    r = org_client.get("/organizational/personnel", headers=auth_header("commander_unit_alpha"))
    assert r.status_code == 403
    assert "Access denied" in r.json()["detail"]


def test_commander_CAN_access_unit_aggregates(org_client):
    r = org_client.get("/organizational/unit/UNIT-ALPHA", headers=auth_header("commander_unit_alpha"))
    assert r.status_code == 200
    data = r.json()
    assert data["unit_id"] == "UNIT-ALPHA"
    assert "risk_distribution" in data
    assert "Privacy Protected" in data["privacy_notice"]
    assert "Synthetic" in data["disclaimer"]
    assert len(data["recommendations"]) > 0


def test_welfare_officer_can_access_overview_alerts_and_personnel(org_client):
    welfare_headers = auth_header("welfare_officer_hq")

    # Overview
    r_overview = org_client.get("/organizational/overview", headers=welfare_headers)
    assert r_overview.status_code == 200
    overview = r_overview.json()
    assert overview["total_personnel_monitored"] == 100
    assert overview["active_alerts_count"] >= 1
    assert "Synthetic demonstration data" in overview["disclaimer"]
    assert len(overview["top_contributors"]) > 0
    assert len(overview["unit_overviews"]) > 0

    # Personnel list
    r_personnel = org_client.get("/organizational/personnel", headers=welfare_headers)
    assert r_personnel.status_code == 200
    personnel = r_personnel.json()
    assert len(personnel) == 100
    # Verify no raw answers exist in the response
    first_p = personnel[0]
    assert "raw_answers" not in first_p
    assert "risk_level" in first_p
    assert "score" in first_p
    assert "trend" in first_p

    # Alerts list
    r_alerts = org_client.get("/organizational/alerts", headers=welfare_headers)
    assert r_alerts.status_code == 200
    alerts = r_alerts.json()
    assert len(alerts) >= 1
    for a in alerts:
        assert a["status"] == "active"
        assert a["severity"] in ("low", "moderate", "high")


# ─────────────────────────────────────────────────────────────────────────────
# 3. Welfare Alert Acknowledgement Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_acknowledge_welfare_alert(org_client):
    welfare_headers = auth_header("welfare_officer_ops")
    # Get active alerts
    r_alerts = org_client.get("/organizational/alerts", headers=welfare_headers)
    assert r_alerts.status_code == 200
    alerts = r_alerts.json()
    assert len(alerts) > 0
    alert_to_ack = alerts[0]["alert_id"]

    # Acknowledge
    r_ack = org_client.post(
        f"/organizational/alerts/{alert_to_ack}/acknowledge",
        json={"notes": "Outreach completed by welfare officer."},
        headers=welfare_headers,
    )
    assert r_ack.status_code == 200
    data = r_ack.json()
    assert data["alert_id"] == alert_to_ack
    assert data["status"] == "acknowledged"


def test_acknowledge_nonexistent_alert_returns_404(org_client):
    welfare_headers = auth_header("welfare_officer_ops")
    r = org_client.post(
        "/organizational/alerts/ALT-NONEXISTENT/acknowledge",
        headers=welfare_headers,
    )
    assert r.status_code == 404


# ─────────────────────────────────────────────────────────────────────────────
# 4. Audit Logging & Non-Admin Restriction
# ─────────────────────────────────────────────────────────────────────────────

def test_non_admin_cannot_access_audit_logs(org_client):
    r_pers = org_client.get("/organizational/audit-logs", headers=auth_header("personnel_audit_1"))
    assert r_pers.status_code == 403

    r_welf = org_client.get("/organizational/audit-logs", headers=auth_header("welfare_officer_audit_2"))
    assert r_welf.status_code == 403

    r_comm = org_client.get("/organizational/audit-logs", headers=auth_header("commander_audit_3"))
    assert r_comm.status_code == 403


def test_admin_can_access_audit_logs_and_hygiene(org_client):
    admin_headers = auth_header("admin_master_1")
    r = org_client.get("/organizational/audit-logs", headers=admin_headers)
    assert r.status_code == 200
    logs = r.json()
    assert isinstance(logs, list)
    assert len(logs) > 0

    # Verify data hygiene in all logs: no tokens or raw answers
    for entry in logs:
        target = str(entry.get("target_id") or "")
        assert "Bearer" not in target
        assert "{" not in target
