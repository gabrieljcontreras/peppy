import csv
import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from io import BytesIO, StringIO
from zipfile import ZipFile

import pytest
from sqlalchemy import select

from app.api.schemas.export import DataExportRequest
from app.models.base import Base
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.notification import NotificationPreference
from app.models.profile import OnboardingProfile
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.services.export import ExportDataset, ExportService


@dataclass(frozen=True)
class ExportAccounts:
    primary_headers: dict[str, str]
    other_email: str


def _archive(response) -> ZipFile:
    return ZipFile(BytesIO(response.content))


def _csv_rows(archive: ZipFile, filename: str) -> list[dict[str, str]]:
    content = archive.read(filename).decode("utf-8")
    return list(csv.DictReader(StringIO(content)))


@pytest.fixture
async def export_accounts(client, db_session) -> ExportAccounts:
    primary_email = "primary-export@example.com"
    other_email = "other-export@example.com"
    primary_registration = await client.post(
        "/api/v1/auth/register",
        json={
            "email": primary_email,
            "password": "password123",
            "display_name": "Primary Export",
        },
    )
    await client.post(
        "/api/v1/auth/register",
        json={
            "email": other_email,
            "password": "password123",
            "display_name": "Other Export",
        },
    )

    users = (
        await db_session.execute(select(User).where(User.email.in_([primary_email, other_email])))
    ).scalars()
    users_by_email = {user.email: user for user in users}
    primary = users_by_email[primary_email]
    other = users_by_email[other_email]

    primary.timezone = "America/New_York"
    db_session.add_all(
        [
            OnboardingProfile(
                user_id=primary.id,
                baseline_date=date(2026, 6, 15),
                weight_kg=82.5,
                preferred_weight_unit="lb",
                height_cm=177.8,
                preferred_height_unit="ft_in",
                goals=["track_protocols", "build_habits"],
                focus_area="understand_body",
            ),
            NotificationPreference(
                user_id=primary.id,
                insights_enabled=True,
                alert_severity_only=False,
                dose_reminders_enabled=True,
                daily_checkin_reminders_enabled=True,
                detailed_previews_enabled=False,
            ),
            Protocol(
                user_id=primary.id,
                name="Primary protocol",
                start_date=date(2026, 6, 1),
                notes="=SUM(A1:A2)",
            ),
            Protocol(
                user_id=other.id,
                name="Foreign protocol",
                start_date=date(2026, 6, 1),
                notes=f"private:{other_email}",
            ),
        ]
    )
    await db_session.flush()

    protocols = (await db_session.execute(select(Protocol))).scalars()
    protocols_by_name = {protocol.name: protocol for protocol in protocols}
    primary_protocol = protocols_by_name["Primary protocol"]
    foreign_protocol = protocols_by_name["Foreign protocol"]
    primary_compound = Compound(
        protocol_id=primary_protocol.id,
        name="Retatrutide",
        dose_mg=2.0,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
        notes="+formula payload",
    )
    foreign_compound = Compound(
        protocol_id=foreign_protocol.id,
        name="Foreign compound",
        dose_mg=1.0,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
        notes=f"private:{other_email}",
    )
    db_session.add_all([primary_compound, foreign_compound])
    await db_session.flush()

    boundary_start = datetime(2026, 7, 1, 12, 0, tzinfo=timezone.utc)
    boundary_end = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)
    db_session.add_all(
        [
            DoseLog(
                user_id=primary.id,
                protocol_id=primary_protocol.id,
                compound_id=primary_compound.id,
                dose=2.0,
                unit="mg",
                administered_at=boundary_start,
                route="subcutaneous",
                notes="start-boundary",
            ),
            DoseLog(
                user_id=primary.id,
                protocol_id=primary_protocol.id,
                compound_id=primary_compound.id,
                dose=2.0,
                unit="mg",
                administered_at=boundary_end,
                route="subcutaneous",
                notes="end-boundary",
            ),
            DoseLog(
                user_id=primary.id,
                protocol_id=primary_protocol.id,
                compound_id=primary_compound.id,
                dose=2.0,
                unit="mg",
                administered_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
                route="subcutaneous",
                notes="before-range",
            ),
            DoseLog(
                user_id=other.id,
                protocol_id=foreign_protocol.id,
                compound_id=foreign_compound.id,
                dose=1.0,
                unit="mg",
                administered_at=boundary_start,
                route="subcutaneous",
                notes=f"private:{other_email}",
            ),
            Checkin(
                user_id=primary.id,
                date=date(2026, 7, 1),
                energy_level=7,
                notes="début café",
            ),
            Checkin(
                user_id=primary.id,
                date=date(2026, 7, 20),
                energy_level=8,
                notes="@end-formula",
            ),
            Checkin(
                user_id=primary.id,
                date=date(2026, 6, 30),
                energy_level=6,
                notes="before-range",
            ),
            Checkin(
                user_id=other.id,
                date=date(2026, 7, 10),
                energy_level=10,
                notes=f"private:{other_email}",
            ),
            Insight(
                user_id=primary.id,
                type=InsightType.TREND,
                severity=InsightSeverity.INFO,
                title="Start insight",
                description="start-boundary",
                explanation="Selected data",
                confidence=0.9,
                created_at=boundary_start,
            ),
            Insight(
                user_id=primary.id,
                type=InsightType.ANOMALY,
                severity=InsightSeverity.WARNING,
                title="-End insight",
                description="end-boundary",
                explanation="Selected data",
                confidence=0.8,
                created_at=boundary_end,
            ),
            Insight(
                user_id=primary.id,
                type=InsightType.SUGGESTION,
                severity=InsightSeverity.INFO,
                title="Before insight",
                description="before-range",
                explanation="Excluded data",
                confidence=0.7,
                created_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
            ),
            Insight(
                user_id=other.id,
                type=InsightType.ANOMALY,
                severity=InsightSeverity.ALERT,
                title="Foreign insight",
                description=f"private:{other_email}",
                explanation="Foreign data",
                confidence=1.0,
                created_at=boundary_start,
            ),
        ]
    )
    await db_session.commit()

    return ExportAccounts(
        primary_headers={"Authorization": f"Bearer {primary_registration.json()['access_token']}"},
        other_email=other_email,
    )


