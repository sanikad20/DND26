import logging
from types import SimpleNamespace
from unittest.mock import Mock

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from core import firebase_auth


def _auth_client():
    app = FastAPI()

    @app.get("/protected")
    def protected(current_user=Depends(firebase_auth.get_current_user)):
        return current_user

    return TestClient(app)


def test_missing_bearer_header_is_logged_without_attempting_verification(
    monkeypatch, caplog
):
    monkeypatch.setattr(firebase_auth.settings, "environment", "production")
    verify_id_token = Mock()
    monkeypatch.setattr(
        firebase_auth, "firebase_auth", SimpleNamespace(verify_id_token=verify_id_token)
    )
    client = _auth_client()

    with caplog.at_level(logging.INFO, logger="core.firebase_auth"):
        response = client.get("/protected")

    assert response.status_code == 401
    verify_id_token.assert_not_called()
    assert "authorization_header_received=False" in caplog.text
    assert "bearer_token_received=False" in caplog.text


def test_verification_failure_logs_sanitized_exception(monkeypatch, caplog):
    monkeypatch.setattr(firebase_auth.settings, "environment", "production")
    token = "sensitive-firebase-token"
    verify_id_token = Mock(side_effect=ValueError(f"invalid token: {token}"))
    monkeypatch.setattr(
        firebase_auth, "firebase_auth", SimpleNamespace(verify_id_token=verify_id_token)
    )
    monkeypatch.setattr(firebase_auth, "_initialize_firebase_admin", lambda: None)
    client = _auth_client()

    with caplog.at_level(logging.INFO, logger="core.firebase_auth"):
        response = client.get(
            "/protected", headers={"Authorization": f"Bearer {token}"}
        )

    assert response.status_code == 401
    verify_id_token.assert_called_once_with(token)
    assert "authorization_header_received=True" in caplog.text
    assert "bearer_token_received=True" in caplog.text
    assert "Firebase ID token verification failed (ValueError)" in caplog.text
    assert "invalid token: [REDACTED]" in caplog.text
    assert token not in caplog.text
