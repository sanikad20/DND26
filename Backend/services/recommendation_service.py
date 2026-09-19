from schemas.occupational import ContributorItem, OccupationalAnswers


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