async def test_csv_export_contains_manifest_and_only_selected_owned_data(
    client,
    export_accounts,
):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "csv",
            "include_protocols": True,
            "include_checkins": False,
            "include_insights": True,
            "start_date": "2026-07-01",
            "end_date": "2026-07-20",
        },
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/zip")
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["content-disposition"].startswith('attachment; filename="peppy-export-')
    archive = _archive(response)
    assert set(archive.namelist()) == {
        "manifest.json",
        "account.csv",
        "profile.csv",
        "preferences.csv",
        "protocols.csv",
        "compounds.csv",
        "dose_logs.csv",
        "insights.csv",
    }
    extracted = b"".join(archive.read(name) for name in archive.namelist())
    assert export_accounts.other_email.encode() not in extracted
    assert "checkins.csv" not in archive.namelist()


async def test_pdf_export_is_valid_and_no_export_record_is_persisted(
    client,
    export_accounts,
):
    before_tables = set(Base.metadata.tables)
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "pdf",
            "include_protocols": False,
            "include_checkins": False,
            "include_insights": False,
        },
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/pdf")
    assert response.headers["cache-control"] == "no-store"
    assert response.content.startswith(b"%PDF")
    assert set(Base.metadata.tables) == before_tables
    assert "exports" not in Base.metadata.tables


