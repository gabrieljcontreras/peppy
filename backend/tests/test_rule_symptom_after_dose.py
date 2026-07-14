import json
from datetime import date, datetime, timezone

import pytest

from app.ml.rules import DEFAULT_RULES
from app.ml.rules.symptom_after_dose import symptom_after_dose_rule
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol
from app.models.user import User

START = date(2026, 6, 1)
END = date(2026, 6, 30)


async def _seed_protocol(db, user):
    protocol = Protocol(user_id=user.id, name="Test", start_date=START, is_active=True)
    db.add(protocol)
    await db.flush()
    compound = Compound(
        protocol_id=protocol.id,
        name="Retatrutide",
        dose_mg=4,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
    )
    db.add(compound)
    await db.flush()
    return protocol, compound


async def _seed(db, doses, checkins):
    """Seed doses and check-ins represented by ``(date, symptom-values)`` pairs."""
    user = User(email="rule1@test.com", hashed_password="x")
    db.add(user)
    await db.flush()
    protocol, compound = await _seed_protocol(db, user)

    for dose in doses:
        administered_at = (
            dose
            if isinstance(dose, datetime)
            else datetime(dose.year, dose.month, dose.day, 9, tzinfo=timezone.utc)
        )
        db.add(
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4,
                unit="mg",
                route="subcutaneous",
                administered_at=administered_at,
            )
        )

    for checkin_date, symptom_values in checkins:
        db.add(Checkin(user_id=user.id, date=checkin_date, **symptom_values))

    await db.commit()
    return user


