from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
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


# ─────────────────────────────────────────────────────────────────────────────
# Organizational & Welfare Layer Models (Additive)
# ─────────────────────────────────────────────────────────────────────────────

class PersonnelProfile(Base):
    """Links Firebase UID to an organizational identity, role, and unit.
    Supported roles: 'personnel', 'welfare_officer', 'commander', 'admin'."""

    __tablename__ = "personnel_profiles"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String, unique=True, index=True, nullable=False)
    personnel_id = Column(String, unique=True, index=True, nullable=False)
    role = Column(String, nullable=False, default="personnel")
    unit_id = Column(String, index=True, nullable=False, default="UNIT-ALPHA")
    rank_designation = Column(String, nullable=True)
    opt_in_optional_wellness = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class HRDemoRecord(Base):
    """Synthetic HRMS records for demonstration purposes only.
    Clearly labeled 'Synthetic demonstration data'.
    NOT real CRPF/CAPF personnel data and NOT used to retrain ML models."""

    __tablename__ = "hr_demo_records"

    id = Column(Integer, primary_key=True, index=True)
    personnel_id = Column(String, index=True, nullable=False)
    unit_id = Column(String, index=True, nullable=False)
    duty_hours = Column(Float, nullable=False, default=8.0)
    night_shift_count = Column(Integer, nullable=False, default=0)
    consecutive_duty_days = Column(Integer, nullable=False, default=0)
    leave_days = Column(Integer, nullable=False, default=0)
    deployment_days = Column(Integer, nullable=False, default=0)
    transfer_count = Column(Integer, nullable=False, default=0)
    training_days = Column(Integer, nullable=False, default=0)
    workload_level = Column(String, nullable=False, default="Normal")
    is_synthetic = Column(Boolean, default=True, nullable=False)
    data_notice = Column(String, default="Synthetic demonstration data", nullable=False)
    record_date = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class WelfareAlert(Base):
    """Welfare-oriented alerts for authorized Welfare Officers.
    Uses supportive, privacy-conscious language.
    Does not use disciplinary or clinical diagnostic terms."""

    __tablename__ = "welfare_alerts"

    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(String, unique=True, index=True, nullable=False)
    personnel_id = Column(String, index=True, nullable=False)
    unit_id = Column(String, index=True, nullable=False)
    alert_type = Column(String, nullable=False)
    severity = Column(String, nullable=False, default="moderate")  # low, moderate, high
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    status = Column(String, default="active", nullable=False)  # active, acknowledged, resolved
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    resolved_at = Column(DateTime(timezone=True), nullable=True)


class AuditLog(Base):
    """Dedicated audit log for sensitive officer access.
    Records actor, role, action, target type, and timestamp.
    NEVER stores raw questionnaire answers or Firebase tokens."""

    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor_uid = Column(String, index=True, nullable=False)
    actor_role = Column(String, nullable=False)
    action = Column(String, nullable=False)
    target_type = Column(String, nullable=False)
    target_id = Column(String, nullable=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

