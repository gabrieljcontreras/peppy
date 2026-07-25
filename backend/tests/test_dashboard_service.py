from datetime import date, timedelta

import pytest

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
