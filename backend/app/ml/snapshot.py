from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.lab import LabResult
from app.models.profile import OnboardingProfile
from app.models.protocol import Protocol

_PROFILE_FIELDS = (
    "age",
    "height_cm",
    "preferred_height_unit",
    "weight_kg",
    "preferred_weight_unit",
    "peptides",
    "custom_peptides",
    "other_medications",
    "workout_days_per_week",
    "goals",
    "custom_goal",
)
_SYMPTOM_FIELDS = (
    "nausea",
    "injection_site_reaction",
    "fatigue",
    "headache",
    "gi_issues",
)


def _mean(values: list[int]) -> Optional[float]:
    return sum(values) / len(values) if values else None


async def build_longitudinal_snapshot(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> dict:
    """Build a JSON-serializable, identity-free view of a user's health data."""
    profile_result = await db.execute(
        select(OnboardingProfile).where(OnboardingProfile.user_id == user_id)
    )
    profile_model = profile_result.scalar_one_or_none()
    profile = (
        {
            field: value
            for field in _PROFILE_FIELDS
            if (value := getattr(profile_model, field)) is not None
        }
        if profile_model is not None
        else {}
    )

    protocol_result = await db.execute(
        select(Protocol)
        .options(selectinload(Protocol.compounds))
        .where(and_(Protocol.user_id == user_id, Protocol.is_active.is_(True)))
        .order_by(Protocol.start_date.desc())
        .limit(1)
    )
    protocol_model = protocol_result.scalar_one_or_none()
    protocol = None
    if protocol_model is not None:
        protocol = {
            "name": protocol_model.name,
            "started": protocol_model.start_date.isoformat(),
            "compounds": [
                {
                    "name": compound.name,
                    "dose": compound.dose_mg,
                    "unit": compound.dose_unit,
                    "frequency": compound.frequency,
                    "route": compound.administration_route,
                    **({"notes": compound.notes} if compound.notes is not None else {}),
                }
                for compound in sorted(protocol_model.compounds, key=lambda item: item.name)
            ],
            **({"notes": protocol_model.notes} if protocol_model.notes is not None else {}),
        }

    checkin_result = await db.execute(
        select(Checkin)
        .where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
        .order_by(Checkin.date.asc())
    )
    checkin_models = list(checkin_result.scalars().all())
    checkins = [
        {
            "date": checkin.date.isoformat(),
            "weight_kg": checkin.weight_kg,
            "energy": checkin.energy_level,
            "mood": checkin.mood,
            "sleep_quality": checkin.sleep_quality,
            "appetite": checkin.appetite_level,
            "symptoms": {
                field: value
                for field in _SYMPTOM_FIELDS
                if (value := getattr(checkin, field)) not in (None, 0)
            },
            "notes": checkin.notes,
        }
        for checkin in checkin_models
    ]

    start_at = datetime.combine(start_date, time.min, tzinfo=timezone.utc)
    end_at = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
    dose_result = await db.execute(
        select(DoseLog)
        .options(selectinload(DoseLog.compound))
        .where(
            and_(
                DoseLog.user_id == user_id,
                DoseLog.administered_at >= start_at,
                DoseLog.administered_at < end_at,
            )
        )
        .order_by(DoseLog.administered_at.asc())
    )
    dose_models = list(dose_result.scalars().all())
    doses = [
        {
            "date": dose.administered_at.date().isoformat(),
            "compound": dose.compound.name,
            "dose": dose.dose,
            "unit": dose.unit,
            "route": dose.route,
            "notes": dose.notes,
        }
        for dose in dose_models
    ]

    lab_result = await db.execute(
        select(LabResult)
        .options(selectinload(LabResult.markers))
        .where(
            and_(
                LabResult.user_id == user_id,
                LabResult.date >= start_date,
                LabResult.date <= end_date,
            )
        )
        .order_by(LabResult.date.asc())
    )
    lab_models = list(lab_result.scalars().all())
    labs = [
        {
            "date": lab.date.isoformat(),
            "panel": lab.panel_type,
            "lab_name": lab.lab_name,
            "notes": lab.notes,
            "markers": [
                {
                    "name": marker.name,
                    "value": marker.value,
                    "unit": marker.unit,
                    "reference_low": marker.reference_low,
                    "reference_high": marker.reference_high,
                }
                for marker in sorted(lab.markers, key=lambda item: item.name)
            ],
        }
        for lab in lab_models
    ]

    weights = [checkin.weight_kg for checkin in checkin_models if checkin.weight_kg is not None]
    energies = [
        checkin.energy_level for checkin in checkin_models if checkin.energy_level is not None
    ]
    moods = [checkin.mood for checkin in checkin_models if checkin.mood is not None]
    sleep_scores = [
        checkin.sleep_quality for checkin in checkin_models if checkin.sleep_quality is not None
    ]

    return {
        "window": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "profile": profile,
        "protocol": protocol,
        "checkins": checkins,
        "doses": doses,
        "labs": labs,
        "aggregates": {
            "checkin_count": len(checkins),
            "dose_count": len(doses),
            "weight_first": weights[0] if weights else None,
            "weight_last": weights[-1] if weights else None,
            "avg_energy": _mean(energies),
            "avg_mood": _mean(moods),
            "avg_sleep_quality": _mean(sleep_scores),
        },
    }
