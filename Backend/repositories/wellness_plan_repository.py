from datetime import datetime, timezone

from database import SessionLocal
from models import PlanProgress, WellnessPlan


class PlanNotFoundError(Exception):
    pass


class WellnessPlanRepository:
    def create_plan(self, assessment_id: int, firebase_uid: str) -> WellnessPlan:
        """One plan per assessment. Called right after an assessment is
        saved, so every assessment - not just the latest - ends up with its
        own plan and its own independent progress."""
        db = SessionLocal()
        try:
            row = WellnessPlan(assessment_id=assessment_id, firebase_uid=firebase_uid)
            db.add(row)
            db.commit()
            db.refresh(row)
            return row
        finally:
            db.close()

    def get_plan(self, plan_id: int) -> WellnessPlan | None:
        db = SessionLocal()
        try:
            return db.query(WellnessPlan).filter(WellnessPlan.id == plan_id).first()
        finally:
            db.close()

    def get_plan_for_assessment(self, assessment_id: int) -> WellnessPlan | None:
        db = SessionLocal()
        try:
            return (
                db.query(WellnessPlan)
                .filter(WellnessPlan.assessment_id == assessment_id)
                .first()
            )
        finally:
            db.close()

    def get_progress(self, plan_id: int) -> list[PlanProgress]:
        db = SessionLocal()
        try:
            return (
                db.query(PlanProgress)
                .filter(PlanProgress.plan_id == plan_id)
                .order_by(PlanProgress.day_number.asc())
                .all()
            )
        finally:
            db.close()

    def set_day_completed(
        self, plan_id: int, day_number: int, completed: bool
    ) -> PlanProgress:
        db = SessionLocal()
        try:
            if not db.query(WellnessPlan).filter(WellnessPlan.id == plan_id).first():
                raise PlanNotFoundError(f"No wellness plan with id {plan_id}")

            row = (
                db.query(PlanProgress)
                .filter(
                    PlanProgress.plan_id == plan_id,
                    PlanProgress.day_number == day_number,
                )
                .first()
            )
            if row is None:
                row = PlanProgress(plan_id=plan_id, day_number=day_number, completed=False)
                db.add(row)

            row.completed = completed
            row.completed_at = datetime.now(timezone.utc) if completed else None
            db.commit()
            db.refresh(row)
            return row
        finally:
            db.close()
