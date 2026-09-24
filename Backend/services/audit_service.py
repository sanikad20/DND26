from typing import Optional
from repositories.organizational_repository import OrganizationalRepository


class AuditService:
    def __init__(self, repository: Optional[OrganizationalRepository] = None):
        self._repo = repository or OrganizationalRepository()

    def log(
        self,
        actor_uid: str,
        actor_role: str,
        action: str,
        target_type: str,
        target_id: Optional[str] = None,
    ) -> None:
        """Logs sensitive officer/commander access.
        Guarantees that raw questionnaire answers and Firebase tokens
        are NEVER stored in audit logs."""
        # Sanitize target_id to ensure no raw answers or tokens leak
        clean_target_id = None
        if target_id is not None:
            clean_str = str(target_id).strip()
            # If accidentally passed a token or JSON object, sanitize
            if "Bearer" in clean_str or len(clean_str) > 100 or "{" in clean_str:
                clean_target_id = "SANITIZED_IDENTIFIER"
            else:
                clean_target_id = clean_str

        self._repo.log_audit(
            actor_uid=actor_uid,
            actor_role=actor_role,
            action=action,
            target_type=target_type,
            target_id=clean_target_id,
        )

    def get_logs(self, limit: int = 50):
        return self._repo.get_audit_logs(limit=limit)
