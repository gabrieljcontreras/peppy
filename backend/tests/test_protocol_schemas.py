import pytest
from datetime import date, timedelta
from pydantic import ValidationError
from app.api.schemas.protocol import (
    CompoundCreate,
    CompoundUpdate,
    ProtocolCreate,
    ProtocolUpdate,
)


class TestCompoundSchemas:
    def test_compound_create_minimal(self):
        compound = CompoundCreate(
            name="Retatrutide",
            dose_mg=2.0,
            frequency="weekly",
        )
        assert compound.name == "Retatrutide"
        assert compound.dose_mg == 2.0
        assert compound.dose_unit == "mg"  # default
        assert compound.administration_route == "subcutaneous"  # default

    def test_compound_create_full(self):
        compound = CompoundCreate(
            name="Tirzepatide",
            dose_mg=5.0,
            dose_unit="mg",
            frequency="weekly",
            administration_route="subcutaneous",
            notes="Rotate injection sites",
        )
        assert compound.notes == "Rotate injection sites"

    def test_compound_create_invalid_dose(self):
        with pytest.raises(ValidationError):
            CompoundCreate(
                name="Test",
                dose_mg=0,  # Must be > 0
                frequency="daily",
            )

    def test_compound_create_invalid_dose_negative(self):
        with pytest.raises(ValidationError):
            CompoundCreate(
                name="Test",
                dose_mg=-5.0,
                frequency="daily",
            )

    def test_compound_create_empty_name(self):
        with pytest.raises(ValidationError):
            CompoundCreate(
                name="",
                dose_mg=1.0,
                frequency="daily",
            )

    def test_compound_update_partial(self):
        update = CompoundUpdate(dose_mg=4.0)
        assert update.dose_mg == 4.0
        assert update.name is None
        assert update.frequency is None


class TestProtocolSchemas:
    def test_protocol_create_minimal(self):
        protocol = ProtocolCreate(
            name="Test Protocol",
            start_date=date.today(),
            compounds=[
                CompoundCreate(name="Test", dose_mg=1.0, frequency="daily")
            ],
        )
        assert protocol.name == "Test Protocol"
        assert len(protocol.compounds) == 1

    def test_protocol_create_with_end_date(self):
        protocol = ProtocolCreate(
            name="Test Protocol",
            start_date=date.today(),
            end_date=date.today() + timedelta(days=90),
            compounds=[
                CompoundCreate(name="Test", dose_mg=1.0, frequency="daily")
            ],
        )
        assert protocol.end_date == date.today() + timedelta(days=90)

    def test_protocol_create_invalid_end_date(self):
        with pytest.raises(ValidationError) as exc_info:
            ProtocolCreate(
                name="Test Protocol",
                start_date=date.today(),
                end_date=date.today() - timedelta(days=1),
                compounds=[
                    CompoundCreate(name="Test", dose_mg=1.0, frequency="daily")
                ],
            )
        assert "End date must be after start date" in str(exc_info.value)

    def test_protocol_create_no_compounds(self):
        with pytest.raises(ValidationError):
            ProtocolCreate(
                name="Test Protocol",
                start_date=date.today(),
                compounds=[],
            )

    def test_protocol_create_multiple_compounds(self):
        protocol = ProtocolCreate(
            name="Stack Protocol",
            start_date=date.today(),
            compounds=[
                CompoundCreate(name="Semaglutide", dose_mg=0.5, frequency="weekly"),
                CompoundCreate(name="BPC-157", dose_mg=250, frequency="daily"),
            ],
        )
        assert len(protocol.compounds) == 2

    def test_protocol_update_partial(self):
        update = ProtocolUpdate(name="New Name")
        assert update.name == "New Name"
        assert update.start_date is None
        assert update.is_active is None

    def test_protocol_create_long_name(self):
        with pytest.raises(ValidationError):
            ProtocolCreate(
                name="A" * 201,  # Max 200
                start_date=date.today(),
                compounds=[
                    CompoundCreate(name="Test", dose_mg=1.0, frequency="daily")
                ],
            )

    def test_protocol_create_long_notes(self):
        with pytest.raises(ValidationError):
            ProtocolCreate(
                name="Test",
                start_date=date.today(),
                notes="A" * 2001,  # Max 2000
                compounds=[
                    CompoundCreate(name="Test", dose_mg=1.0, frequency="daily")
                ],
            )
