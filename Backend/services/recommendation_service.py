from core.logging import get_logger
from core.safety import find_banned_terms
from schemas.occupational import (
    ContributorItem,
    DayPlanItem,
    OccupationalAnswers,
    RecommendationItem,
)

logger = get_logger(__name__)


# Top 3 across both contributor lists, MODEL first (the trained model is
# the primary signal — Section 6.1), in the order they were flagged.
# Wording is action-only, no diagnostic/clinical language. The mandatory
# medical disclaimer lives on the result screen itself, not here.
_RECOMMENDATION_BY_CONTRIBUTOR = {
    "High workload": "Flag workload concerns to your immediate supervisor; ask about redistributing tasks during peak periods.",
    "Low control over work": "Raise scheduling/task-input concerns in your next unit briefing.",
    "Low supervisor/org support": "Identify one trusted senior/peer to check in with weekly.",
    "High effort demands": "Document your contributions for your next review cycle so effort is visible and trackable.",
    "Low recognition/reward": "Discuss recognition gaps directly with your reporting officer.",
    "Long duty hours": "Request a workload review if this pattern continues beyond 2 weeks.",
    "Insufficient recovery": "Prioritize at least one full rest day this week.",
    "Heavy night-shift load": "Speak to your scheduling officer about night-shift rotation frequency.",
    "Poor recovery quality": "Review your pre-sleep routine and duty-hour spacing with a medical/welfare officer if it doesn't improve.",
    "Limited family/social recovery time": "Block out dedicated time with family/friends outside duty hours, even briefly.",
}

# Feature -> plain-language label, used to turn the model's own math
# (coefficient x distance from average — see ml/occupational_model.py)
# into the same labels the UI already shows. The sign is already correct
# in the contribution value itself: e.g. a LOW control answer produces a
# POSITIVE contribution toward risk (because low control genuinely does
# increase risk), so this mapping never needs its own threshold logic —
# it just names whichever features the math actually flagged.
_MODEL_FEATURE_LABELS = {
    "demandmedia": "High workload",
    "controlmedia": "Low control over work",
    "supportmedia": "Low supervisor/org support",
    "effortmedia": "High effort demands",
    "rewardmedia": "Low recognition/reward",
}

# A feature counts as a real contributor (or, on the other side, a real
# model-driven protective factor) only once its contribution crosses this
# magnitude — near-zero contributions are just an average answer and
# shouldn't read as a flagged driver either way. Chosen empirically so a
# neutral "all 3s" persona shows nothing on either side, matching the
# pre-existing threshold-rule behaviour this replaces.
_CONTRIBUTION_THRESHOLD = 0.15

# Low risk gets a short "maintain" list instead of a full plan (Section 6.3).
_MAINTAIN_TIPS = [
    (
        "Use your leave",
        "Keep taking your leave days as they come up rather than banking them.",
    ),
    (
        "Keep your check-in",
        "Keep your weekly check-in with a trusted senior/peer going.",
    ),
    (
        "Protect a rest day",
        "Protect at least one full rest day a week, even during busier stretches.",
    ),
]

# Used to fill the three "focus" days when fewer than 3 contributors were
# flagged, so a Moderate/High plan is always a full 7 days.
_DEFAULT_FOCUS = [
    (
        "Protect one block",
        "Block out one uninterrupted rest period and treat it as non-negotiable.",
    ),
    (
        "Check the roster",
        "Look at your next 2 weeks' schedule for an avoidable clash (back-to-back night shifts, no leave gap).",
    ),
    (
        "One conversation",
        "Raise your biggest current pressure with a supervisor or trusted senior.",
    ),
]

