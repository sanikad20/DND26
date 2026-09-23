"""Occupational Stress: personas, contributor direction, context layer,
plan/recommendation rules, wording guard and week-over-week trend."""
from datetime import datetime, timedelta

import pytest

from core.safety import find_banned_terms, is_clean
from ml.model_loader import get_occupational_model
from repositories.occupational_repository import OccupationalRepository
from schemas.occupational import ContributorItem, OccupationalAnswers
from services import recommendation_service as rec_mod
from services.occupational_service import QUESTIONNAIRE, OccupationalService
from services.recommendation_service import RecommendationService

from conftest import DUTY_STRAIN_ONLY, RELAXED, STRESSED, auth_header, make_answers

MODEL_LABELS = {
    "High workload",
    "Low control over work",
    "Low supervisor/org support",
    "High effort demands",
    "Low recognition/reward",
}


def assess(client, uid, **overrides):
    r = client.post(
        "/occupational/assess",
        json=make_answers(**overrides),
        headers=auth_header(uid),
    )
    assert r.status_code == 200, r.text
    return r.json()


# ---------------------------------------------------------------- personas


def test_stressed_persona_is_high_with_all_model_drivers(occ_client):
    d = assess(occ_client, "persona-stressed", **STRESSED)
    assert d["risk_level"] == "High"
    assert d["score"] >= 67
    assert {c["label"] for c in d["model_contributors"]} == MODEL_LABELS
    assert all(c["layer"] == "MODEL" for c in d["model_contributors"])
    assert len(d["context_contributors"]) == 5
    assert all(c["layer"] == "CONTEXT" for c in d["context_contributors"])
    assert d["protective_factors"] == []


def test_relaxed_persona_is_low_with_no_drivers(occ_client):
    d = assess(occ_client, "persona-relaxed", **RELAXED)
    assert d["risk_level"] == "Low"
    assert d["score"] <= 66
    assert d["model_contributors"] == []
    assert d["context_contributors"] == []
    assert "Strong supervisor/org support" in d["protective_factors"]
    assert "Recent leave taken" in d["protective_factors"]


def test_neutral_persona_shows_no_model_drivers(occ_client):
    d = assess(occ_client, "persona-neutral")
    assert d["risk_level"] != "High"
    assert d["model_contributors"] == []


# ------------------------------------------------ contributor direction


@pytest.mark.parametrize(
    "field, higher_answer_means_more_risk",
    [
        ("demand", True),
        ("effort", True),
        ("control", False),
        ("support", False),
        ("reward", False),
    ],
)
def test_contribution_direction_matches_answer_direction(field, higher_answer_means_more_risk):
    """Raising a demand/effort answer must push toward High risk; raising a
    control/support/reward answer must push away from it."""
    model = get_occupational_model()
    feature = {
        "demand": "demandmedia",
        "control": "controlmedia",
        "support": "supportmedia",
        "effort": "effortmedia",
        "reward": "rewardmedia",
    }[field]
    low = model.predict(OccupationalAnswers(**make_answers(**{field: 1}))).contributions[feature]
    high = model.predict(OccupationalAnswers(**make_answers(**{field: 5}))).contributions[feature]
    if higher_answer_means_more_risk:
        assert high > low
    else:
        assert high < low


# -------------------------------------------------------- context layer

BASE = 50.0


def nudge(risk="Moderate", base=BASE, **overrides):
    return OccupationalService._apply_context_nudge(
        base, risk, OccupationalAnswers(**make_answers(**overrides))
    )


def test_context_nudge_can_raise_the_score():
    assert nudge(duty_hours_per_day=14) > nudge()


def test_context_nudge_can_lower_the_score():
    assert nudge(recovery_quality=5, family_time=5) < nudge()


def test_context_nudge_is_capped_at_15_either_way():
    worst = nudge(**STRESSED)
    best = nudge(**RELAXED)
    assert worst - BASE <= 15
    assert BASE - best <= 15


def test_context_nudge_cannot_push_a_low_result_into_high_territory():
    assert nudge(risk="Low", base=60.0, **STRESSED) <= 66


def test_context_layer_never_changes_the_risk_label(occ_client):
    """Same 5 model answers, wildly different context -> same label."""
    a = assess(occ_client, "label-a", **DUTY_STRAIN_ONLY)
    b = assess(occ_client, "label-b")
    assert a["risk_level"] == b["risk_level"]
    assert a["score"] > b["score"]


# ------------------------------------------- recommendations and the plan


