import json
from datetime import datetime, timedelta, timezone
from statistics import mean

from database import SessionLocal
from core.config import settings
from models import OccupationalAssessment, WellnessPlan
from schemas.occupational import AssessmentResult, HistoryPoint, HistoryResponse, OccupationalAnswers

# Week-over-week trend (Section 6.4): "this week" is the last 7 days,
# "last week" is the 7 days before that. If someone assessed more than once
# in a window, the window's average score is used.
_WEEK = timedelta(days=7)

# Minimum movement between the two weeks to call it a real trend rather than
# noise. Score is 0-100 risk (higher = more risk), so a drop counts as
# Improving, a rise as Worsening.
_TREND_THRESHOLD = 5


class OccupationalRepository:
    def save_assessment(
        self,
        answers: OccupationalAnswers,
        result: AssessmentResult,
        firebase_uid: str,
    ) -> OccupationalAssessment:
        """Persists the assessment and returns the saved row (with its
        generated id) so the caller can create the matching wellness plan
        and report the id back to the client."""
        db = SessionLocal()
        try:
            row = OccupationalAssessment(
                firebase_uid=firebase_uid,
                risk_level=result.risk_level,
                score=result.score,
                model_version=result.model_version,
                raw_answers=json.dumps(answers.model_dump()),
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            return row
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

            # One query for all plans belonging to this uid, then match them
            # up in memory - avoids N+1 queries against wellness_plans.
            plan_rows = (
                db.query(WellnessPlan)
                .filter(WellnessPlan.firebase_uid == firebase_uid)
                .all()
            )
            plan_id_by_assessment = {p.assessment_id: p.id for p in plan_rows}
        finally:
            db.close()

        assessments = [
            HistoryPoint(
                id=row.id,
                timestamp=row.created_at.isoformat(),
                score=row.score,
                risk_level=row.risk_level,
                plan_id=plan_id_by_assessment.get(row.id),
            )
            for row in rows
        ]

        return HistoryResponse(
            firebase_uid=firebase_uid,
            assessments=assessments,
            trend=self._compute_trend(
                [(row.created_at, row.score) for row in rows]
            ),
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
    def _compute_trend(
        points: list[tuple[datetime, int]],
        now: datetime | None = None,
    ) -> str:
        """Improving / Stable / Worsening by comparing this week's average
        score with last week's. "Not enough data" until the person has at
        least one assessment in each of the two weeks."""
        now = now or datetime.utcnow()

        def as_naive_utc(ts: datetime) -> datetime:
            if ts.tzinfo is not None:
                return ts.astimezone(timezone.utc).replace(tzinfo=None)
            return ts

        this_week: list[int] = []
        last_week: list[int] = []
        for ts, score in points:
            age = now - as_naive_utc(ts)
            if age < _WEEK:
                this_week.append(score)
            elif age < 2 * _WEEK:
                last_week.append(score)

        if not this_week or not last_week:
            return "Not enough data"

        delta = mean(this_week) - mean(last_week)
        if delta <= -_TREND_THRESHOLD:
            return "Improving"
        if delta >= _TREND_THRESHOLD:
            return "Worsening"
        return "Stable"
