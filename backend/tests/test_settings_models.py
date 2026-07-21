from datetime import date, time

from sqlalchemy import select

from app.models.notification import (
    DevicePlatform,
    DoseReminderSetting,
    NotificationPreference,
)
from app.models.profile import OnboardingProfile
from app.models.user import User
from app.services.notification import NotificationService


async def test_settings_models_persist_defaults_and_profile_fields(db_session):
    user = User(email="settings-model@example.com", hashed_password="hash")
    db_session.add(user)
    await db_session.flush()
    profile = OnboardingProfile(
        user_id=user.id,
        baseline_date=date(2026, 7, 20),
        primary_goal="track_protocols",
        secondary_goal="build_habits",
        focus_area="understand_body",
    )
    preferences = NotificationPreference(
        user_id=user.id,
        dose_reminders_enabled=True,
        daily_checkin_reminders_enabled=True,
        daily_checkin_time=time(9, 0),
        detailed_previews_enabled=False,
    )
    db_session.add_all([profile, preferences])
    await db_session.commit()

    saved_user = await db_session.scalar(select(User).where(User.id == user.id))
    saved_profile = await db_session.scalar(
        select(OnboardingProfile).where(OnboardingProfile.user_id == user.id)
    )
    saved_preferences = await db_session.scalar(
        select(NotificationPreference).where(NotificationPreference.user_id == user.id)
    )
    assert saved_user.auth_version == 1
    assert saved_profile.baseline_date == date(2026, 7, 20)
    assert saved_preferences.daily_checkin_time == time(9, 0)
    assert saved_preferences.detailed_previews_enabled is False


async def test_dose_reminder_is_unique_per_user_and_compound(db_session):
    assert DoseReminderSetting.__table__.c.user_id.foreign_keys
    assert DoseReminderSetting.__table__.c.compound_id.foreign_keys
    names = {constraint.name for constraint in DoseReminderSetting.__table__.constraints}
    assert "uq_dose_reminder_user_compound" in names


async def test_register_device_transfers_globally_unique_token_to_current_user(db_session):
    first_user = User(email="first-device-owner@example.com", hashed_password="hash")
    current_user = User(email="current-device-owner@example.com", hashed_password="hash")
    db_session.add_all([first_user, current_user])
    await db_session.flush()

    service = NotificationService(db_session)
    original = await service.register_device(first_user.id, "shared-token", DevicePlatform.IOS)
    transferred = await service.register_device(
        current_user.id,
        "shared-token",
        DevicePlatform.IOS,
    )

    assert transferred.id == original.id
    assert transferred.user_id == current_user.id
    assert await service.list_devices(first_user.id) == []
