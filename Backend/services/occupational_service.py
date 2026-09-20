from datetime import datetime

from ml.occupational_model import OccupationalStressModel
from repositories.occupational_repository import OccupationalRepository
from schemas.occupational import (
    AssessmentResult,
    HistoryResponse,
    OccupationalAnswers,
)
from services.recommendation_service import RecommendationService


QUESTIONNAIRE = [
    {
        "id": 1,
        "text": "How many hours are you actively on duty per day?",
        "input_type": "slider",
        "min": 4,
        "max": 16,
        "maps_to": "Operational load",
        "layer": "CONTEXT",
    },
    {
        "id": 2,
        "text": "Night duties/shifts in the last 2 weeks?",
        "input_type": "slider",
        "min": 0,
        "max": 14,
        "maps_to": "Circadian/recovery load",
        "layer": "CONTEXT",
    },
    {
        "id": 3,
        "text": "Consecutive days without a full rest day?",
        "input_type": "slider",
        "min": 0,
        "max": 30,
        "maps_to": "Recovery deficit",
        "layer": "CONTEXT",
    },
    {
        "id": 4,
        "text": "Days since your last leave/off day?",
        "input_type": "slider",
        "min": 0,
        "max": 180,
        "maps_to": "Recovery/family access",
        "layer": "CONTEXT",
    },
    {
        "id": 5,
        "text": "Leave days actually taken in the last 3 months?",
        "input_type": "number",
        "min": 0,
        "max": 30,
        "maps_to": "Recovery access",
        "layer": "CONTEXT",
    },
    {
        "id": 6,
        "text": "How demanding is your current workload?",
        "input_type": "likert_5",
        "maps_to": "Demand (DCS)",
        "layer": "MODEL",
    },
    {
        "id": 7,
        "text": "How much control/say over how & when you work?",
        "input_type": "likert_5",
        "maps_to": "Control (DCS)",
        "layer": "MODEL",
    },
    {
        "id": 8,
        "text": "How supported do you feel by supervisors/organisation?",
        "input_type": "likert_5",
        "maps_to": "Support (DCS)",
        "layer": "MODEL",
    },
    {
        "id": 9,
        "text": "Effort required relative to what's expected?",
        "input_type": "likert_5",
        "maps_to": "Effort (ERI)",
        "layer": "MODEL",
    },
    {
        "id": 10,
        "text": "How adequately recognised/rewarded for that effort?",
        "input_type": "likert_5",
        "maps_to": "Reward (ERI)",
        "layer": "MODEL",
    },
    {
        "id": 11,
        "text": "Sleep/recovery quality this week?",
        "input_type": "likert_5",
        "maps_to": "Recovery quality",
        "layer": "CONTEXT",
    },
    {
        "id": 12,
        "text": "Quality time with family/loved ones (2 weeks)?",
        "input_type": "likert_5",
        "maps_to": "Family separation",
        "layer": "CONTEXT",
    },
]


class OccupationalService:
    def __init__(
        self,
        model: OccupationalStressModel,
        recommendations: RecommendationService,
        repository: OccupationalRepository,
    ):
        self._model = model
        self._recommendations = recommendations
        self._repository = repository

    def get_questionnaire(self) -> dict:
        return {"questions": QUESTIONNAIRE, "count": len(QUESTIONNAIRE)}

    def assess(self, answers: OccupationalAnswers) -> AssessmentResult:
        model_output = self._model.predict(answers)
        score = self._apply_context_nudge(
            base_score=model_output.base_score,
            risk_level=model_output.risk_level,
            answers=answers,
        )

        model_contributors = self._recommendations.model_contributors(
            model_output.contributions
        )
        context_contributors = self._recommendations.context_contributors(answers)

        result = AssessmentResult(
            risk_level=model_output.risk_level,
            score=score,
            model_contributors=model_contributors,
            context_contributors=context_contributors,
            protective_factors=self._recommendations.protective_factors(
                answers, model_output.contributions
            ),
            recommendations=self._recommendations.build_recommendations(
                model_contributors, context_contributors
            ),
            recommendation_items=self._recommendations.build_recommendation_items(
                model_contributors, context_contributors
            ),
            plan=self._recommendations.build_plan(
                model_output.risk_level,
                model_contributors,
                context_contributors,
            ),
            model_version=self._model.model_version,
            placeholder_scoring=False,
            generated_at=datetime.utcnow().isoformat(),
        )
        self._repository.save_assessment(answers, result)
        return result

    def get_history(self, firebase_uid: str) -> HistoryResponse:
        return self._repository.get_history(firebase_uid)

    @staticmethod
    def _apply_context_nudge(
        base_score: float,
        risk_level: str,
        answers: OccupationalAnswers,
    ) -> int:
        """Small, capped refinement from the 7 CONTEXT answers (Section 6.1).

        Can move the score up (strain) or down (protective), never by more
        than +/-15, and can never lift a Low result into High territory.
        The risk LABEL is never touched here — it always comes from the model.
        The point weights are hand-set placeholders, not learned from data.
        """
        nudge = 0.0

        # Strain: pushes the score up.
        if answers.duty_hours_per_day >= 12:
            nudge += 3
        if answers.night_duties_last_2wks >= 6:
            nudge += 3
        if answers.consecutive_days_no_rest >= 10:
            nudge += 3
        if answers.days_since_last_leave >= 60:
            nudge += 2
        if answers.recovery_quality <= 2:
            nudge += 2
        if answers.family_time <= 2:
            nudge += 2

        # Protective: pulls the score down. Mirrors the protective factors
        # shown on the result screen.
        if answers.recovery_quality >= 4:
            nudge -= 2
        if answers.family_time >= 4:
            nudge -= 2
        if answers.leave_days_taken_3mo >= 5:
            nudge -= 2
        if answers.days_since_last_leave <= 14:
            nudge -= 2

        nudged_score = base_score + max(-15.0, min(15.0, nudge))
        if risk_level == "Low":
            nudged_score = min(nudged_score, 66.0)
        return int(round(max(0.0, min(100.0, nudged_score))))
