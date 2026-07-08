import pytest
from datetime import date, timedelta
from app.services.protocol import ProtocolService
from app.services.user import UserService


class TestProtocolService:
    """Unit tests for ProtocolService."""

    @pytest.fixture
    async def user(self, db_session):
        """Create a test user for protocol tests."""
        user_service = UserService(db_session)
        return await user_service.create(
            email="protocol_test@example.com",
            password="password123",
        )

    @pytest.fixture
    def service(self, db_session):
        return ProtocolService(db_session)

    @pytest.fixture
    def sample_compounds(self):
        return [
            {
                "name": "Retatrutide",
                "dose_mg": 2.0,
                "frequency": "weekly",
            }
        ]

    async def test_create_protocol(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Test Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        assert protocol is not None
        assert protocol.name == "Test Protocol"
        assert protocol.is_active is True
        assert len(protocol.compounds) == 1
        assert protocol.compounds[0].name == "Retatrutide"

    async def test_create_protocol_with_multiple_compounds(self, service, user):
        compounds = [
            {"name": "Semaglutide", "dose_mg": 0.5, "frequency": "weekly"},
            {"name": "BPC-157", "dose_mg": 250, "dose_unit": "mcg", "frequency": "daily"},
        ]

        protocol = await service.create(
            user_id=user.id,
            name="Stack Protocol",
            start_date=date.today(),
            compounds=compounds,
        )

        assert len(protocol.compounds) == 2
        compound_names = {c.name for c in protocol.compounds}
        assert compound_names == {"Semaglutide", "BPC-157"}

    async def test_create_protocol_with_all_fields(self, service, user):
        compounds = [
            {
                "name": "Tirzepatide",
                "dose_mg": 5.0,
                "dose_unit": "mg",
                "frequency": "weekly",
                "administration_route": "subcutaneous",
                "notes": "Inject in abdomen",
            }
        ]

        protocol = await service.create(
            user_id=user.id,
            name="Full Protocol",
            start_date=date.today(),
            end_date=date.today() + timedelta(days=90),
            compounds=compounds,
            notes="12-week titration plan",
        )

        assert protocol.end_date == date.today() + timedelta(days=90)
        assert protocol.notes == "12-week titration plan"
        assert protocol.compounds[0].notes == "Inject in abdomen"

    async def test_create_pending_starter_protocol_from_peptides(self, service, user):
        protocol = await service.create_pending_starter(
            user_id=user.id,
            peptide_names=["Retatrutide", "BPC-157"],
            goals=["track_protocols"],
        )

        assert protocol.setup_status == "pending_setup"
        assert protocol.is_active is False
        assert protocol.name == "Starter protocol"
        assert [compound.name for compound in protocol.compounds] == ["Retatrutide", "BPC-157"]
        assert all(compound.dose_mg == 0 for compound in protocol.compounds)

    async def test_activate_pending_protocol_requires_complete_compounds(self, service, user):
        protocol = await service.create_pending_starter(
            user_id=user.id,
            peptide_names=["Retatrutide"],
            goals=[],
        )

        with pytest.raises(ValueError, match="Dose, frequency, route, and start date are required"):
            await service.activate_pending_protocol(protocol)

    async def test_create_protocol_empty_compounds_raises(self, service, user):
        with pytest.raises(ValueError, match="at least one compound"):
            await service.create(
                user_id=user.id,
                name="Empty Protocol",
                start_date=date.today(),
                compounds=[],
            )

    async def test_create_protocol_invalid_dates_raises(self, service, user, sample_compounds):
        with pytest.raises(ValueError, match="End date cannot be before"):
            await service.create(
                user_id=user.id,
                name="Invalid Dates",
                start_date=date.today(),
                end_date=date.today() - timedelta(days=1),
                compounds=sample_compounds,
            )

    async def test_create_protocol_deactivates_existing(self, service, user, sample_compounds):
        first = await service.create(
            user_id=user.id,
            name="First Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        assert first.is_active is True

        second = await service.create(
            user_id=user.id,
            name="Second Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        assert second.is_active is True

        # Reload first protocol
        first_reloaded = await service.get_by_id(first.id, user.id)
        assert first_reloaded.is_active is False

    async def test_get_active_protocol(self, service, user, sample_compounds):
        await service.create(
            user_id=user.id,
            name="Active Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        active = await service.get_active(user.id)
        assert active is not None
        assert active.name == "Active Protocol"
        assert active.is_active is True

    async def test_get_active_protocol_none_exists(self, service, user):
        active = await service.get_active(user.id)
        assert active is None

    async def test_list_protocols(self, service, user, sample_compounds):
        await service.create(
            user_id=user.id,
            name="Protocol 1",
            start_date=date.today() - timedelta(days=30),
            compounds=sample_compounds,
        )
        await service.create(
            user_id=user.id,
            name="Protocol 2",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        protocols = await service.list_for_user(user.id)
        assert len(protocols) == 2
        # Should be ordered by start_date descending
        assert protocols[0].name == "Protocol 2"
        assert protocols[1].name == "Protocol 1"

    async def test_list_protocols_exclude_inactive(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Inactive Protocol",
            start_date=date.today() - timedelta(days=30),
            compounds=sample_compounds,
        )
        await service.deactivate(protocol)

        await service.create(
            user_id=user.id,
            name="Active Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        all_protocols = await service.list_for_user(user.id, include_inactive=True)
        active_only = await service.list_for_user(user.id, include_inactive=False)

        assert len(all_protocols) == 2
        assert len(active_only) == 1
        assert active_only[0].name == "Active Protocol"

    async def test_update_protocol_metadata(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Original Name",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        updated = await service.update(
            protocol,
            name="Updated Name",
            notes="Added some notes",
        )

        assert updated.name == "Updated Name"
        assert updated.notes == "Added some notes"

    async def test_update_protocol_reactivate(self, service, user, sample_compounds):
        first = await service.create(
            user_id=user.id,
            name="First",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        second = await service.create(
            user_id=user.id,
            name="Second",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        # First should be inactive now
        first_reloaded = await service.get_by_id(first.id, user.id)
        assert first_reloaded.is_active is False

        # Reactivate first
        await service.update(first_reloaded, is_active=True)

        # Now second should be inactive
        second_reloaded = await service.get_by_id(second.id, user.id)
        assert second_reloaded.is_active is False
        first_reloaded = await service.get_by_id(first.id, user.id)
        assert first_reloaded.is_active is True

    async def test_update_compounds_replace_all(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        original_compound_id = protocol.compounds[0].id

        new_compounds = [
            {"name": "Tirzepatide", "dose_mg": 5.0, "frequency": "weekly"},
            {"name": "TB-500", "dose_mg": 2.5, "frequency": "twice_weekly"},
        ]
        updated = await service.update_compounds(protocol, new_compounds)

        assert len(updated.compounds) == 2
        # Original compound should be gone
        assert all(c.id != original_compound_id for c in updated.compounds)
        assert {c.name for c in updated.compounds} == {"Tirzepatide", "TB-500"}

    async def test_add_compound(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        assert len(protocol.compounds) == 1

        new_compound = await service.add_compound(
            protocol,
            name="BPC-157",
            dose_mg=250,
            frequency="daily",
            dose_unit="mcg",
        )

        assert new_compound.name == "BPC-157"
        assert new_compound.dose_unit == "mcg"

        # Reload protocol
        reloaded = await service.get_by_id(protocol.id, user.id)
        assert len(reloaded.compounds) == 2

    async def test_update_single_compound(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        compound = protocol.compounds[0]
        assert compound.dose_mg == 2.0

        updated = await service.update_compound(compound, dose_mg=4.0)
        assert updated.dose_mg == 4.0
        assert updated.name == "Retatrutide"  # unchanged

    async def test_remove_compound(self, service, user):
        compounds = [
            {"name": "Semaglutide", "dose_mg": 0.5, "frequency": "weekly"},
            {"name": "BPC-157", "dose_mg": 250, "frequency": "daily"},
        ]
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=compounds,
        )

        compound_to_remove = next(c for c in protocol.compounds if c.name == "BPC-157")
        await service.remove_compound(compound_to_remove, protocol)

        reloaded = await service.get_by_id(protocol.id, user.id)
        assert len(reloaded.compounds) == 1
        assert reloaded.compounds[0].name == "Semaglutide"

    async def test_deactivate_protocol(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        assert protocol.is_active is True
        assert protocol.end_date is None

        deactivated = await service.deactivate(protocol)
        assert deactivated.is_active is False
        assert deactivated.end_date == date.today()

    async def test_deactivate_preserves_existing_end_date(self, service, user, sample_compounds):
        future_date = date.today() + timedelta(days=30)
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            end_date=future_date,
            compounds=sample_compounds,
        )

        deactivated = await service.deactivate(protocol)
        assert deactivated.end_date == future_date

    async def test_delete_protocol(self, service, user, sample_compounds):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        protocol_id = protocol.id

        await service.delete(protocol)

        deleted = await service.get_by_id(protocol_id, user.id)
        assert deleted is None

    async def test_get_by_id_wrong_user(self, service, user, sample_compounds, db_session):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )

        # Create another user
        other_user_service = UserService(db_session)
        other_user = await other_user_service.create(
            email="other@example.com",
            password="password123",
        )

        # Other user shouldn't see this protocol
        result = await service.get_by_id(protocol.id, other_user.id)
        assert result is None

    async def test_get_compound_wrong_user(self, service, user, sample_compounds, db_session):
        protocol = await service.create(
            user_id=user.id,
            name="Protocol",
            start_date=date.today(),
            compounds=sample_compounds,
        )
        compound_id = protocol.compounds[0].id

        other_user_service = UserService(db_session)
        other_user = await other_user_service.create(
            email="other2@example.com",
            password="password123",
        )

        result = await service.get_compound(compound_id, other_user.id)
        assert result is None