def test_low_risk_gets_three_maintain_tips_not_a_full_plan(occ_client):
    d = assess(occ_client, "plan-low", **RELAXED)
    assert len(d["plan"]) == 3
    assert [p["day"] for p in d["plan"]] == [1, 2, 3]


@pytest.mark.parametrize("persona", [STRESSED, DUTY_STRAIN_ONLY])
def test_non_low_plan_is_seven_days_and_day_seven_is_repeat(occ_client, persona):
    d = assess(occ_client, "plan-high", **persona)
    assert d["risk_level"] != "Low"
    assert [p["day"] for p in d["plan"]] == [1, 2, 3, 4, 5, 6, 7]
    assert d["plan"][-1]["title"] == "Repeat the assessment"


def test_recommendations_are_top_three_and_match_items(occ_client):
    d = assess(occ_client, "recs-stressed", **STRESSED)
    assert len(d["recommendations"]) == 3
    assert d["recommendations"] == [i["text"] for i in d["recommendation_items"]]
    # MODEL contributors come first.
    assert [i["label"] for i in d["recommendation_items"]] == [
        c["label"] for c in d["model_contributors"]
    ][:3]


def test_different_causes_get_different_plans(occ_client):
    model_driven = assess(occ_client, "cause-model", **STRESSED)
    duty_driven = assess(occ_client, "cause-duty", **DUTY_STRAIN_ONLY)
    titles_a = [p["title"] for p in model_driven["plan"]]
    titles_b = [p["title"] for p in duty_driven["plan"]]
    assert titles_a != titles_b


def test_plan_falls_back_to_default_focus_when_nothing_flagged():
    plan = RecommendationService().build_plan("Moderate", [], [])
    assert len(plan) == 7
    assert plan[1].title == "Protect one block"


# ---------------------------------------------------------- wording guard


def test_guard_detects_banned_words():
    for text in ["signs of depression", "Anxiety levels", "possible PTSD", "a diagnosis", "clinically"]:
        assert not is_clean(text), text
    assert find_banned_terms("This is diagnostic of a disorder") == ["diagnos", "disorder"]
    assert is_clean("Keep your weekly check-in with a trusted senior/peer going.")


def _all_static_strings():
    strings = [q["text"] for q in QUESTIONNAIRE]
    strings += list(rec_mod._RECOMMENDATION_BY_CONTRIBUTOR.values())
    for title, text in rec_mod._MAINTAIN_TIPS + rec_mod._DEFAULT_FOCUS:
        strings += [title, text]
    return strings


def test_all_static_wording_is_clean():
    offenders = [s for s in _all_static_strings() if not is_clean(s)]
    assert offenders == []


def test_every_generated_plan_and_recommendation_is_clean():
    service = RecommendationService()
    all_labels = list(rec_mod._RECOMMENDATION_BY_CONTRIBUTOR)
    contributor_sets = [[]] + [[label] for label in all_labels] + [all_labels[:3], all_labels[-3:]]
    for labels in contributor_sets:
        items = [ContributorItem(label=l, layer="MODEL") for l in labels]
        for risk in ("Low", "Moderate", "High"):
            for day in service.build_plan(risk, items, []):
                for text in [day.title, day.detail, *day.tasks]:
                    assert is_clean(text), (risk, labels, text)
        for text in service.build_recommendations(items, []):
            assert is_clean(text), text


def test_unsafe_text_is_dropped_rather_than_shipped(monkeypatch):
    monkeypatch.setitem(
        rec_mod._RECOMMENDATION_BY_CONTRIBUTOR, "High workload", "This may be depression."
    )
    items = RecommendationService().build_recommendation_items(
        [ContributorItem(label="High workload", layer="MODEL")], []
    )
    assert items == []


# ------------------------------------------------------ week-over-week trend

NOW = datetime(2026, 9, 20, 12, 0, 0)


def days_ago(n):
    return NOW - timedelta(days=n)


@pytest.mark.parametrize(
    "points, expected",
    [
        ([], "Not enough data"),
        ([(days_ago(1), 60)], "Not enough data"),  # nothing from last week
        ([(days_ago(9), 60)], "Not enough data"),  # nothing from this week
        ([(days_ago(1), 60), (days_ago(2), 62)], "Not enough data"),  # same week only
        ([(days_ago(1), 50), (days_ago(9), 60)], "Improving"),
        ([(days_ago(1), 70), (days_ago(9), 60)], "Worsening"),
        ([(days_ago(1), 62), (days_ago(9), 60)], "Stable"),
        ([(days_ago(1), 55), (days_ago(9), 60)], "Improving"),  # exactly 5 lower
        ([(days_ago(1), 65), (days_ago(9), 60)], "Worsening"),  # exactly 5 higher
        ([(days_ago(20), 10), (days_ago(1), 60)], "Not enough data"),  # too old
        # several assessments in a week are averaged: (40+60)/2=50 vs 60
        ([(days_ago(1), 40), (days_ago(3), 60), (days_ago(9), 60)], "Improving"),
    ],
)
def test_weekly_trend(points, expected):
    assert OccupationalRepository._compute_trend(points, now=NOW) == expected


