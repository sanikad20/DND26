import json

from database import SessionLocal
from core.config import settings
from models import OccupationalAssessment
from schemas.occupational import AssessmentResult, HistoryPoint, HistoryResponse, OccupationalAnswers

# Trend needs at least this many points to say anything beyond "Not enough
# data" — a single point has nothing to compare against.
_MIN_POINTS_FOR_TREND = 2

# Minimum score movement between the two most recent points to call it a
# real trend rather than noise. Score is 0-100 risk (higher = more risk),
# so a drop counts as Improving, a rise as Worsening.
_TREND_THRESHOLD = 5


class OccupationalRepository:
    def save_assessment(
        self,
        answers: OccupationalAnswers,
        result: AssessmentResult,
    ) -> None:
        db = SessionLocal()
        try:
            row = OccupationalAssessment(
                firebase_uid=answers.firebase_uid,
                risk_level=result.risk_level,
                score=result.score,
                model_version=result.model_version,
                raw_answers=json.dumps(answers.model_dump(exclude={"firebase_uid"})),
            )
            db.add(row)
            db.commit()
        finally:
            db.close()

    def get_history(self, firebase_uid: str) -> HistoryResponse:
        db = SessionLocal()
        try:
            rows = (
                db.query(OccupationalAssessment)
                .filter(OccupationalAssessment.firebase_uid == firebase_uid)
                .order_by(OccupationalAssessment.created_at.asc())
                .all()
            )
        finally:
            db.close()

        assessments = [
            HistoryPoint(
                timestamp=row.created_at.isoformat(),
                score=row.score,
                risk_level=row.risk_level,
            )
            for row in rows
        ]

        return HistoryResponse(
            firebase_uid=firebase_uid,
            assessments=assessments,
            trend=self._compute_trend(assessments),
            model_version=settings.occupational_model_version,
            placeholder_data=False,
        )

    def get_latest(self, firebase_uid: str):
        db = SessionLocal()
        try:
            return (
                db.query(OccupationalAssessment)
                .filter(OccupationalAssessment.firebase_uid == firebase_uid)
                .order_by(OccupationalAssessment.created_at.desc())
                .first()
            )
        finally:
            db.close()

    @staticmethod
    def _compute_trend(assessments: list[HistoryPoint]) -> str:
        if len(assessments) < _MIN_POINTS_FOR_TREND:
            return "Not enough data"

        latest = assessments[-1].score
        previous = assessments[-2].score
        delta = latest - previous

        if delta <= -_TREND_THRESHOLD:
            return "Improving"
        if delta >= _TREND_THRESHOLD:
            return "Worsening"
        return "Stable"