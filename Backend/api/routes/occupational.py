from fastapi import APIRouter, HTTPException

from ml.model_loader import get_occupational_model
from repositories.occupational_repository import OccupationalRepository
from schemas.occupational import (
    AssessmentResult,
    HistoryResponse,
    OccupationalAnswers,
)
from services.occupational_service import OccupationalService
from services.recommendation_service import RecommendationService

router = APIRouter(prefix="/occupational", tags=["Occupational Stress"])


def get_occupational_service() -> OccupationalService:
    return OccupationalService(
        model=get_occupational_model(),
        recommendations=RecommendationService(),
        repository=OccupationalRepository(),
    )


@router.get("/questionnaire")
def get_questionnaire():
    return get_occupational_service().get_questionnaire()


@router.post("/assess", response_model=AssessmentResult)
def assess(answers: OccupationalAnswers):
    try:
        return get_occupational_service().assess(answers)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/history/{firebase_uid}", response_model=HistoryResponse)
def get_history(firebase_uid: str):
    return get_occupational_service().get_history(firebase_uid)
