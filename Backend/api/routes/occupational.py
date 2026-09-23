from fastapi import APIRouter, Depends, HTTPException

from core.firebase_auth import get_current_uid
from ml.model_loader import get_occupational_model
from repositories.occupational_repository import OccupationalRepository
from repositories.wellness_plan_repository import PlanNotFoundError, WellnessPlanRepository
from schemas.occupational import (
    AssessmentResult,
    HistoryResponse,
    OccupationalAnswers,
    DayProgress,
    PlanProgressResponse,
    PlanProgressUpdate,
    WellnessPlanOut,
)
from services.occupational_service import OccupationalService
from services.recommendation_service import RecommendationService

router = APIRouter(prefix="/occupational", tags=["Occupational Stress"])


def get_occupational_service() -> OccupationalService:
    return OccupationalService(
        model=get_occupational_model(),
        recommendations=RecommendationService(),
        repository=OccupationalRepository(),
        plan_repository=WellnessPlanRepository(),
    )


def get_plan_repository() -> WellnessPlanRepository:
    return WellnessPlanRepository()


@router.get("/questionnaire")
def get_questionnaire():
    return get_occupational_service().get_questionnaire()


@router.post("/assess", response_model=AssessmentResult)
def assess(
    answers: OccupationalAnswers,
    current_uid: str = Depends(get_current_uid),
):
    try:
        return get_occupational_service().assess(answers, firebase_uid=current_uid)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/history", response_model=HistoryResponse)
@router.get("/history/{firebase_uid}", response_model=HistoryResponse)
def get_history(
    firebase_uid: str | None = None,
    current_uid: str = Depends(get_current_uid),
):
    if firebase_uid is not None and firebase_uid != current_uid:
        raise HTTPException(status_code=403, detail="Forbidden")
    return get_occupational_service().get_history(current_uid)


def _get_owned_plan(
    plan_id: int,
    current_uid: str,
    repo: WellnessPlanRepository,
):
    plan = repo.get_plan(plan_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="Wellness plan not found")
    if plan.firebase_uid != current_uid:
        raise HTTPException(status_code=403, detail="Forbidden")
    return plan


@router.get("/plans/{plan_id}", response_model=WellnessPlanOut)
def get_plan(
    plan_id: int,
    current_uid: str = Depends(get_current_uid),
):
    repo = get_plan_repository()
    plan = _get_owned_plan(plan_id, current_uid, repo)
    return WellnessPlanOut(
        id=plan.id,
        assessment_id=plan.assessment_id,
        firebase_uid=plan.firebase_uid,
        created_at=plan.created_at.isoformat(),
    )


@router.get("/plans/{plan_id}/progress", response_model=PlanProgressResponse)
def get_plan_progress(
    plan_id: int,
    current_uid: str = Depends(get_current_uid),
):
    repo = get_plan_repository()
    _get_owned_plan(plan_id, current_uid, repo)

    rows = repo.get_progress(plan_id)
    return PlanProgressResponse(
        plan_id=plan_id,
        days=[
            DayProgress(
                day_number=row.day_number,
                completed=row.completed,
                completed_at=row.completed_at.isoformat() if row.completed_at else None,
            )
            for row in rows
        ],
    )


@router.post("/plans/{plan_id}/progress", response_model=DayProgress)
def update_plan_progress(
    plan_id: int,
    update: PlanProgressUpdate,
    current_uid: str = Depends(get_current_uid),
):
    repo = get_plan_repository()
    _get_owned_plan(plan_id, current_uid, repo)
    try:
        row = repo.set_day_completed(plan_id, update.day_number, update.completed)
    except PlanNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return DayProgress(
        day_number=row.day_number,
        completed=row.completed,
        completed_at=row.completed_at.isoformat() if row.completed_at else None,
    )