async def test_csv_export_date_filters_are_inclusive(client, export_accounts):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "csv",
            "include_protocols": True,
            "include_checkins": True,
            "include_insights": True,
            "start_date": "2026-07-01",
            "end_date": "2026-07-20",
        },
    )

    assert response.status_code == 200
    archive = _archive(response)
    dose_rows = _csv_rows(archive, "dose_logs.csv")
    checkin_rows = _csv_rows(archive, "checkins.csv")
    insight_rows = _csv_rows(archive, "insights.csv")
    assert {row["notes"] for row in dose_rows} == {"start-boundary", "end-boundary"}
    assert {row["date"] for row in checkin_rows} == {"2026-07-01", "2026-07-20"}
    assert {row["description"] for row in insight_rows} == {
        "start-boundary",
        "end-boundary",
    }
    serialized = json.dumps([dose_rows, checkin_rows, insight_rows], ensure_ascii=False)
    assert "before-range" not in serialized


@pytest.mark.parametrize(
    "payload",
    [
        {
            "format": "csv",
            "start_date": "2026-07-20",
            "end_date": "2026-07-01",
        },
        {
            "format": "csv",
            "end_date": (date.today() + timedelta(days=1)).isoformat(),
        },
        {
            "format": "csv",
            "start_date": (date.today() + timedelta(days=1)).isoformat(),
        },
        {"format": "csv", "unexpected": True},
    ],
)
async def test_export_rejects_invalid_ranges_and_unknown_fields(
    client,
    export_accounts,
    payload,
):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json=payload,
    )

    assert response.status_code == 422


async def test_csv_export_allows_account_only_output(client, export_accounts):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "csv",
            "include_protocols": False,
            "include_checkins": False,
            "include_insights": False,
        },
    )

    assert response.status_code == 200
    archive = _archive(response)
    assert set(archive.namelist()) == {
        "manifest.json",
        "account.csv",
        "profile.csv",
        "preferences.csv",
    }
    manifest = json.loads(archive.read("manifest.json"))
    assert manifest["included_categories"] == {
        "protocols": False,
        "checkins": False,
        "insights": False,
    }
    assert _csv_rows(archive, "account.csv")[0]["email"] == "primary-export@example.com"
    profile = _csv_rows(archive, "profile.csv")[0]
    assert profile["primary_goal"] == "track_protocols"
    assert profile["secondary_goal"] == "build_habits"


async def test_csv_export_preserves_utf8_and_escapes_formula_leading_cells(
    client,
    export_accounts,
):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "csv",
            "include_protocols": True,
            "include_checkins": True,
            "include_insights": True,
        },
    )

    assert response.status_code == 200
    archive = _archive(response)
    assert any(row["notes"] == "début café" for row in _csv_rows(archive, "checkins.csv"))
    assert any(row["notes"] == "'=SUM(A1:A2)" for row in _csv_rows(archive, "protocols.csv"))
    assert any(row["notes"] == "'+formula payload" for row in _csv_rows(archive, "compounds.csv"))
    assert any(row["notes"] == "'@end-formula" for row in _csv_rows(archive, "checkins.csv"))
    assert any(row["title"] == "'-End insight" for row in _csv_rows(archive, "insights.csv"))


async def test_export_requires_authentication(client):
    response = await client.post(
        "/api/v1/profile/export",
        json={"format": "csv"},
    )

    assert response.status_code == 403


def test_csv_generator_closes_temporary_stream_after_generation_failure(monkeypatch):
    stream = BytesIO()
    service = ExportService(db=None)
    dataset = ExportDataset(
        account=[{}],
        profile=[],
        preferences=[{}],
        protocols=[],
        compounds=[],
        dose_logs=[],
        checkins=[],
        insights=[],
    )
    request = DataExportRequest(
        format="csv",
        include_protocols=False,
        include_checkins=False,
        include_insights=False,
    )
    monkeypatch.setattr(service, "_new_stream", lambda: stream)

    def fail_csv_generation(*_args, **_kwargs):
        raise RuntimeError("archive generation failed")

    monkeypatch.setattr(service, "_csv_bytes", fail_csv_generation)

    with pytest.raises(RuntimeError, match="archive generation failed"):
        service._generate_csv_zip(dataset, request)

    assert stream.closed
