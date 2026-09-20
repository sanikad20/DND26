from schemas.occupational import ContributorItem, DayPlanItem, OccupationalAnswers


# Top 3 across both contributor lists, MODEL first (the trained model is
# the primary signal — Section 6.1), in the order they were flagged.
# Wording is action-only, no diagnostic/clinical language. The mandatory
# medical disclaimer lives on the result screen itself, not here.
_RECOMMENDATION_BY_CONTRIBUTOR = {
    "High workload": "Flag workload concerns to your immediate supervisor; ask about redistributing tasks during peak periods.",
    "Low control over work": "Raise scheduling/task-input concerns in your next unit briefing.",
    "Low supervisor/org support": "Identify one trusted senior/peer to check in with weekly.",
    "Effort-reward imbalance": "Document your contributions for your next review cycle; discuss recognition gaps with your reporting officer.",
    "Long duty hours": "Request a workload review if this pattern continues beyond 2 weeks.",
    "Insufficient recovery": "Prioritize at least one full rest day this week.",
    "Heavy night-shift load": "Speak to your scheduling officer about night-shift rotation frequency.",
    "Poor recovery quality": "Review your pre-sleep routine and duty-hour spacing with a medical/welfare officer if it doesn't improve.",
    "Limited family/social recovery time": "Block out dedicated time with family/friends outside duty hours, even briefly.",
}

_MAINTAIN_TIPS = [
    "Keep taking your leave days as they come up rather than banking them.",
    "Keep your weekly check-in with a trusted senior/peer going.",
    "Protect at least one full rest day a week, even during busier stretches.",
]

_FULL_PLAN_TEMPLATE = [
    ("Name it", "Note down which duty patterns felt heaviest this week — specific shifts, not a general feeling."),
    ("One conversation", "Raise your top flagged factor with a supervisor or trusted senior."),
    ("Protect one block", "Block out one uninterrupted rest period and treat it as non-negotiable."),
    ("Check the roster", "Look at your next 2 weeks' schedule for an avoidable clash (back-to-back night shifts, no leave gap)."),
    ("Reach out", "Spend real time with family/friends outside duty hours — even one evening counts."),
    ("Follow up", "Check whether the conversation from Day 2 led anywhere; escalate once more if not."),
    ("Repeat the assessment", "Retake this assessment and compare your score against today's."),
]


class RecommendationService:
    def model_contributors(
        self,
        answers: OccupationalAnswers,
    ) -> list[ContributorItem]:
        contributors: list[ContributorItem] = []
        if answers.demand >= 4:
            contributors.append(ContributorItem(label="High workload", layer="MODEL"))
        if answers.control <= 2:
            contributors.append(
                ContributorItem(label="Low control over work", layer="MODEL")
            )
        if answers.support <= 2:
            contributors.append(
                ContributorItem(label="Low supervisor/org support", layer="MODEL")
            )
        if answers.effort >= 4 and answers.reward <= 2:
            contributors.append(
                ContributorItem(label="Effort-reward imbalance", layer="MODEL")
            )
        return contributors

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

    def protective_factors(self, answers: OccupationalAnswers) -> list[str]:
        factors: list[str] = []
        if answers.leave_days_taken_3mo >= 5:
            factors.append("Recent leave taken")
        if answers.family_time >= 4:
            factors.append("Good family/social connection")
        if answers.support >= 4:
            factors.append("Strong supervisor/org support")
        return factors

    def build_recommendations(
        self,
        model_contributors: list[ContributorItem],
        context_contributors: list[ContributorItem],
    ) -> list[str]:
        """Top 3 across both lists, MODEL first, in flagged order. Not a
        full dump of every contributor — a High-risk result with 7
        contributors firing still gets exactly 3 focused recommendations."""
        ordered_labels = [c.label for c in model_contributors] + [
            c.label for c in context_contributors
        ]
        top3 = ordered_labels[:3]
        return [
            _RECOMMENDATION_BY_CONTRIBUTOR[label]
            for label in top3
            if label in _RECOMMENDATION_BY_CONTRIBUTOR
        ]

    def build_plan(self, risk_level: str) -> list[DayPlanItem]:
        if risk_level == "Low":
            return [
                DayPlanItem(day=i + 1, title="Maintain", detail=tip)
                for i, tip in enumerate(_MAINTAIN_TIPS)
            ]
        return [
            DayPlanItem(day=i + 1, title=title, detail=detail)
            for i, (title, detail) in enumerate(_FULL_PLAN_TEMPLATE)
        ]