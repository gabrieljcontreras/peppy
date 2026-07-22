import csv
import json
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from enum import Enum
from io import StringIO
from tempfile import SpooledTemporaryFile
from typing import IO, Any, cast
from uuid import UUID
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.export import DataExportRequest, ExportFormat
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight
from app.models.notification import DoseReminderSetting, NotificationPreference
from app.models.profile import OnboardingProfile
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.services.profile import OnboardingProfileService

ACCOUNT_FIELDS = (
    "id",
    "email",
    "display_name",
    "timezone",
    "is_verified",
    "created_at",
    "updated_at",
)
PROFILE_FIELDS = (
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
    "baseline_date",
    "primary_goal",
    "secondary_goal",
    "focus_area",
    "healthkit_requested",
    "healthkit_last_sync_at",
    "notifications_authorized",
    "created_at",
    "updated_at",
)
PREFERENCE_FIELDS = (
    "insights_enabled",
    "alert_severity_only",
    "quiet_hours_start",
    "quiet_hours_end",
    "dose_reminders_enabled",
    "daily_checkin_reminders_enabled",
    "daily_checkin_time",
    "detailed_previews_enabled",
    "dose_reminders",
    "created_at",
    "updated_at",
)
PROTOCOL_FIELDS = (
    "id",
    "name",
    "start_date",
    "end_date",
    "is_active",
    "setup_status",
    "is_starter",
    "notes",
    "created_at",
    "updated_at",
)
COMPOUND_FIELDS = (
    "id",
    "protocol_id",
    "name",
    "dose_mg",
    "dose_unit",
    "frequency",
    "administration_route",
    "notes",
    "created_at",
    "updated_at",
)
DOSE_LOG_FIELDS = (
    "id",
    "protocol_id",
    "compound_id",
    "dose",
    "unit",
    "administered_at",
    "route",
    "notes",
    "created_at",
    "updated_at",
)
CHECKIN_FIELDS = (
    "id",
    "date",
    "weight_kg",
    "energy_level",
    "sleep_quality",
    "appetite_level",
    "mood",
    "nausea",
    "injection_site_reaction",
    "fatigue",
    "headache",
    "gi_issues",
    "notes",
    "created_at",
    "updated_at",
)
INSIGHT_FIELDS = (
    "id",
    "type",
    "severity",
    "title",
    "description",
    "explanation",
    "confidence",
    "read_at",
    "dismissed_at",
    "action_taken",
    "action_notes",
    "source_data_refs",
    "supporting_data",
    "snoozed_until",
    "created_at",
    "updated_at",
)

CSV_SECTIONS = (
    ("account.csv", "account", ACCOUNT_FIELDS),
    ("profile.csv", "profile", PROFILE_FIELDS),
    ("preferences.csv", "preferences", PREFERENCE_FIELDS),
    ("protocols.csv", "protocols", PROTOCOL_FIELDS),
    ("compounds.csv", "compounds", COMPOUND_FIELDS),
    ("dose_logs.csv", "dose_logs", DOSE_LOG_FIELDS),
    ("checkins.csv", "checkins", CHECKIN_FIELDS),
    ("insights.csv", "insights", INSIGHT_FIELDS),
)


@dataclass
class GeneratedExport:
    stream: IO[bytes]
    filename: str
    media_type: str


@dataclass
class ExportDataset:
    account: list[dict[str, Any]]
    profile: list[dict[str, Any]]
    preferences: list[dict[str, Any]]
    protocols: list[dict[str, Any]]
    compounds: list[dict[str, Any]]
    dose_logs: list[dict[str, Any]]
    checkins: list[dict[str, Any]]
    insights: list[dict[str, Any]]

    def section(self, name: str) -> list[dict[str, Any]]:
        return cast(list[dict[str, Any]], getattr(self, name))


