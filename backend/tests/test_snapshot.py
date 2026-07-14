import json
from datetime import date, datetime, timezone

import pytest

from app.ml.snapshot import build_longitudinal_snapshot
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.lab import LabMarker, LabResult
from app.models.profile import OnboardingProfile
from app.models.protocol import Compound, Protocol
from app.models.user import User


@pytest.mark.asyncio
async def test_empty_snapshot_is_json_serializable_and_null_safe(db_session):
    user = User(
        email="empty-snapshot@test.com",
        hashed_password="x",
        display_name="Snapshot Secret",
    )
    db_session.add(user)
    await db_session.commit()

    snapshot = await build_longitudinal_snapshot(
        db_session,
        user.id,
        date(2026, 6, 1),
        date(2026, 6, 30),
    )

    assert snapshot == {
        "window": {"start": "2026-06-01", "end": "2026-06-30"},
        "profile": {},
        "protocol": None,
        "checkins": [],
        "doses": [],
        "labs": [],
        "aggregates": {
            "checkin_count": 0,
            "dose_count": 0,
            "weight_first": None,
            "weight_last": None,
            "avg_energy": None,
            "avg_mood": None,
            "avg_sleep_quality": None,
        },
    }
    serialized = json.dumps(snapshot)
    assert "empty-snapshot@test.com" not in serialized
    assert "Snapshot Secret" not in serialized


@pytest.mark.asyncio
async def test_snapshot_organizes_full_window_and_excludes_account_identity(db_session):
    user = User(
        email="svc@test.com",
        hashed_password="x",
        display_name="Private Display Name",
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(
        OnboardingProfile(
            user_id=user.id,
            age=32,
            height_cm=170,
            preferred_height_unit="cm",
            weight_kg=85,
            preferred_weight_unit="kg",
            peptides=["Retatrutide"],
            custom_peptides=["Custom peptide"],
            other_medications="Vitamin D",
            workout_days_per_week=3,
            goals=["Weight loss"],
            custom_goal="Improve recovery",
        )
    )
    protocol = Protocol(
        user_id=user.id,
        name="Current protocol",
        start_date=date(2026, 5, 15),
        is_active=True,
        notes="Titrate slowly",
    )
    db_session.add(protocol)
    await db_session.flush()
    compound = Compound(
        protocol_id=protocol.id,
        name="Retatrutide",
        dose_mg=4,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
        notes="Sunday mornings",
    )
    db_session.add(compound)
    db_session.add(
        Protocol(
            user_id=user.id,
            name="Inactive protocol",
            start_date=date(2025, 1, 1),
            is_active=False,
        )
    )
    await db_session.flush()

    db_session.add_all(
        [
            Checkin(
                user_id=user.id,
                date=date(2026, 6, 3),
                weight_kg=83,
                energy_level=8,
                sleep_quality=7,
                appetite_level=6,
                nausea=4,
                fatigue=0,
                notes="Felt queasy after dose",
            ),
            Checkin(
                user_id=user.id,
                date=date(2026, 6, 1),
                weight_kg=85,
                energy_level=4,
                sleep_quality=6,
                mood=5,
            ),
            Checkin(
                user_id=user.id,
                date=date(2026, 6, 2),
                mood=7,
                headache=2,
            ),
            Checkin(
                user_id=user.id,
                date=date(2026, 5, 31),
                weight_kg=99,
                energy_level=1,
            ),
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4,
                unit="mg",
                route="subcutaneous",
                administered_at=datetime(2026, 6, 20, 9, tzinfo=timezone.utc),
                notes="Right abdomen",
            ),
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=3,
                unit="mg",
                route="subcutaneous",
                administered_at=datetime(2026, 6, 2, 9, tzinfo=timezone.utc),
            ),
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=5,
                unit="mg",
                route="subcutaneous",
                administered_at=datetime(2026, 7, 1, 0, tzinfo=timezone.utc),
            ),
        ]
    )
    lab = LabResult(
        user_id=user.id,
        date=date(2026, 6, 10),
        panel_type="metabolic",
        lab_name="Neighborhood Lab",
        notes="Fasting draw",
    )
    lab.markers.extend(
        [
            LabMarker(
                name="Glucose",
                value=91,
                unit="mg/dL",
                reference_low=70,
                reference_high=99,
            ),
            LabMarker(name="ALT", value=18, unit="U/L", reference_high=44),
        ]
    )
    db_session.add(lab)
    await db_session.commit()

    snapshot = await build_longitudinal_snapshot(
        db_session,
        user.id,
        date(2026, 6, 1),
        date(2026, 6, 30),
    )

    assert snapshot["profile"] == {
        "age": 32,
        "height_cm": 170.0,
        "preferred_height_unit": "cm",
        "weight_kg": 85.0,
        "preferred_weight_unit": "kg",
        "peptides": ["Retatrutide"],
        "custom_peptides": ["Custom peptide"],
        "other_medications": "Vitamin D",
        "workout_days_per_week": 3,
        "goals": ["Weight loss"],
        "custom_goal": "Improve recovery",
    }
    assert snapshot["protocol"] == {
        "name": "Current protocol",
        "started": "2026-05-15",
        "notes": "Titrate slowly",
        "compounds": [
            {
                "name": "Retatrutide",
                "dose": 4.0,
                "unit": "mg",
                "frequency": "weekly",
                "route": "subcutaneous",
                "notes": "Sunday mornings",
            }
        ],
    }
    assert [item["date"] for item in snapshot["checkins"]] == [
        "2026-06-01",
        "2026-06-02",
        "2026-06-03",
    ]
    assert snapshot["checkins"][0] == {
        "date": "2026-06-01",
        "weight_kg": 85.0,
        "energy": 4,
        "mood": 5,
        "sleep_quality": 6,
        "appetite": None,
        "symptoms": {},
        "notes": None,
    }
    assert snapshot["checkins"][1]["symptoms"] == {"headache": 2}
    assert snapshot["checkins"][2]["symptoms"] == {"nausea": 4}
    assert snapshot["checkins"][2]["notes"] == "Felt queasy after dose"
    assert snapshot["doses"] == [
        {
            "date": "2026-06-02",
            "compound": "Retatrutide",
            "dose": 3.0,
            "unit": "mg",
            "route": "subcutaneous",
            "notes": None,
        },
        {
            "date": "2026-06-20",
            "compound": "Retatrutide",
            "dose": 4.0,
            "unit": "mg",
            "route": "subcutaneous",
            "notes": "Right abdomen",
        },
    ]
    assert snapshot["labs"] == [
        {
            "date": "2026-06-10",
            "panel": "metabolic",
            "lab_name": "Neighborhood Lab",
            "notes": "Fasting draw",
            "markers": [
                {
                    "name": "ALT",
                    "value": 18.0,
                    "unit": "U/L",
                    "reference_low": None,
                    "reference_high": 44.0,
                },
                {
                    "name": "Glucose",
                    "value": 91.0,
                    "unit": "mg/dL",
                    "reference_low": 70.0,
                    "reference_high": 99.0,
                },
            ],
        }
    ]
    assert snapshot["aggregates"] == {
        "checkin_count": 3,
        "dose_count": 2,
        "weight_first": 85.0,
        "weight_last": 83.0,
        "avg_energy": 6.0,
        "avg_mood": 6.0,
        "avg_sleep_quality": 6.5,
    }
    serialized = json.dumps(snapshot)
    assert "svc@test.com" not in serialized
    assert "Private Display Name" not in serialized
