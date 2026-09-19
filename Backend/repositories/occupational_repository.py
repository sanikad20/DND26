from core.config import settings
from schemas.occupational import HistoryResponse


class OccupationalRepository:
    def save_assessment(self, *_args, **_kwargs) -> None:
        return None

    def get_history(self, firebase_uid: str) -> HistoryResponse:
        return HistoryResponse(
            firebase_uid=firebase_uid,
            assessments=[],
            trend="Not enough data",
            model_version=settings.occupational_model_version,
            placeholder_data=True,
        )

    def get_latest(self, _firebase_uid: str):
        return None
