from datetime import date, datetime, timedelta, timezone

import pytest
from sqlalchemy import func, select, text

from app.models.dose_log import DoseLog
from app.services.dose_log import DoseLogService
from app.services.protocol import ProtocolService
from app.services.user import UserService


class TestDoseLogService:
    @pytest.fixture
    async def user(self, db_session):
        user_service = UserService(db_session)
        return await user_service.create(
            email="dose-log-service@example.com",
            password="password123",
        )

    @pytest.fixture
    async def other_user(self, db_session):
        user_service = UserService(db_session)
        return await user_service.create(
            email="dose-log-service-other@example.com",
            password="password123",
        )

    @pytest.fixture
    async def protocol(self, db_session, user):
        return await ProtocolService(db_session).create(
            user_id=user.id,
            name="Dose Log Protocol",
            start_date=date.today(),
            compounds=[
                {
                    "name": "Retatrutide",
                    "dose_mg": 2.0,
                    "frequency": "weekly",
                }
            ],
        )

    @pytest.fixture
    async def other_protocol(self, db_session, other_user):
        return await ProtocolService(db_session).create(
            user_id=other_user.id,
            name="Other Dose Log Protocol",
            start_date=date.today(),
            compounds=[
                {
                    "name": "Tirzepatide",
                    "dose_mg": 5.0,
                    "frequency": "weekly",
                }
            ],
        )

    @pytest.fixture
    def service(self, db_session):
        return DoseLogService(db_session)

    async def test_test_harness_enables_sqlite_foreign_keys(self, db_session):
        foreign_keys_enabled = await db_session.scalar(text("PRAGMA foreign_keys"))
        assert foreign_keys_enabled == 1

    async def test_create_dose_log(self, service, user, protocol):
        compound = protocol.compounds[0]
        administered_at = datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc)

        result = await service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=2.5,
            unit="mg",
            administered_at=administered_at,
            route="subcutaneous",
            notes="Left abdomen",
        )

        assert result.user_id == user.id
        assert result.protocol_id == protocol.id
        assert result.compound_id == compound.id
        assert result.dose == 2.5
        assert result.unit == "mg"
        assert result.administered_at == administered_at
        assert result.route == "subcutaneous"
        assert result.notes == "Left abdomen"

    async def test_list_for_protocol_orders_newest_first(self, service, user, protocol):
        compound = protocol.compounds[0]
        older = datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc)
        newer = older + timedelta(hours=8)

        first = await service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=2.0,
            unit="mg",
            administered_at=older,
            route="subcutaneous",
            notes=None,
        )
        second = await service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=3.0,
            unit="mg",
            administered_at=newer,
            route="subcutaneous",
            notes="Evening dose",
        )

        logs = await service.list_for_protocol(
            user_id=user.id,
            protocol_id=protocol.id,
        )

        assert [log.id for log in logs] == [second.id, first.id]

    async def test_create_dose_log_rejects_other_users_compound(
        self,
        service,
        user,
        protocol,
        other_protocol,
    ):
        with pytest.raises(ValueError, match="Compound not found"):
            await service.create(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=other_protocol.compounds[0].id,
                dose=2.5,
                unit="mg",
                administered_at=datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc),
                route="subcutaneous",
                notes=None,
            )

    async def test_create_dose_log_rejects_non_positive_dose(self, service, user, protocol):
        compound = protocol.compounds[0]

        with pytest.raises(ValueError, match="Dose must be greater than 0"):
            await service.create(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=0,
                unit="mg",
                administered_at=datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc),
                route="subcutaneous",
                notes=None,
            )

    async def test_create_dose_log_rejects_naive_administered_at(self, service, user, protocol):
        compound = protocol.compounds[0]

        with pytest.raises(ValueError, match="administered_at must include a timezone offset"):
            await service.create(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=2.5,
                unit="mg",
                administered_at=datetime(2026, 7, 8, 14, 30),
                route="subcutaneous",
                notes=None,
            )

    async def test_create_dose_log_normalizes_offset_aware_value_to_utc(self, service, user, protocol):
        compound = protocol.compounds[0]
        source_time = datetime(2026, 7, 8, 10, 30, tzinfo=timezone(timedelta(hours=-4)))

        result = await service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=2.5,
            unit="mg",
            administered_at=source_time,
            route="subcutaneous",
            notes=None,
        )

        expected = datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc)
        assert result.administered_at == expected

        logs = await service.list_for_protocol(user_id=user.id, protocol_id=protocol.id)
        assert logs[0].administered_at == expected

    async def test_delete_protocol_cascades_dose_logs(self, db_session, service, user, protocol):
        compound = protocol.compounds[0]
        await service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=2.5,
            unit="mg",
            administered_at=datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc),
            route="subcutaneous",
            notes=None,
        )

        protocol_service = ProtocolService(db_session)
        await protocol_service.delete(protocol)

        remaining_logs = await db_session.scalar(select(func.count()).select_from(DoseLog))
        reloaded_protocol = await protocol_service.get_by_id(protocol.id, user.id)

        assert remaining_logs == 0
        assert reloaded_protocol is None

    async def test_remove_compound_cascades_its_dose_logs_and_preserves_remaining_protocol_data(
        self,
        db_session,
        user,
    ):
        protocol_service = ProtocolService(db_session)
        dose_log_service = DoseLogService(db_session)
        protocol = await protocol_service.create(
            user_id=user.id,
            name="Compound Cascade Protocol",
            start_date=date.today(),
            compounds=[
                {"name": "Semaglutide", "dose_mg": 0.5, "frequency": "weekly"},
                {"name": "BPC-157", "dose_mg": 250, "frequency": "daily"},
            ],
        )
        kept_compound = next(c for c in protocol.compounds if c.name == "Semaglutide")
        removed_compound = next(c for c in protocol.compounds if c.name == "BPC-157")

        kept_log = await dose_log_service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=kept_compound.id,
            dose=0.5,
            unit="mg",
            administered_at=datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc),
            route="subcutaneous",
            notes=None,
        )
        removed_log = await dose_log_service.create(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=removed_compound.id,
            dose=250,
            unit="mcg",
            administered_at=datetime(2026, 7, 9, 14, 30, tzinfo=timezone.utc),
            route="subcutaneous",
            notes=None,
        )

        await protocol_service.remove_compound(removed_compound, protocol)

        remaining_protocol = await protocol_service.get_by_id(protocol.id, user.id)
        remaining_logs = await dose_log_service.list_for_protocol(user.id, protocol.id)
        removed_log_count = await db_session.scalar(
            select(func.count()).select_from(DoseLog).where(DoseLog.id == removed_log.id)
        )
        kept_log_count = await db_session.scalar(
            select(func.count()).select_from(DoseLog).where(DoseLog.id == kept_log.id)
        )

        assert remaining_protocol is not None
        assert [compound.name for compound in remaining_protocol.compounds] == ["Semaglutide"]
        assert [log.id for log in remaining_logs] == [kept_log.id]
        assert removed_log_count == 0
        assert kept_log_count == 1
