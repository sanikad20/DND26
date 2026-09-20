from sqlalchemy import Column, DateTime, Integer, String, Text
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