class ExportService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def generate(self, user: User, request: DataExportRequest) -> GeneratedExport:
        dataset = await self.collect(user, request)
        if request.format == ExportFormat.CSV:
            return self._generate_csv_zip(dataset, request)
        return self._generate_pdf(dataset, request)

    async def collect(self, user: User, request: DataExportRequest) -> ExportDataset:
        profile = await self._one_or_none(
            select(OnboardingProfile).where(OnboardingProfile.user_id == user.id)
        )
        preference = await self._one_or_none(
            select(NotificationPreference).where(NotificationPreference.user_id == user.id)
        )
        reminders = await self._all(
            select(DoseReminderSetting)
            .where(DoseReminderSetting.user_id == user.id)
            .order_by(DoseReminderSetting.compound_id)
        )

        protocols: list[Protocol] = []
        compounds: list[Compound] = []
        dose_logs: list[DoseLog] = []
        if request.include_protocols:
            protocols = await self._all(
                select(Protocol)
                .where(Protocol.user_id == user.id)
                .order_by(Protocol.start_date, Protocol.id)
            )
            compounds = await self._all(
                select(Compound)
                .join(Protocol, Compound.protocol_id == Protocol.id)
                .where(Protocol.user_id == user.id)
                .order_by(Compound.protocol_id, Compound.id)
            )
            dose_query = (
                select(DoseLog)
                .where(DoseLog.user_id == user.id)
                .order_by(DoseLog.administered_at, DoseLog.id)
            )
            dose_logs = await self._all(
                self._filter_datetime_range(dose_query, DoseLog.administered_at, request)
            )

        checkins: list[Checkin] = []
        if request.include_checkins:
            checkin_query = (
                select(Checkin).where(Checkin.user_id == user.id).order_by(Checkin.date, Checkin.id)
            )
            checkins = await self._all(
                self._filter_date_range(checkin_query, Checkin.date, request)
            )

        insights: list[Insight] = []
        if request.include_insights:
            insight_query = (
                select(Insight)
                .where(Insight.user_id == user.id)
                .order_by(Insight.created_at, Insight.id)
            )
            insights = await self._all(
                self._filter_datetime_range(insight_query, Insight.created_at, request)
            )

        reminder_rows = [
            {
                "compound_id": reminder.compound_id,
                "local_time": reminder.local_time,
                "enabled": reminder.enabled,
            }
            for reminder in reminders
        ]
        preference_row = self._model_row(preference, PREFERENCE_FIELDS) if preference else {}
        preference_row["dose_reminders"] = reminder_rows

        profile_row = self._model_row(profile, PROFILE_FIELDS) if profile else None
        if profile and profile_row is not None:
            effective_profile = OnboardingProfileService(self.db).to_payload(profile)
            for field in ("primary_goal", "secondary_goal", "focus_area"):
                profile_row[field] = effective_profile[field]

        return ExportDataset(
            account=[self._model_row(user, ACCOUNT_FIELDS)],
            profile=[profile_row] if profile_row is not None else [],
            preferences=[preference_row],
            protocols=[self._model_row(item, PROTOCOL_FIELDS) for item in protocols],
            compounds=[self._model_row(item, COMPOUND_FIELDS) for item in compounds],
            dose_logs=[self._model_row(item, DOSE_LOG_FIELDS) for item in dose_logs],
            checkins=[self._model_row(item, CHECKIN_FIELDS) for item in checkins],
            insights=[self._model_row(item, INSIGHT_FIELDS) for item in insights],
        )

    async def _one_or_none(self, query: Select[Any]) -> Any | None:
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def _all(self, query: Select[Any]) -> list[Any]:
        result = await self.db.execute(query)
        return list(result.scalars().all())

    @staticmethod
    def _filter_date_range(
        query: Select[Any],
        column: Any,
        request: DataExportRequest,
    ) -> Select[Any]:
        if request.start_date:
            query = query.where(column >= request.start_date)
        if request.end_date:
            query = query.where(column <= request.end_date)
        return query

    @staticmethod
    def _filter_datetime_range(
        query: Select[Any],
        column: Any,
        request: DataExportRequest,
    ) -> Select[Any]:
        if request.start_date:
            start = datetime.combine(request.start_date, time.min, tzinfo=timezone.utc)
            query = query.where(column >= start)
        if request.end_date:
            exclusive_end = datetime.combine(
                request.end_date + timedelta(days=1),
                time.min,
                tzinfo=timezone.utc,
            )
            query = query.where(column < exclusive_end)
        return query

    @staticmethod
    def _model_row(model: Any, fields: tuple[str, ...]) -> dict[str, Any]:
        return {field: getattr(model, field, None) for field in fields}

    def _generate_csv_zip(
        self,
        dataset: ExportDataset,
        request: DataExportRequest,
    ) -> GeneratedExport:
        stream = self._new_stream()
        try:
            with ZipFile(stream, mode="w", compression=ZIP_DEFLATED) as archive:
                sections = self._included_sections(request)
                manifest = self._manifest(request, [filename for filename, _, _ in sections])
                archive.writestr(
                    "manifest.json",
                    json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8"),
                )
                for filename, section_name, fields in sections:
                    archive.writestr(
                        filename,
                        self._csv_bytes(dataset.section(section_name), fields),
                    )
            stream.seek(0)
        except Exception:
            stream.close()
            raise
        return GeneratedExport(
            stream=stream,
            filename=f"peppy-export-{date.today().isoformat()}.zip",
            media_type="application/zip",
        )

    def _generate_pdf(
        self,
        dataset: ExportDataset,
        request: DataExportRequest,
    ) -> GeneratedExport:
        stream = self._new_stream()
        try:
            styles = getSampleStyleSheet()
            story: list[Any] = [
                Paragraph("Peppy Data Export", styles["Title"]),
                Paragraph(
                    f"Generated {datetime.now(timezone.utc).date().isoformat()}",
                    styles["Normal"],
                ),
                Spacer(1, 0.2 * inch),
            ]
            for _, section_name, fields in self._included_sections(request):
                rows = dataset.section(section_name)
                if section_name not in {"account", "profile", "preferences"} and not rows:
                    continue
                story.append(Paragraph(section_name.replace("_", " ").title(), styles["Heading2"]))
                if not rows:
                    story.append(Paragraph("No data recorded.", styles["Normal"]))
                    story.append(Spacer(1, 0.12 * inch))
                    continue
                for index, row in enumerate(rows):
                    if len(rows) > 1:
                        story.append(Paragraph(f"Record {index + 1}", styles["Heading3"]))
                    table_rows = [
                        [
                            Paragraph(escape(field.replace("_", " ").title()), styles["BodyText"]),
                            Paragraph(self._pdf_text(row.get(field)), styles["BodyText"]),
                        ]
                        for field in fields
                    ]
                    table = Table(table_rows, colWidths=(1.75 * inch, 4.95 * inch), repeatRows=0)
                    table.setStyle(
                        TableStyle(
                            [
                                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F2F4F7")),
                                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D0D5DD")),
                                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                                ("TOPPADDING", (0, 0), (-1, -1), 4),
                                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                            ]
                        )
                    )
                    story.extend([table, Spacer(1, 0.14 * inch)])

            document = SimpleDocTemplate(
                stream,
                pagesize=letter,
                title="Peppy Data Export",
                author="Peppy",
            )
            document.build(story)
            stream.seek(0)
        except Exception:
            stream.close()
            raise
        return GeneratedExport(
            stream=stream,
            filename=f"peppy-export-{date.today().isoformat()}.pdf",
            media_type="application/pdf",
        )

    @staticmethod
    def _new_stream() -> IO[bytes]:
        return SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")

    @staticmethod
    def _included_sections(
        request: DataExportRequest,
    ) -> list[tuple[str, str, tuple[str, ...]]]:
        included = list(CSV_SECTIONS[:3])
        if request.include_protocols:
            included.extend(CSV_SECTIONS[3:6])
        if request.include_checkins:
            included.append(CSV_SECTIONS[6])
        if request.include_insights:
            included.append(CSV_SECTIONS[7])
        return included

    @staticmethod
    def _manifest(request: DataExportRequest, filenames: list[str]) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "format": request.format.value,
            "included_categories": {
                "protocols": request.include_protocols,
                "checkins": request.include_checkins,
                "insights": request.include_insights,
            },
            "start_date": request.start_date.isoformat() if request.start_date else None,
            "end_date": request.end_date.isoformat() if request.end_date else None,
            "files": ["manifest.json", *filenames],
        }

    @classmethod
    def _csv_bytes(
        cls,
        rows: list[dict[str, Any]],
        fields: tuple[str, ...],
    ) -> bytes:
        output = StringIO(newline="")
        writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: cls._csv_cell(row.get(field)) for field in fields})
        return output.getvalue().encode("utf-8")

    @classmethod
    def _csv_cell(cls, value: Any) -> str:
        serialized = cls._serialize(value)
        if serialized.startswith(("=", "+", "-", "@")):
            return f"'{serialized}"
        return serialized

    @classmethod
    def _pdf_text(cls, value: Any) -> str:
        return escape(cls._serialize(value)).replace("\n", "<br/>") or "—"

    @staticmethod
    def _serialize(value: Any) -> str:
        if value is None:
            return ""
        if isinstance(value, Enum):
            return str(value.value)
        if isinstance(value, (date, datetime, time)):
            return value.isoformat()
        if isinstance(value, UUID):
            return str(value)
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, (dict, list, tuple)):
            return json.dumps(value, ensure_ascii=False, default=ExportService._serialize)
        return str(value)
