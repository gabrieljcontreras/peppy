import json
from datetime import date, datetime, timedelta, timezone

import pytest

from app.ml import adherence
from app.ml.adherence import doses_per_day, expected_doses
from app.ml.rules import DEFAULT_RULES
from app.ml.rules.adherence_consistency import adherence_consistency_rule
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol
from app.models.user import User

START = date(2026, 6, 1)
END = date(2026, 6, 30)


async def _seed_compound(db, protocol, *, name="Retatrutide", frequency="weekly"):
    compound = Compound(
        protocol_id=protocol.id,
        name=name,
        dose_mg=4,
        dose_unit="mg",
        frequency=frequency,
        administration_route="subcutaneous",
    )
    db.add(compound)
    await db.flush()
    return compound


async def _seed_protocol(
    db,
    user,
    *,
    frequency="weekly",
    start_date=END,
    end_date=None,
    is_active=True,
):
    protocol = Protocol(
        user_id=user.id,
        name="Test",
        start_date=start_date,
        end_date=end_date,
        is_active=is_active,
    )
    db.add(protocol)
    await db.flush()
    compound = await _seed_compound(db, protocol, frequency=frequency)
    return protocol, compound


def _seed_dose(db, user, protocol, compound, administered_at):
    if isinstance(administered_at, date) and not isinstance(administered_at, datetime):
        administered_at = datetime(
            administered_at.year,
            administered_at.month,
            administered_at.day,
            9,
            tzinfo=timezone.utc,
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


async def _seed(
    db,
    *,
    email,
    protocol_frequency=None,
    protocol_start=END - timedelta(days=60),
    protocol_active=True,
    doses=(),
    checkins=(),
):
    user = User(email=email, hashed_password="x")
    db.add(user)
    await db.flush()

    protocol = compound = None
    if protocol_frequency is not None:
        protocol, compound = await _seed_protocol(
            db,
            user,
            frequency=protocol_frequency,
            start_date=protocol_start,
            is_active=protocol_active,
        )

    for administered_at in doses:
        _seed_dose(db, user, protocol, compound, administered_at)

    for checkin_date in checkins:
        db.add(Checkin(user_id=user.id, date=checkin_date))

    await db.commit()
    return user, protocol


@pytest.mark.parametrize(
    ("frequency", "rate"),
    [
        ("daily", 1.0),
        ("every other day", 0.5),
        ("every-other-day", 0.5),
        ("Twice weekly", 2 / 7),
        ("twice_weekly", 2 / 7),
        ("weekly", 1 / 7),
        ("every 10 days", 0.1),
        ("biweekly", 1 / 14),
        ("monthly", 1 / 30),
    ],
)
def test_doses_per_day_maps_normalized_frequency(frequency, rate):
    assert doses_per_day(frequency) == pytest.approx(rate)


def test_doses_per_day_returns_none_for_unknown_frequency():
    assert doses_per_day("as needed") is None


@pytest.mark.asyncio
async def test_expected_doses_sums_mappable_active_protocol_compounds(db_session):
    user, _ = await _seed(
        db_session,
        email="expected@test.com",
        protocol_frequency="weekly",
    )
    await _seed_protocol(db_session, user, frequency="unknown")
    await db_session.commit()

    result = await expected_doses(db_session, user.id, END - timedelta(days=13), END)

    assert result == pytest.approx(2.0)


@pytest.mark.asyncio
async def test_expected_doses_returns_none_without_mappable_active_compound(db_session):
    user, _ = await _seed(
        db_session,
        email="unmapped@test.com",
        protocol_frequency="unknown",
    )

    assert await expected_doses(db_session, user.id, START, END) is None


@pytest.mark.asyncio
async def test_expected_doses_returns_none_without_active_protocol(db_session):
    user, _ = await _seed(
        db_session,
        email="inactive@test.com",
        protocol_frequency="weekly",
        protocol_active=False,
    )

    assert await expected_doses(db_session, user.id, START, END) is None


@pytest.mark.asyncio
async def test_streak_milestone_fires_with_seven_consecutive_checkin_days(db_session):
    streak_start = END - timedelta(days=6)
    user, _ = await _seed(
        db_session,
        email="streak7@test.com",
        checkins=[streak_start + timedelta(days=offset) for offset in range(7)],
    )

    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "milestone"
    assert insight.severity.value == "info"
    assert insight.title == "7-day check-in streak"
    assert json.loads(insight.source_data_refs) == {
        "rule": "checkin_streak_7",
        "start": streak_start.isoformat(),
    }
    assert insight.supporting_data is not None


@pytest.mark.asyncio
async def test_streak_milestone_is_silent_with_only_six_days(db_session):
    user, _ = await _seed(
        db_session,
        email="streak6@test.com",
        checkins=[END - timedelta(days=offset) for offset in range(6)],
    )

    assert await adherence_consistency_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_protocol_anniversary_milestone_fires_at_four_weeks(db_session):
    protocol_start = END - timedelta(days=28)
    user, protocol = await _seed(
        db_session,
        email="milestone@test.com",
        protocol_frequency="unknown",
        protocol_start=protocol_start,
    )

    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "milestone"
    assert insight.severity.value == "info"
    assert insight.title == "4 weeks on Test"
    assert json.loads(insight.source_data_refs) == {
        "rule": "protocol_weeks_4",
        "protocol": str(protocol.id),
    }
    assert insight.supporting_data is not None


@pytest.mark.asyncio
async def test_low_adherence_suggestion_fires_with_no_weekly_doses(db_session):
    user, _ = await _seed(
        db_session,
        email="low@test.com",
        protocol_frequency="weekly",
    )

    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "suggestion"
    assert insight.severity.value == "info"
    assert insight.title == "Doses are slipping"
    assert json.loads(insight.source_data_refs) == {
        "rule": "adherence_low",
        "window_end": END.isoformat(),
    }
    assert insight.supporting_data is not None


@pytest.mark.asyncio
async def test_low_adherence_suggestion_is_silent_with_two_weekly_doses(db_session):
    user, _ = await _seed(
        db_session,
        email="adherent@test.com",
        protocol_frequency="weekly",
        doses=[END - timedelta(days=7), END],
    )

    assert await adherence_consistency_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_two_compounds_on_same_dates_count_as_separate_events_without_duplicates(
    db_session,
):
    user = User(email="two-compounds@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    protocol, first = await _seed_protocol(
        db_session,
        user,
        frequency="weekly",
        start_date=END - timedelta(days=60),
    )
    second = await _seed_compound(
        db_session,
        protocol,
        name="Cagrilintide",
        frequency="weekly",
    )
    for dose_date in (END - timedelta(days=7), END):
        _seed_dose(db_session, user, protocol, first, dose_date)
        _seed_dose(db_session, user, protocol, second, dose_date)
    _seed_dose(db_session, user, protocol, first, END)
    await db_session.commit()

    expected = await expected_doses(db_session, user.id, END - timedelta(days=13), END)
    logged = await adherence.logged_dose_events(
        db_session,
        user.id,
        END - timedelta(days=13),
        END,
    )
    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert expected == pytest.approx(4.0)
    assert logged == 4
    assert all(insight.title != "Doses are slipping" for insight in results)


@pytest.mark.asyncio
async def test_inactive_and_unmappable_compound_logs_cannot_inflate_adherence(db_session):
    user = User(email="unrelated-logs@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    active_protocol, _ = await _seed_protocol(
        db_session,
        user,
        frequency="weekly",
        start_date=END - timedelta(days=60),
    )
    unmappable = await _seed_compound(
        db_session,
        active_protocol,
        name="As-needed compound",
        frequency="as needed",
    )
    inactive_protocol, inactive_compound = await _seed_protocol(
        db_session,
        user,
        frequency="weekly",
        start_date=END - timedelta(days=60),
        is_active=False,
    )
    for dose_date in (END - timedelta(days=7), END):
        _seed_dose(db_session, user, inactive_protocol, inactive_compound, dose_date)
    for dose_date in (END - timedelta(days=6), END - timedelta(days=1)):
        _seed_dose(db_session, user, active_protocol, unmappable, dose_date)
    await db_session.commit()

    logged = await adherence.logged_dose_events(
        db_session,
        user.id,
        END - timedelta(days=13),
        END,
    )
    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert logged == 0
    assert [insight.title for insight in results] == ["Doses are slipping"]


@pytest.mark.asyncio
async def test_expected_doses_clips_to_protocol_start_and_end_dates(db_session):
    protocol_start = END - timedelta(days=9)
    protocol_end = END - timedelta(days=3)
    user = User(email="protocol-overlap@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    await _seed_protocol(
        db_session,
        user,
        frequency="weekly",
        start_date=protocol_start,
        end_date=protocol_end,
    )
    await db_session.commit()

    expected = await expected_doses(db_session, user.id, END - timedelta(days=13), END)
    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert expected == pytest.approx(1.0)
    assert results == []


@pytest.mark.asyncio
async def test_dose_at_midnight_after_end_date_is_excluded(db_session):
    user = User(email="midnight-boundary@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    protocol, compound = await _seed_protocol(
        db_session,
        user,
        frequency="weekly",
        start_date=END - timedelta(days=60),
    )
    _seed_dose(db_session, user, protocol, compound, END - timedelta(days=7))
    _seed_dose(
        db_session,
        user,
        protocol,
        compound,
        datetime(2026, 7, 1, 0, 0, tzinfo=timezone.utc),
    )
    await db_session.commit()

    logged = await adherence.logged_dose_events(
        db_session,
        user.id,
        END - timedelta(days=13),
        END,
    )
    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert logged == 1
    assert [insight.title for insight in results] == ["Doses are slipping"]


@pytest.mark.asyncio
async def test_all_emitted_insights_have_supporting_data_and_exact_dedup_refs(db_session):
    streak_start = END - timedelta(days=6)
    protocol_start = END - timedelta(days=28)
    user, protocol = await _seed(
        db_session,
        email="all@test.com",
        protocol_frequency="weekly",
        protocol_start=protocol_start,
        checkins=[streak_start + timedelta(days=offset) for offset in range(7)],
    )

    results = await adherence_consistency_rule(db_session, user.id, START, END)

    assert len(results) == 3
    refs_by_rule = {
        json.loads(insight.source_data_refs)["rule"]: json.loads(insight.source_data_refs)
        for insight in results
    }
    assert refs_by_rule == {
        "checkin_streak_7": {
            "rule": "checkin_streak_7",
            "start": streak_start.isoformat(),
        },
        "protocol_weeks_4": {
            "rule": "protocol_weeks_4",
            "protocol": str(protocol.id),
        },
        "adherence_low": {
            "rule": "adherence_low",
            "window_end": END.isoformat(),
        },
    }
    assert all(insight.supporting_data is not None for insight in results)


def test_registered_in_default_rules_after_symptom_after_dose():
    from app.ml.rules.symptom_after_dose import symptom_after_dose_rule

    symptom_index = DEFAULT_RULES.index(symptom_after_dose_rule)
    assert DEFAULT_RULES[symptom_index + 1] is adherence_consistency_rule
