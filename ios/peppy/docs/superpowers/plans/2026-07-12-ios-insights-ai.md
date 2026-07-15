# Peppy Insights (AI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Insights tab (list, detail, AI weekly summary) end-to-end: 3 new
deterministic detection rules, a Claude-powered narrative layer with template
fallback, event-driven generation, snooze semantics, and Figma-exact iOS screens.

**Architecture:** Hybrid AI — rules compute every number and attach frozen
`supporting_data` evidence; `narrator.py` (Anthropic SDK) rewrites descriptions
(Haiku) and writes the weekly summary narrative (Sonnet) from a longitudinal
snapshot, falling back to rule-templated text on any failure. FastAPI
BackgroundTasks trigger generation after check-in/dose writes and on stale list
fetches. iOS adds `Features/Insights` (store + 3 screens) mirroring the
Protocols feature architecture.

**Tech Stack:** FastAPI + SQLAlchemy (async) + alembic + pytest; `anthropic`
Python SDK (`claude-haiku-4-5`, `claude-sonnet-5`, structured JSON via
`output_config.format`); SwiftUI + Swift Charts + XCTest.

**Spec:** `ios/peppy/docs/superpowers/specs/2026-07-12-ios-insights-ai-design.md`
**Figma frames (visual source of truth):**
`~/.claude/projects/-Users-gabri-peppy/figma-frames/{insights-list,insight-detail,ai-weekly-summary,dashboard-with-insight}.png`

## Global Constraints

- Work on branch `IOS_insights_dev` (Gabriel manages branch creation/merges).
- Backend venv is `backend/venv` (NOT `.venv`): run tests with `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest`.
- Backend tests use in-memory sqlite via `Base.metadata.create_all` — model changes are picked up automatically; the alembic migration is for real databases.
- iOS builds/tests need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and destination `platform=iOS Simulator,name=iPhone 17 Pro`. Ignore SourceKit IDE diagnostics; trust xcodebuild.
- `ios/peppy/peppy.xcodeproj` does NOT use filesystem-synchronized groups: **every new Swift file must be manually registered in `project.pbxproj`** (PBXBuildFile entry, PBXFileReference entry, parent group `children`, target Sources build phase). Existing IDs are 24-char uppercase hex; generate new unique ones in the same style.
- Model IDs are exactly `claude-haiku-4-5` (insight narratives) and `claude-sonnet-5` (weekly summary). Do not append date suffixes. Do NOT pass `output_config.effort` on Haiku 4.5 (errors on that model); do not pass `temperature`/`top_p` on either.
- LLM calls must never block or fail insight persistence: any Anthropic error, timeout, or schema-invalid response → discard the whole LLM result and use rule-templated text. No real API calls in tests — inject a fake client.
- The brand is "peppy" (lowercase). Design tokens: use existing `Color.pep*`, `Spacing.*`, `PepCard`/`PepBadge`/`PepButton`/`PepSelectionChip`/`PepEmptyState` components. No shadows, pill buttons, weight ceiling ~600.
- Insight list privacy-footer copy (exact): "Your data is used only to generate your insights. It's never sold and never used to train AI models."
- TDD: write the failing test first for every behavior. Frequent commits (executor commits on the feature branch).
- Production correctness overrides illustrative pseudocode and examples. When an example conflicts with correct units, eligibility, or boundary semantics, implement and test the production-correct behavior and update this plan so later tasks reuse it.

---

### Task 1: Backend schema — insight columns, weekly_summaries table, staleness marker

**Files:**
- Modify: `backend/app/models/insight.py`
- Modify: `backend/app/models/user.py`
- Create: `backend/app/models/weekly_summary.py`
- Modify: `backend/app/models/__init__.py`
- Create: `backend/alembic/versions/d7e8f9a0b1c2_insights_ai_slice.py`
- Test: `backend/tests/test_insights_schema.py`

**Interfaces:**
- Consumes: `Base, UUIDMixin, TimestampMixin, GUID` from `app.models.base`.
- Produces: `Insight.supporting_data: Text|None`, `Insight.snoozed_until: DateTime|None`, `User.last_insight_run_at: DateTime|None`, `WeeklySummary` model with `user_id: GUID`, `week_start: Date`, `payload: Text (JSON)`, `model_used: String(100)|None`, unique `(user_id, week_start)`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_insights_schema.py
import json
from datetime import date

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models.insight import Insight, InsightType, InsightSeverity
from app.models.user import User
from app.models.weekly_summary import WeeklySummary