@pytest.mark.asyncio
async def test_fires_when_nausea_follows_three_of_four_doses(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 4}),
        (date(2026, 6, 15), {"nausea": 6}),
        (date(2026, 6, 23), {"nausea": 0}),
        (date(2026, 6, 5), {"nausea": 0}),
        (date(2026, 6, 12), {"nausea": 0}),
        (date(2026, 6, 19), {"nausea": 1}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await symptom_after_dose_rule(db_session, user.id, START, END)

    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "anomaly"
    assert insight.severity.value == "warning"
    assert "nausea" in insight.title.lower()
    refs = json.loads(insight.source_data_refs)
    assert refs == {"rule": "symptom_after_dose", "symptom": "nausea", "month": "2026-06"}
    rows = json.loads(insight.supporting_data)
    assert any("3 of" in row["value"] for row in rows)


@pytest.mark.asyncio
async def test_silent_below_three_dose_events(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 8}),
        (date(2026, 6, 9), {"nausea": 8}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_silent_when_symptom_equally_common_on_non_dose_days(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
        (date(2026, 6, 16), {"nausea": 5}),
        (date(2026, 6, 5), {"nausea": 5}),
        (date(2026, 6, 12), {"nausea": 5}),
        (date(2026, 6, 19), {"nausea": 5}),
        (date(2026, 6, 26), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_silent_when_non_dose_rate_is_exactly_half_dose_window_rate(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
        (date(2026, 6, 16), {"nausea": 5}),
        (date(2026, 6, 3), {"nausea": 5}),
        (date(2026, 6, 4), {"nausea": 5}),
        (date(2026, 6, 5), {"nausea": 5}),
        (date(2026, 6, 6), {"nausea": 0}),
        (date(2026, 6, 10), {"nausea": 0}),
        (date(2026, 6, 11), {"nausea": 0}),
        (date(2026, 6, 12), {"nausea": 0}),
        (date(2026, 6, 13), {"nausea": 0}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("field", "display"),
    [
        ("nausea", "Nausea"),
        ("injection_site_reaction", "Injection-site reaction"),
        ("fatigue", "Fatigue"),
        ("headache", "Headache"),
        ("gi_issues", "GI discomfort"),
    ],
)
async def test_evaluates_each_named_symptom_field(db_session, field, display):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15)]
    checkins = [
        (date(2026, 6, 2), {field: 3}),
        (date(2026, 6, 9), {field: 4}),
        (date(2026, 6, 16), {field: 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await symptom_after_dose_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert display.lower() in results[0].title.lower()
    assert json.loads(results[0].source_data_refs)["symptom"] == field


@pytest.mark.asyncio
async def test_excludes_dose_at_midnight_after_end_date(db_session):
    doses = [
        date(2026, 6, 1),
        date(2026, 6, 8),
        date(2026, 6, 15),
        datetime(2026, 7, 1, 0, 0, tzinfo=timezone.utc),
    ]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
        (date(2026, 6, 16), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await symptom_after_dose_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert json.loads(results[0].source_data_refs)["month"] == "2026-06"
    rows = json.loads(results[0].supporting_data)
    dose_events_row = next(row for row in rows if row["label"] == "Dose events analyzed")
    assert dose_events_row["value"] == "3"


@pytest.mark.asyncio
async def test_duplicate_same_day_logs_count_as_one_distinct_dose_date(db_session):
    doses = [
        datetime(2026, 6, 1, 9, tzinfo=timezone.utc),
        datetime(2026, 6, 1, 18, tzinfo=timezone.utc),
        date(2026, 6, 8),
        date(2026, 6, 15),
    ]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
        (date(2026, 6, 16), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await symptom_after_dose_rule(db_session, user.id, START, END)

    assert len(results) == 1
    rows = json.loads(results[0].supporting_data)
    assert rows[0]["value"] == "3 of last 3 dose days"
    assert rows[1]["value"] == "3"


@pytest.mark.asyncio
async def test_only_latest_four_distinct_dose_dates_count_toward_occurrences(db_session):
    doses = [
        date(2026, 6, 1),
        date(2026, 6, 8),
        date(2026, 6, 15),
        date(2026, 6, 22),
        date(2026, 6, 29),
    ]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
        (date(2026, 6, 16), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_silent_with_three_dose_dates_but_only_two_occurrences(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 9), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_dedup_month_tracks_latest_dose_across_month_boundary(db_session):
    doses = [
        date(2026, 6, 15),
        date(2026, 6, 22),
        date(2026, 6, 29),
        date(2026, 7, 6),
    ]
    checkins = [
        (date(2026, 6, 16), {"nausea": 5}),
        (date(2026, 6, 23), {"nausea": 5}),
        (date(2026, 6, 30), {"nausea": 5}),
        (date(2026, 7, 7), {"nausea": 5}),
    ]
    user = await _seed(db_session, doses, checkins)

    june_results = await symptom_after_dose_rule(db_session, user.id, START, END)
    july_results = await symptom_after_dose_rule(db_session, user.id, START, date(2026, 7, 31))

    assert json.loads(june_results[0].source_data_refs)["month"] == "2026-06"
    assert json.loads(july_results[0].source_data_refs)["month"] == "2026-07"


@pytest.mark.asyncio
async def test_freezes_exact_evidence_values_and_analysis_window(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), {"nausea": 5}),
        (date(2026, 6, 8), {"nausea": 4}),
        (date(2026, 6, 16), {"nausea": 3}),
        (date(2026, 6, 5), {"nausea": 3}),
        (date(2026, 6, 6), {"nausea": 0}),
        (date(2026, 6, 12), {"nausea": 0}),
        (date(2026, 6, 19), {"nausea": 0}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await symptom_after_dose_rule(db_session, user.id, START, END)

    assert json.loads(results[0].supporting_data) == [
        {
            "icon_key": "symptom",
            "label": "Nausea after dose",
            "sublabel": "Within 24h of a logged dose",
            "value": "3 of last 4 dose days",
        },
        {
            "icon_key": "calendar",
            "label": "Dose events analyzed",
            "sublabel": "2026-06-01 – 2026-06-30",
            "value": "4",
        },
        {
            "icon_key": "chart",
            "label": "On non-dose days",
            "sublabel": "Same symptom, days without a dose",
            "value": "1 of 4 days",
        },
    ]


def test_registered_in_default_rules():
    assert symptom_after_dose_rule in DEFAULT_RULES
