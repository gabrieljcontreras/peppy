import json
from datetime import date, datetime, time, timezone

import pytest

from app.ml.rules import DEFAULT_RULES
from app.ml.rules.adherence_consistency import adherence_consistency_rule
from app.ml.rules.dose_day_energy_dip import dose_day_energy_dip_rule
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol
from app.models.user import User

START = date(2026, 6, 1)
END = date(2026, 6, 30)
DOSE_DATES = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15)]


async def _seed(db, doses, checkins):
    user = User(email="energy-dip@test.com", hashed_password="x")
    db.add(user)
    await db.flush()

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

    for dose in doses:
        administered_at = (
            dose
            if isinstance(dose, datetime)
            else datetime.combine(dose, time(hour=9), tzinfo=timezone.utc)
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

    for checkin_date, values in checkins:
        db.add(Checkin(user_id=user.id, date=checkin_date, **values))

    await db.commit()
    return user


@pytest.mark.asyncio
async def test_fires_warning_for_large_energy_gap_across_four_dose_dates(db_session):
    doses = DOSE_DATES + [date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 9), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 15), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 23), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 5), {"energy_level": 7, "mood": 7}),
        (date(2026, 6, 12), {"energy_level": 7, "mood": 7}),
        (date(2026, 6, 19), {"energy_level": 7, "mood": 7}),
        (date(2026, 6, 26), {"energy_level": 7, "mood": 7}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "trend"
    assert insight.severity.value == "warning"
    assert insight.title == "Energy dips on dose day"
    assert insight.description == (
        "Your average energy is 2.0/10 on dose days (and the day after) vs "
        "7.0/10 on other days. Mood shows the same pattern."
    )
    assert insight.confidence == 0.9
    assert json.loads(insight.source_data_refs) == {
        "rule": "dose_day_energy_dip",
        "month": "2026-06",
    }
    assert json.loads(insight.supporting_data) == [
        {
            "icon_key": "chart",
            "label": "Energy on dose days",
            "sublabel": "Dose day + day after",
            "value": "2.0 / 10 avg",
        },
        {
            "icon_key": "chart",
            "label": "Energy on other days",
            "sublabel": None,
            "value": "7.0 / 10 avg",
        },
        {
            "icon_key": "calendar",
            "label": "Dose days analyzed",
            "sublabel": "2026-06-01 – 2026-06-30",
            "value": "4",
        },
    ]


@pytest.mark.asyncio
async def test_silent_with_fewer_than_three_distinct_dose_dates(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 2), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 7}),
        (date(2026, 6, 5), {"energy_level": 7}),
    ]
    user = await _seed(db_session, DOSE_DATES[:2], checkins)

    assert await dose_day_energy_dip_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_silent_when_energy_gap_is_one_point(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 3}),
        (date(2026, 6, 2), {"energy_level": 3}),
        (date(2026, 6, 4), {"energy_level": 4}),
        (date(2026, 6, 5), {"energy_level": 4}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    assert await dose_day_energy_dip_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
@pytest.mark.parametrize("sparse_group", ["dose_window", "other"])
async def test_silent_when_either_group_has_fewer_than_two_non_null_energy_checkins(
    db_session, sparse_group
):
    dose_values = [2, None] if sparse_group == "dose_window" else [2, 2]
    other_values = [7, None] if sparse_group == "other" else [7, 7]
    checkins = [
        (date(2026, 6, 1), {"energy_level": dose_values[0]}),
        (date(2026, 6, 2), {"energy_level": dose_values[1]}),
        (date(2026, 6, 4), {"energy_level": other_values[0]}),
        (date(2026, 6, 5), {"energy_level": other_values[1]}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    assert await dose_day_energy_dip_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_exact_energy_and_mood_gap_threshold_fires_info_with_mood_clause(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 2), {"energy_level": 3, "mood": 3}),
        (date(2026, 6, 4), {"energy_level": 4, "mood": 4}),
        (date(2026, 6, 5), {"energy_level": 4, "mood": 4}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert results[0].severity.value == "info"
    assert results[0].description.endswith("Mood shows the same pattern.")


@pytest.mark.asyncio
async def test_exact_warning_gap_threshold_fires_warning(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 2), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 5}),
        (date(2026, 6, 5), {"energy_level": 5}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert results[0].severity.value == "warning"


@pytest.mark.asyncio
async def test_exact_fractional_energy_gap_threshold_fires(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 1}),
        (date(2026, 6, 9), {"energy_level": 2}),
        (date(2026, 6, 15), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 3}),
        (date(2026, 6, 5), {"energy_level": 3}),
        (date(2026, 6, 6), {"energy_level": 3}),
        (date(2026, 6, 12), {"energy_level": 3}),
        (date(2026, 6, 19), {"energy_level": 3}),
        (date(2026, 6, 26), {"energy_level": 4}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert results[0].severity.value == "info"


@pytest.mark.asyncio
async def test_exact_fractional_warning_gap_threshold_fires_warning(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 9), {"energy_level": 2}),
        (date(2026, 6, 15), {"energy_level": 3}),
        (date(2026, 6, 4), {"energy_level": 5}),
        (date(2026, 6, 12), {"energy_level": 5}),
        (date(2026, 6, 19), {"energy_level": 6}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert results[0].severity.value == "warning"


@pytest.mark.asyncio
async def test_exact_fractional_mood_gap_threshold_adds_mood_clause(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2, "mood": 1}),
        (date(2026, 6, 9), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 15), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 4), {"energy_level": 6, "mood": 3}),
        (date(2026, 6, 5), {"energy_level": 6, "mood": 3}),
        (date(2026, 6, 6), {"energy_level": 6, "mood": 3}),
        (date(2026, 6, 12), {"energy_level": 6, "mood": 3}),
        (date(2026, 6, 19), {"energy_level": 6, "mood": 3}),
        (date(2026, 6, 26), {"energy_level": 6, "mood": 4}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert results[0].description.endswith("Mood shows the same pattern.")


@pytest.mark.asyncio
async def test_omits_mood_clause_when_mood_gap_is_below_threshold(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2, "mood": 3}),
        (date(2026, 6, 2), {"energy_level": 2, "mood": 3}),
        (date(2026, 6, 4), {"energy_level": 6, "mood": 4}),
        (date(2026, 6, 5), {"energy_level": 6, "mood": 4}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert "Mood" not in results[0].description


@pytest.mark.asyncio
async def test_omits_mood_clause_without_two_mood_checkins_in_each_group(db_session):
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2, "mood": 2}),
        (date(2026, 6, 2), {"energy_level": 2, "mood": None}),
        (date(2026, 6, 4), {"energy_level": 6, "mood": 6}),
        (date(2026, 6, 5), {"energy_level": 6, "mood": 6}),
    ]
    user = await _seed(db_session, DOSE_DATES, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    assert len(results) == 1
    assert "Mood" not in results[0].description


@pytest.mark.asyncio
async def test_duplicate_same_day_logs_count_as_one_distinct_dose_date(db_session):
    doses = [
        datetime(2026, 6, 1, 9, tzinfo=timezone.utc),
        datetime(2026, 6, 1, 18, tzinfo=timezone.utc),
        date(2026, 6, 8),
        date(2026, 6, 15),
    ]
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 2), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 6}),
        (date(2026, 6, 5), {"energy_level": 6}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    rows = json.loads(results[0].supporting_data)
    assert rows[2]["value"] == "3"
    assert results[0].confidence == 0.8


@pytest.mark.asyncio
async def test_excludes_dose_exactly_at_midnight_after_end_date(db_session):
    doses = [
        date(2026, 6, 1),
        date(2026, 6, 8),
        datetime(2026, 7, 1, 0, 0, tzinfo=timezone.utc),
    ]
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 2), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 7}),
        (date(2026, 6, 5), {"energy_level": 7}),
    ]
    user = await _seed(db_session, doses, checkins)

    assert await dose_day_energy_dip_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_includes_dose_before_midnight_on_end_date(db_session):
    doses = [
        date(2026, 6, 1),
        date(2026, 6, 8),
        datetime(2026, 6, 30, 23, 59, 59, tzinfo=timezone.utc),
    ]
    checkins = [
        (date(2026, 6, 1), {"energy_level": 2}),
        (date(2026, 6, 2), {"energy_level": 2}),
        (date(2026, 6, 30), {"energy_level": 2}),
        (date(2026, 6, 4), {"energy_level": 7}),
        (date(2026, 6, 5), {"energy_level": 7}),
    ]
    user = await _seed(db_session, doses, checkins)

    results = await dose_day_energy_dip_rule(db_session, user.id, START, END)

    rows = json.loads(results[0].supporting_data)
    assert rows[2]["value"] == "3"


def test_registered_in_default_rules_after_adherence_consistency():
    adherence_index = DEFAULT_RULES.index(adherence_consistency_rule)
    assert DEFAULT_RULES[adherence_index + 1] is dose_day_energy_dip_rule
