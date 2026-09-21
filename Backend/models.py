from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.sql import func
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)


class OccupationalAssessment(Base):
    __tablename__ = "occupational_assessments"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String, index=True, nullable=False)
    risk_level = Column(String, nullable=False)
    score = Column(Integer, nullable=False)
    model_version = Column(String, nullable=False)
    # JSON-serialized copy of the 12 raw answers, so a future model version
    # can re-score this assessment without asking the person to redo it.
    raw_answers = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class WellnessPlan(Base):
    """One plan per assessment. Keeping this as its own table (rather than
    embedding plan state on OccupationalAssessment) means a new assessment
    never has to overwrite or reset a previous plan's progress - it just
    creates a new plan row of its own."""

    __tablename__ = "wellness_plans"

    id = Column(Integer, primary_key=True, index=True)
    assessment_id = Column(
        Integer,
        ForeignKey("occupational_assessments.id"),
        nullable=False,
        index=True,
    )
    firebase_uid = Column(String, index=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PlanProgress(Base):
    """Per-day completion state for a WellnessPlan. One row per day that has
    been touched (created on first toggle); a day with no row is simply
    "not completed"."""

    __tablename__ = "plan_progress"

    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(
        Integer,
        ForeignKey("wellness_plans.id"),
        nullable=False,
        index=True,
    )
    day_number = Column(Integer, nullable=False)
    completed = Column(Boolean, default=False, nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
