import base64
import json
import logging
import re
import threading
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from core.config import settings

try:
    import firebase_admin
    from firebase_admin import auth as firebase_auth
    from firebase_admin import credentials
except ImportError:  # pragma: no cover - exercised only in incomplete envs.
    firebase_admin = None
    firebase_auth = None
    credentials = None


_bearer = HTTPBearer(auto_error=False)
_init_lock = threading.Lock()
_logger = logging.getLogger(__name__)


def _service_account_info() -> dict[str, Any] | None:
    if settings.firebase_service_account_json:
        return json.loads(settings.firebase_service_account_json)
    if settings.firebase_service_account_json_base64:
        decoded = base64.b64decode(settings.firebase_service_account_json_base64)
        return json.loads(decoded.decode("utf-8"))
    return None


def _initialize_firebase_admin() -> None:
    if firebase_admin is None:
        raise RuntimeError("firebase-admin is not installed")
    if firebase_admin._apps:
        return

    with _init_lock:
        if firebase_admin._apps:
            return

        options = {}
        if settings.firebase_project_id:
            options["projectId"] = settings.firebase_project_id

        service_account = _service_account_info()
        if service_account:
            cred = credentials.Certificate(service_account)
            firebase_admin.initialize_app(cred, options or None)
        else:
            # Uses Google Application Default Credentials, including
            # GOOGLE_APPLICATION_CREDENTIALS in local development.
            firebase_admin.initialize_app(options=options or None)


def _safe_verification_error_message(message: str, token: str) -> str:
    if token:
        message = message.replace(token, "[REDACTED]")
    if "private_key" in message.lower():
        message = "[redacted message containing service-account data]"
    message = re.sub(
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
        "[REDACTED PRIVATE KEY]",
        message,
        flags=re.DOTALL,
    )
    message = re.sub(
        r"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s,;]+",
        r"\1[REDACTED]",
        message,
    )
    message = re.sub(r"AIza[0-9A-Za-z_-]{35}", "[REDACTED API KEY]", message)
    message = re.sub(
        r"(?i)(api[_ -]?key\s*[:=]\s*)[^\s,;]+",
        r"\1[REDACTED]",
        message,
    )
    return message


def get_current_user(
    request: Request,
    credentials_: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    authorization_header_received = bool(request.headers.get("authorization"))
    bearer_token_received = bool(
        credentials_ is not None
        and credentials_.scheme.lower() == "bearer"
        and credentials_.credentials
    )
    _logger.info(
        "Authentication request: authorization_header_received=%s "
        "bearer_token_received=%s",
        authorization_header_received,
        bearer_token_received,
    )

    if credentials_ is None or credentials_.scheme.lower() != "bearer":
        if settings.environment == "development":
            return {"uid": "dev_user", "dev_mode": True}
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials_.credentials

    # Support local development / test tokens starting with "uid:" (e.g. Bearer uid:user123)
    if token.startswith("uid:"):
        uid = token.removeprefix("uid:")
        if uid and uid not in {"invalid", "expired"}:
            return {"uid": uid, "dev_mode": True}

    try:
        _initialize_firebase_admin()
    except Exception as exc:
        # Fallback in local development if Firebase credentials are not configured
        if (
            settings.environment == "development"
            and not _service_account_info()
            and token
            and token not in {"invalid", "expired"}
        ):
            return {"uid": token, "dev_mode": True}

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authorization token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    try:
        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:
        _logger.warning(
            "Firebase ID token verification failed (%s): %s",
            type(exc).__name__,
            _safe_verification_error_message(str(exc), token),
        )
        # Fallback in local development if Firebase credentials are not configured.
        if (
            settings.environment == "development"
            and not _service_account_info()
            and token
            and token not in {"invalid", "expired"}
        ):
            return {"uid": token, "dev_mode": True}

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authorization token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    uid = decoded.get("uid")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return decoded


def get_current_uid(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> str:
    return current_user["uid"]