async def _make_user(db_session) -> User:
    user = User(email="schema@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.mark.asyncio
async def test_insight_new_columns_round_trip(db_session):
    user = await _make_user(db_session)
    insight = Insight(
        user_id=user.id,
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="t",
        description="d",
        explanation="e",
        confidence=0.5,
        supporting_data=json.dumps([{"icon_key": "weight", "label": "Weight trend",
                                     "sublabel": "vs prior 2 weeks", "value": "0.4 kg / week"}]),
    )
    db_session.add(insight)
    await db_session.commit()
    await db_session.refresh(insight)
    assert insight.snoozed_until is None
    assert json.loads(insight.supporting_data)[0]["icon_key"] == "weight"


@pytest.mark.asyncio
async def test_user_last_insight_run_at_defaults_null(db_session):
    user = await _make_user(db_session)
    assert user.last_insight_run_at is None


@pytest.mark.asyncio
async def test_weekly_summary_unique_per_user_week(db_session):
    user = await _make_user(db_session)
    row = WeeklySummary(user_id=user.id, week_start=date(2026, 7, 6),
                        payload=json.dumps({"narrative": "hi"}), model_used="claude-sonnet-5")
    db_session.add(row)
    await db_session.commit()

    dupe = WeeklySummary(user_id=user.id, week_start=date(2026, 7, 6), payload="{}")
    db_session.add(dupe)
    with pytest.raises(IntegrityError):
        await db_session.commit()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_insights_schema.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.models.weekly_summary'`

- [ ] **Step 3: Implement the model changes**

In `backend/app/models/insight.py`, after the `source_data_refs` column add:

```python
    # Frozen evidence rows for the detail screen (JSON list of
    # {icon_key, label, sublabel, value}), written by the rule at detection time.
    supporting_data = Column(Text, nullable=True)

    # Snooze: hidden from default lists until this passes, then resurfaces unread.
    snoozed_until = Column(DateTime(timezone=True), nullable=True)
```

In `backend/app/models/user.py`, after `timezone` add (import `DateTime` from sqlalchemy):

```python
    # Staleness marker for insight generate-if-stale on list fetches.
    last_insight_run_at = Column(DateTime(timezone=True), nullable=True)
```

Create `backend/app/models/weekly_summary.py`:

```python
from sqlalchemy import Column, Date, ForeignKey, String, Text, UniqueConstraint

from app.models.base import Base, GUID, TimestampMixin, UUIDMixin


class WeeklySummary(Base, UUIDMixin, TimestampMixin):
    """Cached AI weekly summary. One immutable row per (user, completed Mon-Sun week)."""

    __tablename__ = "weekly_summaries"
    __table_args__ = (UniqueConstraint("user_id", "week_start", name="uq_weekly_summary_user_week"),)

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    week_start = Column(Date, nullable=False)  # Monday of the summarized week
    payload = Column(Text, nullable=False)  # JSON: hero, what_changed, what_to_watch, provider_questions, narrative, weight_series
    model_used = Column(String(100), nullable=True)  # null when narrative fell back / disabled
```

Register it in `backend/app/models/__init__.py` following the existing import/export style (import `WeeklySummary` and add to `__all__` if the file uses one).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_insights_schema.py -v`
Expected: 3 passed

- [ ] **Step 5: Write the alembic migration**

First confirm the current head: `cd /Users/gabri/peppy/backend && venv/bin/alembic heads` → expected `c5d6e7f8a9b0`. If different, use that value as `down_revision`.

Create `backend/alembic/versions/d7e8f9a0b1c2_insights_ai_slice.py`:

```python
"""insights ai slice: supporting_data, snoozed_until, weekly_summaries, last_insight_run_at

Revision ID: d7e8f9a0b1c2
Revises: c5d6e7f8a9b0
Create Date: 2026-07-12
"""
import sqlalchemy as sa
from alembic import op

revision = "d7e8f9a0b1c2"
down_revision = "c5d6e7f8a9b0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("insights", sa.Column("supporting_data", sa.Text(), nullable=True))
    op.add_column("insights", sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("last_insight_run_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "weekly_summaries",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("user_id", sa.CHAR(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column("model_used", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "week_start", name="uq_weekly_summary_user_week"),
    )


def downgrade() -> None:
    op.drop_table("weekly_summaries")
    op.drop_column("users", "last_insight_run_at")
    op.drop_column("insights", "snoozed_until")
    op.drop_column("insights", "supporting_data")
```

Match the CHAR(36)/GUID column style against `c5d6e7f8a9b0_protocol_dose_logs.py` and adjust if that file uses a different pattern for GUID columns.

- [ ] **Step 6: Run the full backend suite**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest`
Expected: all pass (no regressions)

- [ ] **Step 7: Commit**

```bash
git add backend/app/models backend/alembic/versions/d7e8f9a0b1c2_insights_ai_slice.py backend/tests/test_insights_schema.py
git commit -m "feat(backend): insight supporting_data/snooze columns, weekly_summaries table, staleness marker"
```

---

### Task 2: Insight service — snooze semantics, supporting_data, response schema

**Files:**
- Modify: `backend/app/ml/insights_engine.py` (GeneratedInsight)
- Modify: `backend/app/services/insight.py`
- Modify: `backend/app/api/schemas/insight.py`
- Test: `backend/tests/test_insight_service.py`

**Interfaces:**
- Consumes: Task 1 columns.
- Produces:
  - `GeneratedInsight` gains field `supporting_data: Optional[str] = None` (JSON string).
  - `InsightService.create(..., supporting_data: Optional[str] = None)`.
  - `InsightService.record_action(insight, "snooze")` sets `snoozed_until = now + 7 days` and `read_at = None`.
  - `InsightService.list_for_user(...)` excludes rows where `snoozed_until > now`.
  - `InsightService.mark_read` also clears `snoozed_until`.
  - Pydantic `SupportingDataItem {icon_key: str, label: str, sublabel: str|None, value: str}`; `InsightResponse` gains `supporting_data: list[SupportingDataItem]|None` (parsed from the JSON string) and `snoozed_until: datetime|None`.

- [ ] **Step 1: Write the failing tests**

```python
# backend/tests/test_insight_service.py
import json
from datetime import datetime, timedelta, timezone

import pytest

from app.models.insight import InsightType, InsightSeverity
from app.models.user import User
from app.services.insight import InsightService


async def _user(db_session) -> User:
    user = User(email="svc@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


async def _insight(db_session, user, **overrides):
    service = InsightService(db_session)
    kwargs = dict(
        user_id=user.id, type=InsightType.TREND, severity=InsightSeverity.INFO,
        title="t", description="d", explanation="e", confidence=0.6,
    )
    kwargs.update(overrides)
    return await service.create(**kwargs)


@pytest.mark.asyncio
async def test_create_persists_supporting_data(db_session):
    user = await _user(db_session)
    rows = json.dumps([{"icon_key": "calendar", "label": "Dose timing", "sublabel": None, "value": "100% on time"}])
    insight = await _insight(db_session, user, supporting_data=rows)
    assert json.loads(insight.supporting_data)[0]["label"] == "Dose timing"


@pytest.mark.asyncio
async def test_snooze_sets_snoozed_until_and_clears_read(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    insight = await _insight(db_session, user)
    await service.mark_read(insight)
    updated = await service.record_action(insight, action="snooze")
    assert updated.read_at is None
    assert updated.snoozed_until is not None
    delta = updated.snoozed_until - datetime.now(timezone.utc)
    assert timedelta(days=6, hours=23) < delta < timedelta(days=7, hours=1)


@pytest.mark.asyncio
async def test_list_excludes_actively_snoozed_and_includes_expired(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    active = await _insight(db_session, user, title="active")
    snoozed = await _insight(db_session, user, title="snoozed")
    expired = await _insight(db_session, user, title="expired")
    await service.record_action(snoozed, action="snooze")
    expired.snoozed_until = datetime.now(timezone.utc) - timedelta(days=1)
    await db_session.commit()

    titles = {i.title for i in await service.list_for_user(user_id=user.id)}
    assert titles == {"active", "expired"}


@pytest.mark.asyncio
async def test_mark_read_clears_snooze(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    insight = await _insight(db_session, user)
    await service.record_action(insight, action="snooze")
    updated = await service.mark_read(insight)
    assert updated.snoozed_until is None
    assert updated.read_at is not None
```

Note: sqlite returns naive datetimes; if the timedelta assertion fails on tz-naive
values, normalize with `updated.snoozed_until.replace(tzinfo=timezone.utc)` in the test.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_insight_service.py -v`
Expected: FAIL (`create() got an unexpected keyword argument 'supporting_data'`, snooze assertions fail)

- [ ] **Step 3: Implement**

`backend/app/ml/insights_engine.py` — add to the `GeneratedInsight` dataclass after `source_data_refs`:

```python
    supporting_data: Optional[str] = None  # JSON list of {icon_key,label,sublabel,value}
```

`backend/app/services/insight.py`:
- Add `from datetime import timedelta` alongside the existing datetime imports.
- `create(...)`: add parameter `supporting_data: Optional[str] = None` and pass through to the `Insight(...)` constructor.
- `list_for_user(...)`: after the dismissed filter add:

```python
        from sqlalchemy import or_  # move to module imports
        now = datetime.now(timezone.utc)
        query = query.where(
            or_(Insight.snoozed_until.is_(None), Insight.snoozed_until <= now)
        )
```

- `record_action(...)`: inside the method, after the dismiss branch add:

```python
        if action == "snooze":
            insight.snoozed_until = datetime.now(timezone.utc) + timedelta(days=7)
            insight.read_at = None  # resurfaces as unread after the snooze expires
```

- `mark_read(...)`: alongside the existing clears add `insight.snoozed_until = None`.

`backend/app/api/schemas/insight.py` — add:

```python
from pydantic import field_validator
import json


class SupportingDataItem(BaseModel):
    icon_key: str
    label: str
    sublabel: Optional[str] = None
    value: str
```

and on `InsightResponse` add fields + parser:

```python
    snoozed_until: Optional[datetime] = None
    supporting_data: Optional[list[SupportingDataItem]] = None

    @field_validator("supporting_data", mode="before")
    @classmethod
    def _parse_supporting_data(cls, v):
        if isinstance(v, str):
            return json.loads(v) if v else None
        return v
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_insight_service.py tests/test_insights_schema.py -v`
Expected: all pass

- [ ] **Step 5: Full suite + commit**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest`
Expected: all pass

```bash
git add backend/app/ml/insights_engine.py backend/app/services/insight.py backend/app/api/schemas/insight.py backend/tests/test_insight_service.py
git commit -m "feat(backend): snooze semantics, supporting_data on insights"
```

---

### Task 3: Rule — symptom_after_dose

**Files:**
- Create: `backend/app/ml/rules/symptom_after_dose.py`
- Modify: `backend/app/ml/rules/__init__.py`
- Test: `backend/tests/test_rule_symptom_after_dose.py`

**Interfaces:**
- Consumes: `Checkin` (symptom columns `nausea, injection_site_reaction, fatigue, headache, gi_issues`, 0–10), `DoseLog.administered_at`, `GeneratedInsight` (with `supporting_data`).
- Produces: `symptom_after_dose_rule(db, user_id, start_date, end_date) -> list[GeneratedInsight]` registered in `DEFAULT_RULES`.

**Rule spec (from design):** For each symptom field: an "occurrence" is a check-in
with severity ≥ 3 on a dose date or the following day. Look at the last up to 4
distinct dose dates in the window; require ≥ 3 dose dates in the window and
≥ 3 occurrences among the last 4. Contrast: rate of symptom-days among
non-dose-window check-in days must be less than half the dose-window rate
(zero non-dose occurrences trivially satisfies this). Emits one ANOMALY/WARNING
insight per qualifying symptom. Dedup key: `{"rule": "symptom_after_dose",
"symptom": <field>, "month": "<YYYY-MM of latest dose date>"}` so a persisting
pattern can re-fire in a later month but not spam within one.

- [ ] **Step 1: Write the failing tests**

```python
# backend/tests/test_rule_symptom_after_dose.py
import json
from datetime import date, datetime, timedelta, timezone

import pytest

from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.protocol import Protocol, Compound
from app.models.user import User
from app.ml.rules.symptom_after_dose import symptom_after_dose_rule

START = date(2026, 6, 1)
END = date(2026, 6, 30)


async def _seed_protocol(db, user):
    protocol = Protocol(user_id=user.id, name="Test", start_date=START, is_active=True)
    db.add(protocol)
    await db.flush()
    compound = Compound(protocol_id=protocol.id, name="Retatrutide", dose_mg=4,
                        dose_unit="mg", frequency="weekly", administration_route="subcutaneous")
    db.add(compound)
    await db.flush()
    return protocol, compound


async def _seed(db, dose_dates, checkins):
    """checkins: list of (date, nausea_severity)"""
    user = User(email="rule1@test.com", hashed_password="x")
    db.add(user)
    await db.flush()
    protocol, compound = await _seed_protocol(db, user)
    for d in dose_dates:
        db.add(DoseLog(user_id=user.id, protocol_id=protocol.id, compound_id=compound.id,
                       dose=4, unit="mg", route="subcutaneous",
                       administered_at=datetime(d.year, d.month, d.day, 9, tzinfo=timezone.utc)))
    for d, nausea in checkins:
        db.add(Checkin(user_id=user.id, date=d, nausea=nausea))
    await db.commit()
    return user


@pytest.mark.asyncio
async def test_fires_when_nausea_follows_three_of_four_doses(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), 5), (date(2026, 6, 9), 4), (date(2026, 6, 15), 6),  # 3 occurrences
        (date(2026, 6, 23), 0),
        (date(2026, 6, 5), 0), (date(2026, 6, 12), 0), (date(2026, 6, 19), 1),  # clean non-dose days
    ]
    user = await _seed(db_session, doses, checkins)
    results = await symptom_after_dose_rule(db_session, user.id, START, END)
    assert len(results) == 1
    insight = results[0]
    assert insight.type.value == "anomaly"
    assert insight.severity.value == "warning"
    assert "nausea" in insight.title.lower() or "Nausea" in insight.title
    refs = json.loads(insight.source_data_refs)
    assert refs == {"rule": "symptom_after_dose", "symptom": "nausea", "month": "2026-06"}
    rows = json.loads(insight.supporting_data)
    assert any("3 of" in r["value"] for r in rows)


@pytest.mark.asyncio
async def test_silent_below_three_dose_events(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8)]
    checkins = [(date(2026, 6, 2), 8), (date(2026, 6, 9), 8)]
    user = await _seed(db_session, doses, checkins)
    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []


@pytest.mark.asyncio
async def test_silent_when_symptom_equally_common_on_non_dose_days(db_session):
    doses = [date(2026, 6, 1), date(2026, 6, 8), date(2026, 6, 15), date(2026, 6, 22)]
    checkins = [
        (date(2026, 6, 2), 5), (date(2026, 6, 9), 5), (date(2026, 6, 16), 5),
        # nausea just as common far from doses -> no contrast
        (date(2026, 6, 5), 5), (date(2026, 6, 12), 5), (date(2026, 6, 19), 5), (date(2026, 6, 26), 5),
    ]
    user = await _seed(db_session, doses, checkins)
    assert await symptom_after_dose_rule(db_session, user.id, START, END) == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_rule_symptom_after_dose.py -v`
Expected: FAIL with `ModuleNotFoundError`

- [ ] **Step 3: Implement the rule**

```python
# backend/app/ml/rules/symptom_after_dose.py
import json
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import InsightSeverity, InsightType

_SYMPTOMS = {
    "nausea": "Nausea",
    "injection_site_reaction": "Injection-site reaction",
    "fatigue": "Fatigue",
    "headache": "Headache",
    "gi_issues": "GI discomfort",
}
_SEVERITY_THRESHOLD = 3
_MIN_DOSE_DATES = 3
_MIN_OCCURRENCES = 3
_LOOKBACK_DOSES = 4


async def symptom_after_dose_rule(
    db: AsyncSession, user_id: UUID, start_date: date, end_date: date,
) -> list[GeneratedInsight]:
    """Detect symptoms recurring on dose day or the day after."""
    dose_rows = await db.execute(
        select(DoseLog.administered_at).where(
            and_(DoseLog.user_id == user_id,
                 DoseLog.administered_at >= start_date,
                 DoseLog.administered_at <= end_date + timedelta(days=1))
        )
    )
    dose_dates = sorted({row[0].date() for row in dose_rows.all()})
    if len(dose_dates) < _MIN_DOSE_DATES:
        return []
    recent_doses = dose_dates[-_LOOKBACK_DOSES:]

    checkin_rows = await db.execute(
        select(Checkin).where(
            and_(Checkin.user_id == user_id,
                 Checkin.date >= start_date, Checkin.date <= end_date)
        )
    )
    checkins_by_date = {c.date: c for c in checkin_rows.scalars().all()}

    dose_window_days = set()
    for d in dose_dates:
        dose_window_days.add(d)
        dose_window_days.add(d + timedelta(days=1))

    results: list[GeneratedInsight] = []
    for field, display in _SYMPTOMS.items():
        occurrences = 0
        for dose_day in recent_doses:
            for day in (dose_day, dose_day + timedelta(days=1)):
                checkin = checkins_by_date.get(day)
                if checkin and (getattr(checkin, field) or 0) >= _SEVERITY_THRESHOLD:
                    occurrences += 1
                    break  # count each dose event at most once
        if occurrences < _MIN_OCCURRENCES:
            continue

        non_dose_days = [d for d in checkins_by_date if d not in dose_window_days]
        non_dose_hits = sum(
            1 for d in non_dose_days
            if (getattr(checkins_by_date[d], field) or 0) >= _SEVERITY_THRESHOLD
        )
        dose_rate = occurrences / len(recent_doses)
        non_dose_rate = (non_dose_hits / len(non_dose_days)) if non_dose_days else 0.0
        if non_dose_rate > 0 and dose_rate < 2 * non_dose_rate:
            continue

        confidence = min(0.5 + 0.1 * occurrences, 0.9)
        month_key = recent_doses[-1].strftime("%Y-%m")
        supporting = json.dumps([
            {"icon_key": "symptom", "label": f"{display} after dose",
             "sublabel": "Within 24h of a logged dose",
             "value": f"{occurrences} of last {len(recent_doses)} dose days"},
            {"icon_key": "calendar", "label": "Dose events analyzed",
             "sublabel": f"{start_date.isoformat()} – {end_date.isoformat()}",
             "value": str(len(dose_dates))},
            {"icon_key": "chart", "label": "On non-dose days",
             "sublabel": "Same symptom, days without a dose",
             "value": f"{non_dose_hits} of {len(non_dose_days)} days" if non_dose_days else "no data"},
        ])
        results.append(GeneratedInsight(
            type=InsightType.ANOMALY,
            severity=InsightSeverity.WARNING,
            title=f"{display} is appearing after dose day",
            description=(
                f"You've logged {display.lower()} within 24 hours after your dose "
                f"on {occurrences} of the last {len(recent_doses)} dose days."
            ),
            explanation=(
                f"Computed from {len(checkins_by_date)} check-ins and {len(dose_dates)} dose days "
                f"between {start_date.isoformat()} and {end_date.isoformat()}. A dose day counts when "
                f"{display.lower()} severity is {_SEVERITY_THRESHOLD}+ on the dose day or the day after."
            ),
            confidence=confidence,
            source_data_refs=json.dumps(
                {"rule": "symptom_after_dose", "symptom": field, "month": month_key}
            ),
            supporting_data=supporting,
        ))
    return results
```

Register in `backend/app/ml/rules/__init__.py`:

```python
from app.ml.rules.weight_trend import weight_trend_rule
from app.ml.rules.weight_plateau import weight_plateau_rule
from app.ml.rules.symptom_after_dose import symptom_after_dose_rule

DEFAULT_RULES = [
    weight_trend_rule,
    weight_plateau_rule,
    symptom_after_dose_rule,
]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest tests/test_rule_symptom_after_dose.py -v`
Expected: 3 passed

- [ ] **Step 5: Full suite + commit**

```bash
cd /Users/gabri/peppy/backend && venv/bin/python -m pytest
git add backend/app/ml/rules backend/tests/test_rule_symptom_after_dose.py
git commit -m "feat(backend): symptom-after-dose anomaly rule"
```

---

### Task 4: Rule — adherence, streaks & milestones

**Files:**
- Create: `backend/app/ml/adherence.py` (shared frequency→expected-dose helper)
- Create: `backend/app/ml/rules/adherence_consistency.py`
- Modify: `backend/app/ml/rules/__init__.py`
- Test: `backend/tests/test_rule_adherence_consistency.py`

**Interfaces:**
- Consumes: `Protocol` (`is_active`, `start_date`), `Compound.frequency`, `DoseLog`, `Checkin`.
- Produces:
  - `app.ml.adherence.doses_per_day(frequency: str) -> Optional[float]` — maps
    frequency strings (case-insensitive; strip spaces/hyphens/underscores):
    `daily→1.0, every other day→0.5, twice weekly→2/7, weekly→1/7,
    every 10 days→0.1, biweekly→1/14, monthly→1/30`; anything else → `None`.
  - `app.ml.adherence.expected_doses(db, user_id, start, end) -> Optional[float]`
    — sums expected compound-dose events over active-protocol compounds with a
    known frequency, clipping each compound to its protocol's inclusive
    `start_date`/`end_date` overlap with the requested window; `None` when there
    is no active, mappable compound with an overlap.
  - `app.ml.adherence.logged_dose_events(db, user_id, start, end) -> int` — counts
    logged compound-dose events for that same active, mappable compound/window
    set. Different compounds on the same date count separately; repeated logs
    for the same compound/date count once. The datetime query is half-open at
    midnight after `end`, and unrelated/inactive protocol or compound logs do
    not count.
  - `adherence_consistency_rule(db, user_id, start_date, end_date) -> list[GeneratedInsight]` emitting:
    1. MILESTONE/INFO "7-day check-in streak" when the 7 most recent consecutive
       days ending at `end_date` all have check-ins. Dedup refs:
       `{"rule": "checkin_streak_7", "start": <streak start iso>}`.
    2. MILESTONE/INFO "4 weeks on protocol" when an active protocol's
       `start_date + 28 days` falls inside the window. Refs:
       `{"rule": "protocol_weeks_4", "protocol": <id str>}`.
    3. SUGGESTION/INFO "Doses are slipping" when over the trailing 14 days
       expected compound-dose events ≥ 2 and logged/expected compound-dose
       events < 0.7. Refs:
       `{"rule": "adherence_low", "window_end": <end_date iso>}`.
- Note: `expected_doses` and `logged_dose_events` are reused together by the
  weekly summary (Task 9); numerator and denominator must remain the same unit.

- [ ] **Step 1: Write the failing tests** — `backend/tests/test_rule_adherence_consistency.py` with the same `_seed`-style helpers as Task 3. Cover: (a) `doses_per_day` mapping incl. unknown→None and case/space variants (`"Twice weekly"`, `"every-other-day"`); (b) streak milestone fires with 7 consecutive check-in days ending at `end_date` and is silent at 6; (c) protocol-anniversary milestone fires when `start_date = end_date - 28 days`; (d) low-adherence suggestion fires with a weekly-frequency compound (expected ≈ 2 over 14 days) and 0 dose logs, and is silent with 2 logs; (e) every emitted insight has non-null `supporting_data` and refs matching the dedup keys above; (f) two compounds logged on the same dates count as separate events while duplicate same-compound/date logs count once; (g) inactive and unmappable compound logs do not count; (h) expected/logged events are clipped to protocol start/end overlap; (i) a log exactly at midnight after `end_date` is excluded.

- [ ] **Step 2: Run to verify failure** — `venv/bin/python -m pytest tests/test_rule_adherence_consistency.py -v` → `ModuleNotFoundError`.

- [ ] **Step 3: Implement** `app/ml/adherence.py`:

```python
# backend/app/ml/adherence.py
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol

_RATES = {
    "daily": 1.0,
    "everyotherday": 0.5,
    "twiceweekly": 2 / 7,
    "weekly": 1 / 7,
    "onceweekly": 1 / 7,
    "every10days": 0.1,
    "biweekly": 1 / 14,
    "monthly": 1 / 30,
}


@dataclass(frozen=True)
class _CompoundDoseWindow:
    protocol_id: UUID
    compound_id: UUID
    start: date
    end: date
    expected: float


def doses_per_day(frequency: str) -> Optional[float]:
    key = "".join(ch for ch in frequency.lower() if ch.isalnum())
    return _RATES.get(key)


async def _compound_dose_windows(
    db: AsyncSession, user_id: UUID, start: date, end: date,
) -> list[_CompoundDoseWindow]:
    rows = await db.execute(
        select(Compound, Protocol.start_date, Protocol.end_date)
        .join(Protocol, Compound.protocol_id == Protocol.id)
        .where(and_(Protocol.user_id == user_id, Protocol.is_active.is_(True)))
    )
    windows = []
    for compound, protocol_start, protocol_end in rows.all():
        rate = doses_per_day(compound.frequency or "")
        if rate is None:
            continue
        overlap_start = max(start, protocol_start)
        overlap_end = min(end, protocol_end) if protocol_end is not None else end
        if overlap_start > overlap_end:
            continue
        windows.append(_CompoundDoseWindow(
            protocol_id=compound.protocol_id,
            compound_id=compound.id,
            start=overlap_start,
            end=overlap_end,
            expected=rate * ((overlap_end - overlap_start).days + 1),
        ))
    return windows


async def expected_doses(
    db: AsyncSession, user_id: UUID, start: date, end: date,
) -> Optional[float]:
    """Expected compound-dose events in each active protocol's window overlap."""
    windows = await _compound_dose_windows(db, user_id, start, end)
    return sum(window.expected for window in windows) if windows else None


async def logged_dose_events(
    db: AsyncSession, user_id: UUID, start: date, end: date,
) -> int:
    """Count eligible compound/date dose events, de-duplicating repeated logs."""
    windows = await _compound_dose_windows(db, user_id, start, end)
    if not windows:
        return 0

    start_at = datetime.combine(start, time.min, tzinfo=timezone.utc)
    end_at = datetime.combine(end + timedelta(days=1), time.min, tzinfo=timezone.utc)
    protocol_ids = {window.protocol_id for window in windows}
    compound_ids = {window.compound_id for window in windows}
    rows = await db.execute(
        select(DoseLog.protocol_id, DoseLog.compound_id, DoseLog.administered_at)
        .where(and_(
            DoseLog.user_id == user_id,
            DoseLog.protocol_id.in_(protocol_ids),
            DoseLog.compound_id.in_(compound_ids),
            DoseLog.administered_at >= start_at,
            DoseLog.administered_at < end_at,
        ))
    )
    windows_by_pair = {
        (window.protocol_id, window.compound_id): window for window in windows
    }
    events = set()
    for protocol_id, compound_id, administered_at in rows.all():
        window = windows_by_pair.get((protocol_id, compound_id))
        administered_date = administered_at.date()
        if window is not None and window.start <= administered_date <= window.end:
            events.add((compound_id, administered_date))
    return len(events)
```

then create `app/ml/rules/adherence_consistency.py`:

```python
# backend/app/ml/rules/adherence_consistency.py
import json
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.adherence import expected_doses, logged_dose_events
from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.insight import InsightSeverity, InsightType
from app.models.protocol import Protocol

_STREAK_LENGTH = 7
_PROTOCOL_MILESTONE_DAYS = 28
_ADHERENCE_WINDOW_DAYS = 14
_ADHERENCE_FLOOR = 0.7
_MIN_EXPECTED = 2.0


async def adherence_consistency_rule(
    db: AsyncSession, user_id: UUID, start_date: date, end_date: date,
) -> list[GeneratedInsight]:
    results: list[GeneratedInsight] = []

    # --- 1. 7-day check-in streak ending at end_date ---
    rows = await db.execute(
        select(Checkin.date).where(
            and_(Checkin.user_id == user_id,
                 Checkin.date > end_date - timedelta(days=_STREAK_LENGTH),
                 Checkin.date <= end_date)
        )
    )
    streak_days = {r[0] for r in rows.all()}
    if len(streak_days) == _STREAK_LENGTH:
        streak_start = end_date - timedelta(days=_STREAK_LENGTH - 1)
        results.append(GeneratedInsight(
            type=InsightType.MILESTONE, severity=InsightSeverity.INFO,
            title="7-day check-in streak",
            description=(
                "You've checked in every day for the last 7 days. "
                "Consistent logging is what makes your insights accurate."
            ),
            explanation=(
                f"Check-ins found for every day from {streak_start.isoformat()} "
                f"to {end_date.isoformat()}."
            ),
            confidence=0.9,
            source_data_refs=json.dumps(
                {"rule": "checkin_streak_7", "start": streak_start.isoformat()}
            ),
            supporting_data=json.dumps([
                {"icon_key": "checkmark", "label": "Check-in streak",
                 "sublabel": f"{streak_start.isoformat()} – {end_date.isoformat()}",
                 "value": "7 of 7 days"},
            ]),
        ))

    # --- 2. Four weeks on protocol ---
    protocols = (await db.execute(
        select(Protocol).where(
            and_(Protocol.user_id == user_id, Protocol.is_active.is_(True))
        )
    )).scalars().all()
    for protocol in protocols:
        milestone_day = protocol.start_date + timedelta(days=_PROTOCOL_MILESTONE_DAYS)
        if start_date <= milestone_day <= end_date:
            results.append(GeneratedInsight(
                type=InsightType.MILESTONE, severity=InsightSeverity.INFO,
                title=f"4 weeks on {protocol.name}",
                description=(
                    f"You've completed 4 weeks on {protocol.name}. That's enough "
                    "history for your trends to start meaning something."
                ),
                explanation=(
                    f"{protocol.name} started {protocol.start_date.isoformat()}; "
                    f"week 4 completed {milestone_day.isoformat()}."
                ),
                confidence=0.9,
                source_data_refs=json.dumps(
                    {"rule": "protocol_weeks_4", "protocol": str(protocol.id)}
                ),
                supporting_data=json.dumps([
                    {"icon_key": "calendar", "label": "Protocol duration",
                     "sublabel": f"Started {protocol.start_date.isoformat()}",
                     "value": "Week 4"},
                ]),
            ))

    # --- 3. Low adherence over trailing 14 days ---
    window_start = end_date - timedelta(days=_ADHERENCE_WINDOW_DAYS - 1)
    expected = await expected_doses(db, user_id, window_start, end_date)
    if expected is not None and expected >= _MIN_EXPECTED:
        logged = await logged_dose_events(db, user_id, window_start, end_date)
        if logged / expected < _ADHERENCE_FLOOR:
            results.append(GeneratedInsight(
                type=InsightType.SUGGESTION, severity=InsightSeverity.INFO,
                title="Doses are slipping",
                description=(
                    f"You've logged {logged} of about {expected:.0f} expected doses "
                    f"over the last {_ADHERENCE_WINDOW_DAYS} days. A reminder or a "
                    "set dose day can help."
                ),
                explanation=(
                    "Expected doses computed from your active protocol's compound "
                    f"frequencies over {window_start.isoformat()} – {end_date.isoformat()}."
                ),
                confidence=0.7,
                source_data_refs=json.dumps(
                    {"rule": "adherence_low", "window_end": end_date.isoformat()}
                ),
                supporting_data=json.dumps([
                    {"icon_key": "chart", "label": "Dose adherence",
                     "sublabel": f"Last {_ADHERENCE_WINDOW_DAYS} days",
                     "value": f"{logged} of {expected:.0f} expected doses"},
                ]),
            ))

    return results
```

Register in `DEFAULT_RULES` after `symptom_after_dose_rule`.

- [ ] **Step 4: Run tests to verify they pass**, then the full suite.

- [ ] **Step 5: Commit**

```bash
git add backend/app/ml/adherence.py backend/app/ml/rules backend/tests/test_rule_adherence_consistency.py
git commit -m "feat(backend): adherence/streak/milestone rule + shared dose-expectation helper"
```

---

### Task 5: Rule — dose-day energy/mood dip

**Files:**
- Create: `backend/app/ml/rules/dose_day_energy_dip.py`
- Modify: `backend/app/ml/rules/__init__.py`
- Test: `backend/tests/test_rule_dose_day_energy_dip.py`

**Interfaces:**
- Produces: `dose_day_energy_dip_rule(db, user_id, start_date, end_date) -> list[GeneratedInsight]`.

**Rule spec:** Dose-window days = dose date + following day. Requires ≥ 3 distinct
dose dates and ≥ 2 check-ins with non-null `energy_level` in each group
(dose-window vs other days). Computes mean energy per group; emits TREND when
`other_mean - dose_mean >= 1.5`: severity INFO for gap < 3.0, WARNING for ≥ 3.0.
Description mentions mood only when the same comparison on `mood` also gaps ≥ 1.5.
Refs: `{"rule": "dose_day_energy_dip", "month": "<YYYY-MM of end_date>"}`.
`supporting_data`: energy on dose days ("2.1 / 10 avg"), energy on other days,
dose days analyzed count.

- [ ] **Step 1: Write failing tests** — cover: fires with energy 2 on dose-window days vs 7 elsewhere across 4 dose dates (assert gap-driven WARNING at ≥3.0 and title "Energy dips on dose day"); silent with < 3 dose dates; silent when gap is 1.0; silent when dose-window days have fewer than 2 energy check-ins.

- [ ] **Step 2: Verify failure.**

- [ ] **Step 3: Implement**

```python
# backend/app/ml/rules/dose_day_energy_dip.py
import json
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import InsightSeverity, InsightType

_MIN_DOSE_DATES = 3
_MIN_GROUP_CHECKINS = 2
_GAP_THRESHOLD = 1.5
_WARNING_GAP = 3.0


def _mean(values: list[int]) -> float:
    return sum(values) / len(values)


async def dose_day_energy_dip_rule(
    db: AsyncSession, user_id: UUID, start_date: date, end_date: date,
) -> list[GeneratedInsight]:
    dose_rows = await db.execute(
        select(DoseLog.administered_at).where(
            and_(DoseLog.user_id == user_id,
                 DoseLog.administered_at >= start_date,
                 DoseLog.administered_at <= end_date + timedelta(days=1))
        )
    )
    dose_dates = sorted({r[0].date() for r in dose_rows.all()})
    if len(dose_dates) < _MIN_DOSE_DATES:
        return []

    dose_window_days = set()
    for d in dose_dates:
        dose_window_days.add(d)
        dose_window_days.add(d + timedelta(days=1))

    checkin_rows = await db.execute(
        select(Checkin).where(
            and_(Checkin.user_id == user_id,
                 Checkin.date >= start_date, Checkin.date <= end_date)
        )
    )
    checkins = checkin_rows.scalars().all()

    def split(field: str) -> tuple[list[int], list[int]]:
        dose_vals, other_vals = [], []
        for c in checkins:
            value = getattr(c, field)
            if value is None:
                continue
            (dose_vals if c.date in dose_window_days else other_vals).append(value)
        return dose_vals, other_vals

    dose_energy, other_energy = split("energy_level")
    if len(dose_energy) < _MIN_GROUP_CHECKINS or len(other_energy) < _MIN_GROUP_CHECKINS:
        return []

    gap = _mean(other_energy) - _mean(dose_energy)
    if gap < _GAP_THRESHOLD:
        return []

    dose_mood, other_mood = split("mood")
    mood_dips = (
        len(dose_mood) >= _MIN_GROUP_CHECKINS
        and len(other_mood) >= _MIN_GROUP_CHECKINS
        and _mean(other_mood) - _mean(dose_mood) >= _GAP_THRESHOLD
    )

    severity = InsightSeverity.WARNING if gap >= _WARNING_GAP else InsightSeverity.INFO
    mood_clause = " Mood shows the same pattern." if mood_dips else ""
    return [GeneratedInsight(
        type=InsightType.TREND,
        severity=severity,
        title="Energy dips on dose day",
        description=(
            f"Your average energy is {_mean(dose_energy):.1f}/10 on dose days "
            f"(and the day after) vs {_mean(other_energy):.1f}/10 on other days."
            f"{mood_clause}"
        ),
        explanation=(
            f"Computed from {len(dose_energy) + len(other_energy)} energy check-ins "
            f"across {len(dose_dates)} dose days between {start_date.isoformat()} "
            f"and {end_date.isoformat()}. Dose window = dose day plus the following day."
        ),
        confidence=min(0.5 + 0.1 * len(dose_dates), 0.9),
        source_data_refs=json.dumps(
            {"rule": "dose_day_energy_dip", "month": end_date.strftime("%Y-%m")}
        ),
        supporting_data=json.dumps([
            {"icon_key": "chart", "label": "Energy on dose days",
             "sublabel": "Dose day + day after",
             "value": f"{_mean(dose_energy):.1f} / 10 avg"},
            {"icon_key": "chart", "label": "Energy on other days",
             "sublabel": None,
             "value": f"{_mean(other_energy):.1f} / 10 avg"},
            {"icon_key": "calendar", "label": "Dose days analyzed",
             "sublabel": f"{start_date.isoformat()} – {end_date.isoformat()}",
             "value": str(len(dose_dates))},
        ]),
    )]
```

Register in `DEFAULT_RULES` after `adherence_consistency_rule`.

- [ ] **Step 4: Tests pass + full suite.**

- [ ] **Step 5: Commit** — `git commit -m "feat(backend): dose-day energy dip rule"`.

---

### Task 6: Longitudinal snapshot builder

**Files:**
- Create: `backend/app/ml/snapshot.py`
- Test: `backend/tests/test_snapshot.py`

**Interfaces:**
- Consumes: `Checkin`, `DoseLog`, `Protocol`/`Compound`, `LabResult` (see `app/models/lab.py` — read it first and include panel/marker fields it actually has), `OnboardingProfile`.
- Produces: `async def build_longitudinal_snapshot(db, user_id, start_date, end_date) -> dict` — the single organized data picture both narrator entry points consume (spec: Product Principle #1/#2). Shape:

```python
{
  "window": {"start": "2026-06-01", "end": "2026-06-30"},
  "profile": {"age": 32, "goals": [...], "peptides": [...], "workout_days_per_week": 3},  # only non-null keys
  "protocol": {"name": ..., "started": ..., "compounds": [{"name","dose","unit","frequency","route"}]} | None,
  "checkins": [{"date","weight_kg","energy","mood","sleep_quality","appetite",
                "symptoms": {"nausea": 4, ...non-zero only}, "notes": "..."} ...],  # date-ascending
  "doses": [{"date","compound","dose","unit","route","notes"} ...],
  "labs": [{"date","panel","markers":[...]} ...],  # [] when none
  "aggregates": {"checkin_count": N, "dose_count": N,
                 "weight_first": x, "weight_last": y,
                 "avg_energy": x, "avg_mood": x, "avg_sleep_quality": x},  # null-safe
}
```

All values JSON-serializable (dates as ISO strings). Free-text notes ARE included
(per spec privacy decision). No user id/email/display_name anywhere in the snapshot.

- [ ] **Step 1: Write failing tests** — seed a user with profile, active protocol + compound, 3 check-ins (one with notes + nausea), 2 dose logs; assert structure above, ascending checkin order, symptom dict contains only non-zero severities, aggregates computed, and that the snapshot contains no email/display_name string anywhere (`"svc@test.com" not in json.dumps(snapshot)`).
- [ ] **Step 2: Verify failure.**
- [ ] **Step 3: Implement** with simple selects (reuse query shapes from Tasks 3–5). Read `app/models/lab.py` first and map its real columns; if labs are heavier than a simple panel/markers shape, include `{"date", "panel_type"}` plus whatever marker list the model exposes.
- [ ] **Step 4: Tests pass + full suite.**
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): longitudinal snapshot builder for AI narratives"`.

---

### Task 7: Narrator — Claude narrative layer with template fallback

**Files:**
- Modify: `backend/requirements.txt` (add `anthropic>=0.116.0` under `# ML`)
- Modify: `backend/app/config.py`
- Create: `backend/app/ml/narrator.py`
- Test: `backend/tests/test_narrator.py`

**Interfaces:**
- Consumes: `GeneratedInsight` list + snapshot dict (Task 6).
- Produces:

```python
class Narrator:
    def __init__(self, settings: Settings | None = None, client: "anthropic.AsyncAnthropic | None" = None): ...
    @property
    def enabled(self) -> bool: ...  # api key present
    async def enrich_insight_descriptions(self, candidates, snapshot) -> Optional[list[str]]
    async def write_summary_narrative(self, stats: dict, snapshot: dict) -> Optional[dict]
    # -> {"narrative": str, "what_to_watch": [{"title","detail"}], "provider_questions": [str]}
```

Both return `None` on ANY failure (missing key, API error, timeout, malformed/
mismatched JSON) — callers fall back to templated text. Settings additions:
`anthropic_api_key: str = ""`, `insight_narrative_model: str = "claude-haiku-4-5"`,
`summary_narrative_model: str = "claude-sonnet-5"`.

- [ ] **Step 1: Install the SDK**

Run: `cd /Users/gabri/peppy/backend && venv/bin/pip install "anthropic>=0.116.0"` and add the line to `requirements.txt`.

- [ ] **Step 2: Write the failing tests**

Tests inject a fake client (never the real SDK network path):

```python
# backend/tests/test_narrator.py
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.config import Settings
from app.ml.insights_engine import GeneratedInsight
from app.ml.narrator import Narrator
from app.models.insight import InsightSeverity, InsightType


def _candidate(title="Weight trending down"):
    return GeneratedInsight(
        type=InsightType.TREND, severity=InsightSeverity.INFO, title=title,
        description="template description", explanation="because data",
        confidence=0.7,
    )


def _fake_client(payload: dict):
    block = SimpleNamespace(type="text", text=json.dumps(payload))
    response = SimpleNamespace(content=[block], stop_reason="end_turn")
    client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))
    return client


def _settings():
    return Settings(anthropic_api_key="test-key", debug=True)


@pytest.mark.asyncio
async def test_disabled_without_api_key():
    narrator = Narrator(settings=Settings(debug=True))
    assert narrator.enabled is False
    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None


@pytest.mark.asyncio
async def test_enrich_returns_descriptions_in_order():
    client = _fake_client({"descriptions": ["polished one", "polished two"]})
    narrator = Narrator(settings=_settings(), client=client)
    out = await narrator.enrich_insight_descriptions([_candidate("a"), _candidate("b")], {"window": {}})
    assert out == ["polished one", "polished two"]
    kwargs = client.messages.create.await_args.kwargs
    assert kwargs["model"] == "claude-haiku-4-5"
    assert "output_config" in kwargs and "effort" not in kwargs.get("output_config", {})


@pytest.mark.asyncio
async def test_enrich_falls_back_on_count_mismatch():
    client = _fake_client({"descriptions": ["only one"]})
    narrator = Narrator(settings=_settings(), client=client)
    assert await narrator.enrich_insight_descriptions([_candidate("a"), _candidate("b")], {}) is None


@pytest.mark.asyncio
async def test_enrich_falls_back_on_api_error():
    client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(side_effect=RuntimeError("boom"))))
    narrator = Narrator(settings=_settings(), client=client)
    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None


@pytest.mark.asyncio
async def test_summary_narrative_uses_sonnet_and_parses():
    payload = {"narrative": "Great week.",
               "what_to_watch": [{"title": "Nausea after dose day", "detail": "3 of 4 this week"}],
               "provider_questions": ["Is the nausea pattern expected?"]}
    client = _fake_client(payload)
    narrator = Narrator(settings=_settings(), client=client)
    out = await narrator.write_summary_narrative({"weight_delta_kg": -1.0}, {"window": {}})
    assert out == payload
    assert client.messages.create.await_args.kwargs["model"] == "claude-sonnet-5"
```

- [ ] **Step 3: Verify failure** — `venv/bin/python -m pytest tests/test_narrator.py -v` → `ModuleNotFoundError: app.ml.narrator`.

- [ ] **Step 4: Implement**

Add the three settings fields to `Settings` in `app/config.py` (under a
`# AI narratives` comment, near External APIs).

```python
# backend/app/ml/narrator.py
"""Claude narrative layer.

Rules compute every number; this module only turns confirmed findings into
prose. Any failure returns None and callers ship the rule-templated text —
generation never blocks on the LLM.
"""
import json
import logging
from typing import Optional, Sequence

import anthropic

from app.config import Settings, get_settings
from app.ml.insights_engine import GeneratedInsight

logger = logging.getLogger(__name__)

_GUARDRAILS = (
    "You write short, warm, plain-English health observations for the peppy app. "
    "Repeat numbers exactly as given in the input — never invent, recompute, or round them differently. "
    "Never give medical advice or dosing instructions; at most suggest discussing with a healthcare provider. "
    "Sentence case, no exclamation marks, no emoji, second person ('you')."
)

_ENRICH_SCHEMA = {
    "type": "object",
    "properties": {"descriptions": {"type": "array", "items": {"type": "string"}}},
    "required": ["descriptions"],
    "additionalProperties": False,
}

_SUMMARY_SCHEMA = {
    "type": "object",
    "properties": {
        "narrative": {"type": "string"},
        "what_to_watch": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"title": {"type": "string"}, "detail": {"type": "string"}},
                "required": ["title", "detail"],
                "additionalProperties": False,
            },
        },
        "provider_questions": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["narrative", "what_to_watch", "provider_questions"],
    "additionalProperties": False,
}


class Narrator:
    def __init__(self, settings: Optional[Settings] = None,
                 client: Optional[anthropic.AsyncAnthropic] = None):
        self._settings = settings or get_settings()
        self._client = client
        if self._client is None and self._settings.anthropic_api_key:
            self._client = anthropic.AsyncAnthropic(api_key=self._settings.anthropic_api_key)

    @property
    def enabled(self) -> bool:
        return self._client is not None

    async def enrich_insight_descriptions(
        self, candidates: Sequence[GeneratedInsight], snapshot: dict,
    ) -> Optional[list[str]]:
        """One batched call: rewrite each candidate's description. Order-preserving."""
        if not self.enabled or not candidates:
            return None
        findings = [
            {"title": c.title, "template_description": c.description,
             "explanation": c.explanation,
             "supporting_data": json.loads(c.supporting_data) if c.supporting_data else None}
            for c in candidates
        ]
        prompt = (
            "Rewrite each finding's description as one or two plain-English sentences "
            "(the 'observation' a user reads on a card). Return exactly "
            f"{len(candidates)} descriptions in the same order.\n\n"
            f"FINDINGS:\n{json.dumps(findings, indent=2)}\n\n"
            f"USER DATA SNAPSHOT (context only — numbers come from FINDINGS):\n"
            f"{json.dumps(snapshot, indent=2)}"
        )
        try:
            response = await self._client.messages.create(
                model=self._settings.insight_narrative_model,
                max_tokens=2048,
                system=_GUARDRAILS,
                output_config={"format": {"type": "json_schema", "schema": _ENRICH_SCHEMA}},
                messages=[{"role": "user", "content": prompt}],
            )
            text = next(b.text for b in response.content if b.type == "text")
            descriptions = json.loads(text)["descriptions"]
            if len(descriptions) != len(candidates) or not all(
                isinstance(d, str) and d.strip() for d in descriptions
            ):
                logger.warning("narrator: enrichment shape mismatch, falling back")
                return None
            return descriptions
        except Exception:
            logger.warning("narrator: enrichment failed, falling back", exc_info=True)
            return None

    async def write_summary_narrative(self, stats: dict, snapshot: dict) -> Optional[dict]:
        """Weekly summary narrative. what_to_watch may only rephrase stats/snapshot facts."""
        if not self.enabled:
            return None
        prompt = (
            "Write the AI weekly summary for this user.\n"
            "- narrative: one encouraging sentence about the week (like 'Great progress. "
            "You're trending in the right direction.').\n"
            "- what_to_watch: up to 3 items drawn ONLY from patterns visible in the stats/snapshot "
            "(rephrase, never invent numbers).\n"
            "- provider_questions: up to 3 questions the user could ask their healthcare provider.\n\n"
            f"WEEK STATS (authoritative numbers):\n{json.dumps(stats, indent=2)}\n\n"
            f"USER DATA SNAPSHOT:\n{json.dumps(snapshot, indent=2)}"
        )
        try:
            response = await self._client.messages.create(
                model=self._settings.summary_narrative_model,
                max_tokens=2048,
                system=_GUARDRAILS,
                output_config={"format": {"type": "json_schema", "schema": _SUMMARY_SCHEMA}},
                messages=[{"role": "user", "content": prompt}],
            )
            text = next(b.text for b in response.content if b.type == "text")
            payload = json.loads(text)
            if not isinstance(payload.get("narrative"), str):
                return None
            return payload
        except Exception:
            logger.warning("narrator: summary narrative failed, falling back", exc_info=True)
            return None
```

Also add `ANTHROPIC_API_KEY=` to `backend/.env.example` if that file exists, and a
one-line note in `backend/README.md` ("Optional: set ANTHROPIC_API_KEY to enable
AI-written insight narratives; without it the app uses templated text").

- [ ] **Step 5: Tests pass + full suite + commit**

```bash
cd /Users/gabri/peppy/backend && venv/bin/python -m pytest
git add backend/requirements.txt backend/app/config.py backend/app/ml/narrator.py backend/tests/test_narrator.py backend/README.md
git commit -m "feat(backend): Claude narrator layer with wholesale template fallback"
```

---

### Task 8: Generation runner + event-driven triggers + generate-if-stale

**Files:**
- Create: `backend/app/services/insight_generation.py`
- Modify: `backend/app/api/routes/checkins.py` (POST)
- Modify: `backend/app/api/routes/dose_logs.py` (POST)
- Modify: `backend/app/api/routes/insights.py` (list route + refactor `/generate`)
- Test: `backend/tests/test_insight_generation.py`

**Interfaces:**
- Produces:

```python
# app/services/insight_generation.py
STALENESS_WINDOW = timedelta(hours=6)

async def run_generation(db, user_id, start_date=None, end_date=None,
                         narrator: Narrator | None = None) -> dict:
    """Engine -> dedup -> narrator enrichment (best-effort) -> persist -> ALERT push
    -> stamp users.last_insight_run_at. Returns {"insights_generated": int,
    "types_breakdown": dict}. Defaults to trailing 30 days."""

def is_stale(user) -> bool  # last_insight_run_at is None or older than STALENESS_WINDOW

async def run_generation_in_background(user_id: UUID) -> None:
    """Opens its own session via module-level `session_factory` (defaults to
    app.database.async_session_maker; tests monkeypatch it) and calls run_generation."""
```

- Consumes: `InsightsEngine`, `InsightService`, `NotificationService` (mirror the existing ALERT-push behavior in `app/api/routes/insights.py:209`), `build_longitudinal_snapshot`, `Narrator`.
- Route changes:
  - `POST /checkins` and `POST /dose-logs`: add `background_tasks: BackgroundTasks` parameter; after the successful service call add `background_tasks.add_task(run_generation_in_background, current_user.id)`.
  - `GET /insights`: add `background_tasks: BackgroundTasks`; before returning, `if is_stale(current_user): background_tasks.add_task(run_generation_in_background, current_user.id)`.
  - `POST /insights/generate` (sync path): replace its inline candidate loop with a call to `run_generation(db, ...)` so both paths share persistence/enrichment. Keep the `run_async` job branch untouched (dormant, out of scope).

- [ ] **Step 1: Write failing tests** — `backend/tests/test_insight_generation.py`:
  - `run_generation` over Task 3's seed data creates the symptom insight with template text when narrator is disabled, stamps `last_insight_run_at`, and a second run creates nothing (dedup).
  - `run_generation` with a Narrator built on the Task 7 fake client persists the LLM description ("polished one") instead of the template.
  - `is_stale` true for `None`, true for now-7h, false for now-1h.
  - Route test: monkeypatch `app.services.insight_generation.session_factory` to the test session factory, POST a check-in via the `client` fixture, then GET `/api/v1/insights` and assert generation ran (httpx `ASGITransport` executes FastAPI background tasks after the response). If the seeded data shouldn't fire any rule, assert `last_insight_run_at` got stamped instead.
- [ ] **Step 2: Verify failure.**
- [ ] **Step 3: Implement.** `run_generation` filters candidates through `exists_matching` FIRST, then enriches only new ones (one batched call), then persists with `supporting_data`, sends the ALERT push exactly as the current route does, stamps the user row, commits. `run_generation_in_background` wraps it in `async with session_factory() as db:` with a broad try/except that logs (a background failure must never propagate).
- [ ] **Step 4: Tests pass + full suite** (verify the existing `/generate` route tests, if any, still pass after the refactor).
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): event-driven insight generation with LLM enrichment and staleness trigger"`.

---

### Task 9: Weekly summary — service, caching, endpoint

**Files:**
- Create: `backend/app/services/weekly_summary.py`
- Modify: `backend/app/api/schemas/insight.py` (summary schemas)
- Modify: `backend/app/api/routes/insights.py` (new GET route)
- Test: `backend/tests/test_weekly_summary.py`

**Interfaces:**
- Produces:

```python
def completed_week_bounds(today: date) -> tuple[date, date]:
    """Monday..Sunday of the most recently COMPLETED calendar week."""

async def get_or_create_weekly_summary(db, user_id, narrator=None, today=None) -> Optional[dict]:
    """Search back up to 8 completed weeks for the latest with >=3 check-ins.
    Cache hit -> stored payload. Miss -> compute stats, call narrator (Sonnet),
    persist WeeklySummary ONLY when narrative succeeded (model_used = summary model)
    or narrator disabled (model_used=None, stats-only payload cached is NOT allowed
    either — recompute when narrator comes online: only cache when narrative is
    non-null). Returns payload dict or None when no qualifying week."""
```

- Payload dict / response schema:

```python
class WeeklySummaryHero(BaseModel):
    weight_delta_kg: Optional[float]; weight_from_kg: Optional[float]; weight_to_kg: Optional[float]

class WeeklySummaryMetric(BaseModel):
    key: str      # "sleep_quality" | "dose_adherence" | "checkins" | "energy"
    label: str; value: str; detail: Optional[str] = None; positive: Optional[bool] = None

class WeeklyWatchItem(BaseModel):
    title: str; detail: str

class WeeklySummaryPayload(BaseModel):
    week_start: date; week_end: date
    hero: WeeklySummaryHero
    weight_series: list[dict]        # [{"date": iso, "weight_kg": float}]
    what_changed: list[WeeklySummaryMetric]   # only metrics with data
    what_to_watch: list[WeeklyWatchItem]      # empty when narrative fell back
    provider_questions: list[str]             # empty when narrative fell back
    narrative: Optional[str]

class WeeklySummaryEnvelope(BaseModel):
    available: bool
    summary: Optional[WeeklySummaryPayload] = None
```

- Stats computed deterministically (no LLM): hero weight delta = mean weight this
  week minus mean weight prior week (None when prior week has no weights);
  what_changed builds from: avg sleep_quality delta, dose adherence % via
  `expected_doses` vs `logged_dose_events` (both Task 4, with identical active
  mappable compound and protocol-overlap semantics), check-ins "N of 7",
  avg energy delta. Skip any metric with no data.
- Route in `insights.py` (place ABOVE `get_insight` for readability):

```python
@router.get("/summary/weekly", response_model=WeeklySummaryEnvelope)
async def get_weekly_summary(current_user: CurrentUser, db: ...):
    payload = await get_or_create_weekly_summary(db, current_user.id, narrator=Narrator())
    if payload is None:
        return WeeklySummaryEnvelope(available=False)
    return WeeklySummaryEnvelope(available=True, summary=payload)
```

- [X] **Step 1: Write failing tests** — cover: `completed_week_bounds` for a Wednesday and for a Monday (must return the PRIOR full week); no qualifying week (<3 check-ins everywhere) → None/`available: false`; qualifying week computes hero delta + metrics with seeded two weeks of check-ins/doses; narrator success caches one `WeeklySummary` row and a second call does NOT call the narrator again (assert fake client `create` awaited once); narrator failure returns stats payload with `narrative=None` and does NOT cache; route returns envelope JSON with snake_case fields.
- [X] **Step 2: Verify failure.**
- [X] **Step 3: Implement.** Cache lookup by `(user_id, week_start)`. When cached, return `json.loads(row.payload)`. When narrative succeeds, merge `what_to_watch`/`provider_questions`/`narrative` into the payload and persist. Keep everything JSON-serializable.
- [X] **Step 4: Tests pass + full backend suite.**
- [X] **Step 5: Commit** — `git commit -m "feat(backend): cached AI weekly summary endpoint"`.

---

### Task 10: iOS — API models + weekly summary endpoint + decoding tests

**Files:**
- Modify: `ios/peppy/Core/Network/APIModels.swift` (rewrite `Insight`, add supporting/summary models)
- Modify: `ios/peppy/Core/Network/Endpoint.swift` (add `getWeeklySummary`)
- Test: `ios/peppy/peppyTests/InsightAPIModelsTests.swift` (new file — register in pbxproj under peppyTests Sources)

**Interfaces:**
- Produces (replaces the stale `Insight` struct, which does NOT match the backend today):

```swift
struct InsightSupportingItem: Codable, Equatable, Hashable {
    let iconKey: String
    let label: String
    let sublabel: String?
    let value: String

    enum CodingKeys: String, CodingKey {
        case label, sublabel, value
        case iconKey = "icon_key"
    }
}

struct Insight: Codable, Identifiable, Equatable {
    let id: UUID
    let type: String            // anomaly | trend | suggestion | milestone
    let severity: String        // info | warning | alert
    let title: String
    let description: String     // plain-English observation (LLM or template)
    let explanation: String     // deterministic "why peppy noticed this"
    let confidence: Double      // 0...1
    let createdAt: Date
    let readAt: Date?
    let dismissedAt: Date?
    let snoozedUntil: Date?
    let actionTaken: String?
    let actionNotes: String?
    let supportingData: [InsightSupportingItem]?

    enum CodingKeys: String, CodingKey {
        case id, type, severity, title, description, explanation, confidence
        case createdAt = "created_at"
        case readAt = "read_at"
        case dismissedAt = "dismissed_at"
        case snoozedUntil = "snoozed_until"
        case actionTaken = "action_taken"
        case actionNotes = "action_notes"
        case supportingData = "supporting_data"
    }

    var isUnread: Bool { readAt == nil && dismissedAt == nil }
}

struct WeeklySummaryHero: Codable, Equatable { let weightDeltaKg, weightFromKg, weightToKg: Double? /* snake_case keys */ }
struct WeeklySummaryMetric: Codable, Equatable, Identifiable { let key, label, value: String; let detail: String?; let positive: Bool?; var id: String { key } }
struct WeeklyWatchItem: Codable, Equatable { let title, detail: String }
struct WeeklyWeightPoint: Codable, Equatable { let date: String; let weightKg: Double /* "weight_kg" */ }
struct WeeklySummaryPayload: Codable, Equatable { let weekStart, weekEnd: String; let hero: WeeklySummaryHero; let weightSeries: [WeeklyWeightPoint]; let whatChanged: [WeeklySummaryMetric]; let whatToWatch: [WeeklyWatchItem]; let providerQuestions: [String]; let narrative: String? }
struct WeeklySummaryEnvelope: Codable, Equatable { let available: Bool; let summary: WeeklySummaryPayload? }
```

(Write full CodingKeys for every snake_case field; `week_start`/`week_end` decode
as String — they are `yyyy-MM-dd` date-only values, which `.iso8601` cannot decode
as `Date`; same reason `weight_series.date` is a String.)
- `Endpoint`: add `case getWeeklySummary` → path `"/insights/summary/weekly"`, method GET, no body/query.
- Check for existing references to the old `Insight` fields (`body`, `isRead`) with `grep -rn "\.body\b\|isRead" ios/peppy --include="*.swift"` scoped to Insight usages — the placeholder tab never used them, but fix any compile break the rewrite causes.
- `created_at` datetimes may carry microseconds — if `.iso8601` decoding fails in tests, reuse the existing `APIDateOnly`/custom decoding approach already present in APIModels.swift for `DoseLog`.

**Steps:**
- [X] **Step 1: Write failing decoding tests** — `InsightAPIModelsTests.swift`: decode a backend-shaped insight JSON fixture (all fields incl. `supporting_data` array and nulls) with `JSONDecoder` configured like `APIClient` (`.iso8601`); decode a `WeeklySummaryEnvelope` fixture with `available: true` and one with `available: false, summary: null`; assert `Endpoint.getWeeklySummary.path == "/insights/summary/weekly"`. Register the test file in project.pbxproj (peppyTests group + Sources phase).
- [X] **Step 2: Build to verify failure** — `cd /Users/gabri/peppy/ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build-for-testing` → compile error (models missing).
- [X] **Step 3: Implement** the models + endpoint case (add to the GET list in the `method` switch and no-op in body/query switches).
- [X] **Step 4: Run tests** — `... xcodebuild test -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/InsightAPIModelsTests` → pass.
- [X] **Step 5: Commit** — `git add ios/peppy/Core/Network ios/peppy/peppyTests/InsightAPIModelsTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj && git commit -m "feat(ios): backend-accurate insight models + weekly summary endpoint"`.

---

### Task 11: iOS — InsightsStore + Dependencies wiring

**Files:**
- Create: `ios/peppy/Features/Insights/Stores/InsightsStore.swift`
- Modify: `ios/peppy/App/Dependencies.swift`
- Test: `ios/peppy/peppyTests/InsightsStoreTests.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj` (register both files)

**Interfaces:**
- Produces (mirrors `ProtocolStore` — token-guarded async loads, `message(for:)` error mapping copied from ProtocolStore):

```swift
@MainActor
@Observable
final class InsightsStore {
    private let api: APIClientProtocol
    private(set) var insights: [Insight] = []
    private(set) var weekly: WeeklySummaryEnvelope?
    private(set) var isLoading = false
    var errorMessage: String?

    var unreadCount: Int { insights.filter(\.isUnread).count }

    init(api: APIClientProtocol)
    func loadInsights(force: Bool = false) async      // GET .getInsights(unreadOnly: nil, type: nil, severity: nil); dedupe by hasLoaded flag like ProtocolStore
    func loadWeeklySummary() async                    // GET .getWeeklySummary
    func markRead(_ id: UUID) async                   // POST read, replace element with response
    @discardableResult
    func act(_ id: UUID, action: String) async -> Bool // POST action; on success: replace element; for "dismiss"/"snooze" also remove from `insights` (server hides them); returns success
}
```

- Filtering by type happens client-side in the list ViewModel (Task 12) — the store always holds the unfiltered default list so `unreadCount` powers the tab badge.
- `Dependencies`: add `let insightsStore: InsightsStore`, init param, and `InsightsStore(api: api)` construction in both `live()` and `mock()`.
- Add fixtures for previews/tests as an extension in the store file:

```swift
extension Insight {
    static func fixture(
        id: UUID = UUID(), type: String = "trend", severity: String = "info",
        title: String = "Weight trending down",
        description: String = "Your average weekly weight change is -0.4 kg.",
        explanation: String = "Computed from 5 weight check-ins.",
        confidence: Double = 0.83, createdAt: Date = Date(),
        readAt: Date? = nil, supportingData: [InsightSupportingItem]? = [
            .init(iconKey: "weight", label: "Weight trend", sublabel: "Compared to prior 2 weeks", value: "-0.4 kg / week")
        ]
    ) -> Insight { ... }
}
```

**Steps:**
- [X] **Step 1: Write failing tests** — `InsightsStoreTests` (@MainActor, MockAPIClient): load populates + unreadCount counts only unread; second `loadInsights()` without force doesn't re-hit API (assert `requestLog` count); `markRead` replaces element (mock returns updated insight for `POST /insights/<id>/read` via `setMockResponse(_, for: endpoint)`); `act(dismiss)` removes the row; API error sets `errorMessage` and keeps prior list.
- [X] **Step 2: Verify failure** (compile error), register files in pbxproj as you add them.
- [X] **Step 3: Implement store + Dependencies wiring.**
- [X] **Step 4: Run** `-only-testing:peppyTests/InsightsStoreTests` + full `xcodebuild test` to catch Dependencies init breakage in other tests.
- [X] **Step 5: Commit** — `git commit -m "feat(ios): InsightsStore with unread count, actions, weekly summary"`.

---

### Task 12: iOS — Insights list screen, filters, empty state, tab badge

**Files:**
- Create: `ios/peppy/Features/Insights/Models/InsightModels.swift`
- Create: `ios/peppy/Features/Insights/ViewModels/InsightsListViewModel.swift`
- Create: `ios/peppy/Features/Insights/Views/InsightCardView.swift`
- Create: `ios/peppy/Features/Insights/Views/InsightsListView.swift`
- Modify: `ios/peppy/App/MainTabView.swift` (real tab + badge)
- Test: `ios/peppy/peppyTests/InsightsListViewModelTests.swift`
- Modify: `project.pbxproj` (5 new files)

**Interfaces (InsightModels.swift):**

```swift
enum InsightRoute: Hashable {
    case detail(UUID)
    case weeklySummary
}

enum InsightTypeFilter: String, CaseIterable, Identifiable {
    case all, trends, anomalies, suggestions, milestones
    var id: String { rawValue }
    var title: String { ... }                    // "All", "Trends", ...
    var matchesType: String? { ... }             // nil for .all; "trend", "anomaly", "suggestion", "milestone"
}

// Presentation mapping (single source of truth for both screens)
extension Insight {
    var typeBadgeStyle: PepBadgeStyle { ... }    // trend→.success, anomaly→.warning, suggestion→.info, milestone→.neutral
    var typeIcon: String { ... }                 // trend→"chart.line.uptrend.xyaxis", anomaly→"exclamationmark.triangle", suggestion→"lightbulb", milestone→"flag.checkered"
    var typeDisplayName: String { ... }          // "Trend", "Anomaly", ...
    var confidenceLabel: String { ... }          // >=0.75 "High", >=0.5 "Medium", else "Low"
    var confidenceColor: Color { ... }           // High→.pepSuccess, Medium→.pepWarning, Low→.pepTextSecondary
    var severityIcon: String { ... }             // info→"info.circle", warning→"exclamationmark.triangle", alert→"bell.badge"
}
```

**ViewModel:**

```swift
@MainActor
@Observable
final class InsightsListViewModel {
    private let store: InsightsStore
    var filter: InsightTypeFilter = .all
    var filtered: [Insight] { ... }              // store.insights filtered by filter.matchesType
    var unread: [Insight] { filtered.filter(\.isUnread) }
    var earlier: [Insight] { filtered.filter { !$0.isUnread } }
    var showsSummaryCard: Bool { store.weekly?.available == true }
    init(store: InsightsStore)
    func onAppear() async   // parallel: store.loadInsights() + store.loadWeeklySummary()
    func refresh() async    // force reload (server does generate-if-stale)
}
```

**View composition (match `insights-list.png` exactly):** ScrollView with
`.refreshable`; header row (PeppyLogo wordmark leading — reuse whatever header
pattern DashboardView uses — check `DashboardView.swift` first and copy its
header); title `Insights` (28pt semibold, `.pepTextPrimary`) with unread-count
chip (rust-muted capsule) shown only when unreadCount > 0; subtitle
"AI-powered insights from your check-ins and protocol data." (13pt,
`.pepTextSecondary`); horizontal `ScrollView` of `PepSelectionChip`s bound to
`viewModel.filter` (no checkmark needed — PepSelectionChip shows one when
selected; acceptable deviation); weekly-summary entry card (PepCard: sparkle
icon, "AI weekly summary", week range from payload, chevron →
`NavigationLink(value: InsightRoute.weeklySummary)`); "Unread" section header +
`InsightCardView` per unread insight (`NavigationLink(value: .detail(id))`);
"Earlier" section for the rest; privacy footer PepCard (lock icon in rust
circle, bold line "Your data is private and secure.", body: the exact copy from
Global Constraints); empty state when `store.insights.isEmpty && !isLoading`:
`PepEmptyState(icon: "sparkles", title: "peppy is learning your patterns",
message: "Keep checking in daily and logging doses. peppy looks for trends,
anomalies, and milestones in your data — your first insight usually appears
within a week.")`; error toast via existing `PepToast` pattern (copy usage from
CheckinView/DashboardView).

`InsightCardView` per Figma card anatomy: HStack — 56pt tinted circle
(`typeBadgeStyle` muted color) with `typeIcon`; VStack — top row `PepBadge(text:
typeDisplayName, style: typeBadgeStyle)` + spacer + "New" `PepBadge(style:
.error)` when unread; title (17pt semibold); description (13pt secondary,
2-line limit); divider; bottom row calendar icon + formatted `createdAt` +
spacer + "Confidence: \(confidenceLabel)" in `confidenceColor` + chevron.

**MainTabView changes:** `InsightsTab` becomes:

```swift
struct InsightsTab: View {
    @Environment(\.dependencies) private var deps
    var body: some View {
        InsightsListView(store: deps.insightsStore)
    }
}
```

(Task 15 changes this call site to also pass the navigation coordinator.)

and the tab item gains `.badge(deps.insightsStore.unreadCount)` (badge(0) hides
automatically). `InsightsListView` owns a `NavigationStack` bound to the
coordinator path added in Task 15 — until Task 15 lands, use
`@State private var path: [InsightRoute] = []` and leave a `// Task 15 swaps
this to the shared coordinator` comment, with `navigationDestination(for:
InsightRoute.self)` switching to `InsightDetailView` / `WeeklySummaryView`
(stub `Text("...")` destinations until Tasks 13–14 land, replaced there).

**Steps:**
- [X] **Step 1: Failing VM tests** — filter mapping (`.anomalies` shows only type "anomaly"), unread/earlier sectioning, `showsSummaryCard` false when envelope unavailable, `onAppear` triggers both loads (assert MockAPIClient `requestLog` contains both endpoints).
- [X] **Step 2: Verify failure; register the 5 files in pbxproj.**
- [X] **Step 3: Implement models → VM → card → list → tab.** Add a `#Preview` for `InsightsListView` using `.mock()` dependencies with fixture insights preloaded. (Note: real component enum is `PepBadgeType`, not `PepBadgeStyle`.)
- [X] **Step 4: Run** `-only-testing:peppyTests/InsightsListViewModelTests`, then full build.
- [X] **Step 5: Commit** — `git commit -m "feat(ios): insights list screen with filters, sections, empty state, tab badge"`.

---

### Task 13: iOS — Insight detail screen with confidence ring + actions

**Files:**
- Create: `ios/peppy/Features/Insights/ViewModels/InsightDetailViewModel.swift`
- Create: `ios/peppy/Features/Insights/Views/ConfidenceRing.swift`
- Create: `ios/peppy/Features/Insights/Views/InsightDetailView.swift`
- Modify: `ios/peppy/Features/Insights/Views/InsightsListView.swift` (real destination)
- Test: `ios/peppy/peppyTests/InsightDetailViewModelTests.swift`
- Modify: `project.pbxproj` (4 new files)

**Interfaces:**

```swift
@MainActor
@Observable
final class InsightDetailViewModel {
    private let store: InsightsStore
    let insightID: UUID
    var insight: Insight? { store.insights.first { $0.id == insightID } ?? loadedFallback }
    private(set) var loadedFallback: Insight?   // fetched via .getInsight when not in store (deep link)
    private(set) var isActing = false
    var didCompleteAction = false               // view pops when this flips
    init(store: InsightsStore, api: APIClientProtocol, insightID: UUID)
    func onAppear() async                       // fetch fallback if needed, then store.markRead(insightID) once
    func snooze() async; func dismissInsight() async; func accept() async
    // each: isActing guard -> store.act(id, action:) -> didCompleteAction = success
}
```

```swift
struct ConfidenceRing: View {
    let confidence: Double  // 0...1
    // ZStack: Circle().stroke(Color.pepBorder, lineWidth: 5)
    //       + Circle().trim(from: 0, to: confidence).stroke(ringColor, style: .init(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
    //       + Text("\(Int(confidence * 100))%") 13pt semibold
    // ringColor = confidence >= 0.75 ? .pepSuccess : confidence >= 0.5 ? .pepWarning : .pepTextTertiary
}
```

**View composition (match `insight-detail.png`):** ScrollView content — type
`PepBadge`; large title (28pt semibold); timestamp line; **stat card** (PepCard,
3 equal columns divided by 1pt `pepBorder` lines): "Type" (typeIcon in tinted
circle + typeDisplayName), "Severity" (severityIcon + capitalized severity),
"Confidence" (ConfidenceRing 56pt + confidenceLabel in confidenceColor);
**observation card** (PepCard: quote icon in success-muted circle, header
"Plain-English observation", body = `insight.description`); **why card**
(PepCard: sparkle icon in rust-muted circle, header "Why peppy noticed this",
body = `insight.explanation`; divider; "Supporting references" 15pt semibold;
one row per `supportingData` item: 36pt tinted rounded-square with icon
(map iconKey: weight→"chart.line.downtrend.xyaxis", sleep→"moon", calendar→
"calendar", checkmark→"checkmark.circle", symptom→"exclamationmark.triangle",
chart→"chart.bar", default→"circle"), label (15pt medium) + sublabel (12pt
secondary), spacer, value in rust/semantic color, chevron **rendered but
non-navigating** this slice); **disclaimer banner** (info-muted background,
info icon, "Informational only, not medical advice" + body per Figma);
**bottom action bar** pinned via `safeAreaInset(edge: .bottom)`: three buttons —
Snooze ("Remind me later" subtitle) and Dismiss ("Not helpful") as bordered
cards, Accept ("Helpful insight") as filled rust button; all disabled while
`isActing`. On `didCompleteAction`, show toast ("Insight snoozed" / "Insight
dismissed" / "Marked as helpful") and `dismiss()` (Environment).

**Steps:**
- [ ] **Step 1: Failing VM tests** — onAppear marks read exactly once (requestLog); deep-link fallback fetch when store empty; accept/dismiss/snooze call the right endpoint and flip `didCompleteAction`; failed action leaves `didCompleteAction == false` and sets store error.
- [ ] **Step 2: Verify failure; pbxproj registration.**
- [ ] **Step 3: Implement ring → VM → view; wire destination in list.** `#Preview` with fixture.
- [ ] **Step 4: Tests + full build.**
- [ ] **Step 5: Commit** — `git commit -m "feat(ios): insight detail with confidence ring, evidence rows, snooze/dismiss/accept"`.

---

### Task 14: iOS — AI weekly summary screen

**Files:**
- Create: `ios/peppy/Features/Insights/ViewModels/WeeklySummaryViewModel.swift`
- Create: `ios/peppy/Features/Insights/Views/WeeklySummaryView.swift`
- Modify: `ios/peppy/Features/Insights/Views/InsightsListView.swift` (real destination)
- Test: `ios/peppy/peppyTests/WeeklySummaryViewModelTests.swift`
- Modify: `project.pbxproj` (3 new files)

**Interfaces:**

```swift
@MainActor
@Observable
final class WeeklySummaryViewModel {
    private let store: InsightsStore
    var payload: WeeklySummaryPayload? { store.weekly?.summary }
    var weekRangeText: String { ... }        // "Week of May 24 – May 30, 2026" from weekStart/weekEnd (parse yyyy-MM-dd)
    var heroDeltaText: String? { ... }       // signed, 1 decimal, "kg" — nil hides hero numerals
    var heroTrendingDown: Bool { ... }
    var chartPoints: [(date: Date, weightKg: Double)] { ... }
    var hasNarrative: Bool { payload?.narrative != nil }
    init(store: InsightsStore)
    func onAppear() async                    // store.loadWeeklySummary() if nil
}
```

**View composition (match `ai-weekly-summary.png`):** back handled by
NavigationStack; peppy wordmark; title "AI weekly summary" + `weekRangeText`;
**hero card** (rust-muted PepCard): arrow icon in rust circle
("arrow.down.right" when trending down), big delta (34pt semibold rust) + "vs
last week", narrative sentence (or omit when `!hasNarrative`), divider, footer
"From X kg to Y kg" + week-range caption; trailing Swift Charts sparkline
(`Chart { LineMark(x: .value("Day", $0.date), y: .value("Weight", $0.weightKg)) }`
with `.chartXAxis(.hidden)`, `.chartYAxis(.hidden)`,
`.foregroundStyle(Color.pepPrimary)`, catmullRom interpolation, ~120×70pt) —
hidden when `chartPoints.count < 2`; **What changed** card: header + caption
"Key changes compared to the prior week.", `LazyVGrid(columns: 2)` of metric
tiles (icon per key: sleep_quality→"moon", dose_adherence→"syringe" (use
"cross.vial" if unavailable), checkins→"calendar", energy→"bolt"; label 13pt,
value 17pt semibold in `.pepSuccess` when `positive == true` else
`.pepTextPrimary`, detail 12pt secondary) — renders ONLY metrics present in
`whatChanged`; **What to watch** card (warning icon header; bullet rows title +
detail, chevrons omitted — static this slice) hidden when list empty; **Questions
for your provider** card (rust "?" icon; bullet rows) hidden when empty;
**explainability footer** (info-muted): "All insights are based on your logged
data and are explainable." + "View details and sources for each insight."
Unavailable state (payload nil after load): `PepEmptyState(icon: "calendar",
title: "No summary yet", message: "Your first weekly summary arrives after a
week with at least 3 check-ins.")`.

**Steps:**
- [ ] **Step 1: Failing VM tests** — weekRangeText formatting from fixture payload; heroDeltaText sign/precision; chartPoints parse date strings; hasNarrative false ⇒ (view logic) narrative/watch/questions sections hidden (test the VM booleans).
- [ ] **Step 2: Verify failure; pbxproj.**
- [ ] **Step 3: Implement; wire destination; `#Preview` for full + no-narrative states.**
- [ ] **Step 4: Tests + full build.**
- [ ] **Step 5: Commit** — `git commit -m "feat(ios): AI weekly summary screen with sparkline and adaptive metric grid"`.

---

### Task 15: iOS — cross-tab navigation + dashboard insight card wiring

**Files:**
- Modify: `ios/peppy/App/MainTabView.swift` (coordinator)
- Modify: `ios/peppy/Features/Insights/Views/InsightsListView.swift` (bind coordinator path)
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardView.swift` (tappable insight card)
- Test: extend `ios/peppy/peppyTests/ProtocolNavigationTests.swift`

**Interfaces:**
- `ProtocolNavigationCoordinator` gains:

```swift
    var insightsPath: [InsightRoute] = []

    func showInsight(_ route: InsightRoute) {
        selectedTab = .insights
        insightsPath = [route]
    }

    func showInsightsTab() {
        selectedTab = .insights
        insightsPath = []
    }
```

- `InsightsListView` replaces its local `@State` path with `@Bindable var navigation` binding `navigation.insightsPath` (mirror how `ProtocolsRootView` consumes the coordinator).
- `DashboardView.insightCard`: wrap content in a `Button`; action: `if let id = summary.insight.id { navigation.showInsight(.detail(id)) } else { navigation.showInsightsTab() }`; add trailing chevron. Reach the coordinator the same way DashboardView reaches it for protocols (it already navigates cross-tab — copy that access pattern).

**Steps:**
- [ ] **Step 1: Failing tests** — coordinator: `showInsight(.detail(id))` sets `selectedTab == .insights` and path `[.detail(id)]`; `showInsightsTab` clears path.
- [ ] **Step 2: Verify failure.**
- [ ] **Step 3: Implement all three wirings.**
- [ ] **Step 4: Full iOS test suite + build.**
- [ ] **Step 5: Commit** — `git commit -m "feat(ios): dashboard insight card deep-links into insights tab"`.

---

### Task 16: Verification, seed script, design QA, manual QA checklist

**Files:**
- Create: `backend/scripts/seed_insights_demo.py`
- Create: `ios/peppy/docs/superpowers/plans/2026-07-12-insights-manual-qa-checklist.md`

**Steps:**
- [ ] **Step 1: Seed script.** `backend/scripts/seed_insights_demo.py` — async script (run:
`cd backend && venv/bin/python -m scripts.seed_insights_demo`) that creates/updates a demo
user `insights-demo@peppy.dev` / password `peppy-demo-1` with: 30 days of check-ins
(declining weight ~0.3 kg/step, energy 7 baseline, energy 2 + nausea 5 on dose-day+1),
an active weekly protocol started 30 days ago, weekly dose logs, a 7-day recent check-in
streak, and two full Mon–Sun weeks of data so every rule and the weekly summary fire.
Ends by calling `run_generation` directly and printing the breakdown.
- [ ] **Step 2: Full verification.**
  - Backend: `cd /Users/gabri/peppy/backend && venv/bin/python -m pytest` → all pass.
  - iOS: full `xcodebuild test` on iPhone 17 Pro → all pass.
  - Live smoke: start backend (`venv/bin/uvicorn app.main:app --reload`), run seed script,
    `curl -s localhost:8000/api/v1/insights -H "Authorization: Bearer <token from login>" | python3 -m json.tool`
    shows ≥3 insights with `supporting_data`; `curl .../insights/summary/weekly` returns `available: true`
    (with `ANTHROPIC_API_KEY` set: narrative non-null; without: null narrative, watch/questions empty).
- [ ] **Step 3: Design QA.** Boot the simulator with the seeded backend, navigate the three
screens, and compare side-by-side against the three Figma frames (853×1844). Check: spacing
scale, badge colors per type, confidence ring %, section order, privacy footer copy, action
bar layout, hero card composition, grid reflow with missing metrics. Fix discrepancies.
(App screenshots via `xcrun simctl io booted screenshot` are fine; do NOT attempt scripted
UI driving — blocked on this machine.)
- [ ] **Step 4: Manual QA checklist.** Write the checklist doc for Gabriel covering: fresh
user → educational empty state; check-in submit → new insight appears on next tab visit
(event trigger); pull-to-refresh; filter chips; unread badge counts down as details are
opened; snooze hides card (and reappears if `snoozed_until` is manually backdated in DB);
dismiss hides; accept keeps in Earlier; detail evidence rows match card numbers; weekly
summary entry card → summary screen; no-narrative state (unset API key); dashboard card
deep-link; tab badge; VoiceOver pass on the three screens.
- [ ] **Step 5: Commit** — `git add backend/scripts ios/peppy/docs/superpowers/plans/2026-07-12-insights-manual-qa-checklist.md && git commit -m "chore: insights demo seed + manual QA checklist"`.

---

## Task order & dependencies

Backend: 1 → 2 → {3, 4, 5 in any order} → 6 → 7 → 8 → 9.
iOS: 10 → 11 → 12 → 13 → 14 → 15 (12–14 depend on 11; 15 depends on 12).
Task 16 last. iOS work can start once Task 9 is merged (or in parallel against the
schemas defined in Tasks 2/9 — they are the contract).