def test_history_endpoint_round_trip(occ_client):
    uid = "history-user"
    assess(occ_client, uid, **STRESSED)
    r = occ_client.get("/occupational/history", headers=auth_header(uid))
    assert r.status_code == 200
    body = r.json()
    assert len(body["assessments"]) == 1
    assert body["assessments"][0]["risk_level"] == "High"
    assert body["trend"] == "Not enough data"


def test_history_is_private_per_user(occ_client):
    assess(occ_client, "user-one", **STRESSED)
    body = occ_client.get("/occupational/history", headers=auth_header("user-two")).json()
    assert body["assessments"] == []


def test_history_endpoint_with_path_param_uid(occ_client):
    uid = "history-user-path"
    assess(occ_client, uid, **STRESSED)
    r = occ_client.get(f"/occupational/history/{uid}", headers=auth_header(uid))
    assert r.status_code == 200
    assert len(r.json()["assessments"]) == 1

    # Mismatched uid in path vs bearer token must be rejected with 403
    r_forbidden = occ_client.get(f"/occupational/history/{uid}", headers=auth_header("other-user"))
    assert r_forbidden.status_code == 403


def test_assessment_requires_authorization_header(occ_client):
    r = occ_client.post("/occupational/assess", json=make_answers())
    assert r.status_code == 401


@pytest.mark.parametrize("authorization", ["Bearer invalid", "Bearer uid:expired"])
def test_assessment_rejects_invalid_or_expired_token(occ_client, authorization):
    r = occ_client.post(
        "/occupational/assess",
        json=make_answers(),
        headers={"Authorization": authorization},
    )
    assert r.status_code == 401


def test_assessment_uses_verified_uid_not_client_supplied_uid(occ_client):
    r = occ_client.post(
        "/occupational/assess",
        json={**make_answers(), "firebase_uid": "attacker-uid"},
        headers=auth_header("verified-user"),
    )
    assert r.status_code == 200, r.text

    verified = occ_client.get(
        "/occupational/history",
        headers=auth_header("verified-user"),
    ).json()
    attacker = occ_client.get(
        "/occupational/history",
        headers=auth_header("attacker-uid"),
    ).json()

    assert len(verified["assessments"]) == 1
    assert attacker["assessments"] == []


def test_user_cannot_access_another_users_wellness_plan(occ_client):
    plan_id = assess(occ_client, "plan-owner", **STRESSED)["plan_id"]
    r = occ_client.get(
        f"/occupational/plans/{plan_id}",
        headers=auth_header("different-user"),
    )
    assert r.status_code == 403


def test_user_cannot_access_another_users_plan_progress(occ_client):
    plan_id = assess(occ_client, "progress-owner", **STRESSED)["plan_id"]
    r = occ_client.get(
        f"/occupational/plans/{plan_id}/progress",
        headers=auth_header("different-user"),
    )
    assert r.status_code == 403


def test_user_cannot_update_another_users_plan_progress(occ_client):
    plan_id = assess(occ_client, "progress-update-owner", **STRESSED)["plan_id"]
    r = occ_client.post(
        f"/occupational/plans/{plan_id}/progress",
        json={"day_number": 1, "completed": True},
        headers=auth_header("different-user"),
    )
    assert r.status_code == 403


def test_owner_can_update_plan_progress(occ_client):
    uid = "progress-owner-success"
    plan_id = assess(occ_client, uid, **STRESSED)["plan_id"]
    r = occ_client.post(
        f"/occupational/plans/{plan_id}/progress",
        json={"day_number": 1, "completed": True},
        headers=auth_header(uid),
    )
    assert r.status_code == 200, r.text
    assert r.json()["completed"] is True


def test_questionnaire_endpoint_serves_twelve_questions(occ_client):
    body = occ_client.get("/occupational/questionnaire").json()
    assert body["count"] == 12
    assert [q["id"] for q in body["questions"]] == list(range(1, 13))