class RecommendationService:
    def model_contributors(
        self,
        contributions: dict,
    ) -> list[ContributorItem]:
        """Built from the model's own coefficient x distance-from-average
        math (the plan's specified explainability method for Logistic
        Regression), not answer thresholds. Sorted by contribution size
        so the biggest driver toward risk comes first."""
        ranked = sorted(
            contributions.items(), key=lambda kv: kv[1], reverse=True
        )
        return [
            ContributorItem(label=_MODEL_FEATURE_LABELS[feature], layer="MODEL")
            for feature, value in ranked
            if value > _CONTRIBUTION_THRESHOLD
        ]

    def context_contributors(
        self,
        answers: OccupationalAnswers,
    ) -> list[ContributorItem]:
        contributors: list[ContributorItem] = []
        if answers.duty_hours_per_day >= 12:
            contributors.append(ContributorItem(label="Long duty hours", layer="CONTEXT"))
        if answers.consecutive_days_no_rest >= 10:
            contributors.append(
                ContributorItem(label="Insufficient recovery", layer="CONTEXT")
            )
        if answers.night_duties_last_2wks >= 6:
            contributors.append(
                ContributorItem(label="Heavy night-shift load", layer="CONTEXT")
            )
        if answers.recovery_quality <= 2:
            contributors.append(
                ContributorItem(label="Poor recovery quality", layer="CONTEXT")
            )
        if answers.family_time <= 2:
            contributors.append(
                ContributorItem(
                    label="Limited family/social recovery time",
                    layer="CONTEXT",
                )
            )
        return contributors

    def protective_factors(
        self,
        answers: OccupationalAnswers,
        contributions: dict,
    ) -> list[str]:
        factors: list[str] = []
        if answers.leave_days_taken_3mo >= 5:
            factors.append("Recent leave taken")
        if answers.family_time >= 4:
            factors.append("Good family/social connection")
        # Model-driven: a strongly NEGATIVE contribution means that answer
        # pushed away from High risk (the same coefficient x distance
        # math as model_contributors, just the protective direction).
        if contributions.get("supportmedia", 0) < -_CONTRIBUTION_THRESHOLD:
            factors.append("Strong supervisor/org support")
        return factors

    def build_recommendation_items(
        self,
        model_contributors: list[ContributorItem],
        context_contributors: list[ContributorItem],
    ) -> list[RecommendationItem]:
        """Top 3 across both lists, MODEL first, in flagged order. Not a
        full dump of every contributor — a High-risk result with several
        contributors firing still gets exactly 3 focused recommendations."""
        ordered_labels = [c.label for c in model_contributors] + [
            c.label for c in context_contributors
        ]
        items: list[RecommendationItem] = []
        for label in ordered_labels[:3]:
            text = _RECOMMENDATION_BY_CONTRIBUTOR.get(label)
            if text and self._is_safe(text):
                items.append(RecommendationItem(label=label, text=text))
        return items

    def build_recommendations(
        self,
        model_contributors: list[ContributorItem],
        context_contributors: list[ContributorItem],
    ) -> list[str]:
        return [
            item.text
            for item in self.build_recommendation_items(
                model_contributors, context_contributors
            )
        ]

    def build_plan(
        self,
        risk_level: str,
        model_contributors: list[ContributorItem] | None = None,
        context_contributors: list[ContributorItem] | None = None,
    ) -> list[DayPlanItem]:
        """Low risk -> 3 "maintain" tips. Moderate/High -> a 7-day plan whose
        middle days (2-4) are built from the top 3 contributors, so two High
        results with different causes get different plans (Section 6.3).
        Day 7 is always "Repeat the assessment" — it powers the trend."""
        if risk_level.strip().lower() == "low":
            return [
                self._checked_day(
                    DayPlanItem(
                        day=i + 1,
                        title=title,
                        detail="Keep this going while things are steady.",
                        tasks=[tip],
                    )
                )
                for i, (title, tip) in enumerate(_MAINTAIN_TIPS)
            ]

        top_labels = [
            c.label
            for c in (model_contributors or []) + (context_contributors or [])
        ][:3]

        focus_days: list[tuple[str, str, str]] = []  # (title, detail, task)
        for label in top_labels:
            text = _RECOMMENDATION_BY_CONTRIBUTOR.get(label)
            if text:
                focus_days.append(
                    (
                        f"Focus: {label}",
                        "One of your top flagged factors — a small, specific step this week.",
                        text,
                    )
                )
        for title, task in _DEFAULT_FOCUS:
            if len(focus_days) >= 3:
                break
            focus_days.append(
                (title, "A small step that helps whatever is weighing on you most.", task)
            )

        days = [
            DayPlanItem(
                day=1,
                title="Reset & recover",
                detail="Begin with a simple reset so the week feels manageable.",
                tasks=[
                    "Note how you slept and how heavy duty felt today.",
                    "Choose one protected rest or decompression window.",
                ],
            )
        ]
        for offset, (title, detail, task) in enumerate(focus_days[:3]):
            days.append(
                DayPlanItem(day=2 + offset, title=title, detail=detail, tasks=[task])
            )
        days.extend(
            [
                DayPlanItem(
                    day=5,
                    title="Family & social connection",
                    detail="Time with people outside duty is one of the strongest recovery supports.",
                    tasks=[
                        "Spend real time with family or friends outside duty hours — even one evening counts.",
                    ],
                ),
                DayPlanItem(
                    day=6,
                    title="Recharge & support",
                    detail="A short recharge routine helps carry the plan into the final day.",
                    tasks=[
                        "Do a short walk, stretch or quiet decompression routine.",
                        "Check in with one trusted peer or senior.",
                    ],
                ),
                DayPlanItem(
                    day=7,
                    title="Repeat the assessment",
                    detail="Compare your score with today's to see whether this week's steps helped.",
                    tasks=[
                        "Retake this assessment and compare your score against the one from Day 1.",
                    ],
                ),
            ]
        )
        return [self._checked_day(day) for day in days]

    # -- wording guard (Section 6.3) --------------------------------------

    @staticmethod
    def _is_safe(text: str) -> bool:
        found = find_banned_terms(text)
        if found:
            logger.warning("Dropped unsafe wellness wording %s: %r", found, text)
        return not found

    def _checked_day(self, day: DayPlanItem) -> DayPlanItem:
        """Replace any line that trips the guard with a neutral fallback
        rather than ever shipping it."""
        safe_tasks = [t for t in day.tasks if self._is_safe(t)]
        safe_detail = day.detail if self._is_safe(day.detail) else ""
        safe_title = day.title if self._is_safe(day.title) else f"Day {day.day}"
        return DayPlanItem(
            day=day.day, title=safe_title, detail=safe_detail, tasks=safe_tasks
        )
