from datetime import date, datetime, timedelta, timezone

import pytest

from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.lab import LabResult
from app.models.wearable import WearableConnection, WearableProvider
from app.services.checkin import CheckinService
from app.services.dashboard import DashboardService
from app.services.protocol import ProtocolService
from app.services.user import UserService


@pytest.fixture
async def user(db_session):
    return await UserService(db_session).create(
        email="dashboard@example.com",
        password="password123",
    )


async def test_dashboard_summary_reports_pending_starter(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["status"] == "pending_setup"
    assert summary["protocol"]["title"] == "Starter protocol"
    assert summary["protocol"]["compounds"] == ["Retatrutide"]


async def test_dashboard_summary_without_protocol_prompts_creation(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["id"] is None
    assert summary["protocol"]["status"] == "missing"
    assert summary["protocol"]["title"] == "Create your protocol"
    assert summary["protocol"]["compounds"] == []


async def test_dashboard_summary_includes_protocol_start_date(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["start_date"] == date.today()


async def test_dashboard_summary_start_date_is_none_without_protocol(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["start_date"] is None


async def test_dashboard_summary_includes_today_and_weight_trend(db_session, user):
    checkins = CheckinService(db_session)
    await checkins.create(user.id, date.today() - timedelta(days=2), weight_kg=75.2, energy_level=6)
    await checkins.create(user.id, date.today(), weight_kg=74.8, energy_level=7, mood=8)

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["today_checkin"]["logged"] is True
    assert summary["response_snapshot"]["weight_trend"][-1]["weight_kg"] == 74.8
    assert summary["response_snapshot"]["latest_energy"] == 7


async def test_dashboard_summary_includes_insight_confidence(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    db_session.add(
        Insight(
            user_id=user.id,
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Your weight trend is accelerating",
            description="Your rate of loss increased over the past 7 days.",
            explanation="Computed from your last 10 check-ins.",
            confidence=0.82,
        )
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["insight"]["confidence"] == 0.82


async def test_dashboard_summary_confidence_is_none_for_empty_insight_state(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["insight"]["confidence"] is None


async def test_dashboard_summary_recent_activity_merges_all_event_types(db_session, user):
    protocol = await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    compound = protocol.compounds[0]
    now = datetime.now(timezone.utc)

    # Every timestamp is set explicitly (including `created_at`, which
    # overrides the model's server_default) so the expected descending order
    # below is deterministic rather than depending on real wall-clock
    # ordering between separate flush calls.
    checkin = Checkin(
        user_id=user.id,
        date=date.today(),
        weight_kg=74.8,
        energy_level=7,
        mood=8,
        created_at=now - timedelta(hours=2),
    )
    db_session.add_all(
        [
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4.0,
                unit="mg",
                administered_at=now - timedelta(hours=1),
                route="subcutaneous",
            ),
            checkin,
            WearableConnection(
                user_id=user.id,
                provider=WearableProvider.OURA,
                access_token="test-token",
                last_sync_at=now - timedelta(hours=3),
            ),
            LabResult(
                user_id=user.id,
                date=date.today() - timedelta(days=2),
                panel_type="metabolic",
                lab_name="Comprehensive Metabolic Panel",
                created_at=now - timedelta(hours=4),
            ),
        ]
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)
    activity = summary["recent_activity"]

    assert [item["type"] for item in activity] == [
        "dose_logged",
        "checkin_completed",
        "wearable_synced",
        "lab_added",
    ]
    assert activity[0]["title"] == "Dose logged"
    assert activity[0]["subtitle"] == "Retatrutide • 4 mg"
    assert activity[0]["protocol_id"] == protocol.id
    assert activity[1]["subtitle"] == "Energy, mood, weight"
    assert activity[1]["checkin_id"] == checkin.id
    assert activity[2]["subtitle"] == "Oura"
    assert activity[3]["subtitle"] == "Comprehensive Metabolic Panel"


async def test_dashboard_summary_recent_activity_empty_when_no_events(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["recent_activity"] == []


async def test_dashboard_summary_recent_activity_caps_at_five_most_recent(db_session, user):
    protocol = await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    compound = protocol.compounds[0]
    now = datetime.now(timezone.utc)
    db_session.add_all(
        [
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4.0,
                unit="mg",
                administered_at=now - timedelta(hours=offset),
                route="subcutaneous",
            )
            for offset in range(1, 8)
        ]
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert len(summary["recent_activity"]) == 5
    assert summary["recent_activity"][0]["timestamp"] == now - timedelta(hours=1)
