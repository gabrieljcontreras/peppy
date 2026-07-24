# iOS Insights Readiness Bug Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make authenticated Insights requests succeed without redirects, return one evidence-backed baseline after three check-ins when stronger rules are silent, and simplify the iOS learning-state copy without redesigning the screen.

**Architecture:** Keep all health-pattern calculation in the backend. The existing engine runs its high-signal rules first and invokes a deterministic baseline rule only when they return no candidates; the list route synchronously recovers eligible users who have never stored an insight, then retains the existing background refresh behavior. iOS continues rendering the same Figma-aligned screen and shared empty-state component with approved copy and testable presentation state.

**Tech Stack:** Python 3, FastAPI, SQLAlchemy async, pytest/pytest-asyncio, Swift 6, SwiftUI, Observation, XCTest, Xcode 26.

## Global Constraints

- Work directly on `main`; do not create a worktree.
- Preserve iOS 17 as the minimum deployment target.
- Require at least three completed check-ins before generating the neutral baseline.
- Never characterize a value as improving, declining, anomalous, or dose-related unless an existing stronger rule supports that claim.
- Keep pattern calculation on the backend; do not calculate health insights in iOS.
- Use the exact learning-state title `peppy is learning your patterns.`.
- Use the exact learning-state message `Keep checking in daily and logging doses`.
- Preserve the existing Insights hierarchy, Peppy design tokens, filters, navigation, and shared components.
- Use the existing Figma frame for one practical visual comparison; do not enter a pixel-by-pixel iteration loop.
- Do not change the Insights detail screen, weekly-summary screen, API response schema, insight categories, or narrator prompts.

---

## File Structure

- Create `backend/app/ml/rules/checkin_baseline.py`: deterministic construction of the one-time three-check-in baseline candidate.
- Create `backend/tests/test_insights_readiness.py`: focused regression coverage for the canonical route, fallback threshold/evidence, stronger-rule precedence, deduplication, and same-response recovery.
- Modify `backend/app/ml/insights_engine.py`: invoke the fallback only when the configured stronger rules return nothing.
- Modify `backend/app/services/insight.py`: expose an ownership-scoped `has_any_for_user` query used by the list route.
- Modify `backend/app/api/routes/insights.py`: remove the redirect and synchronously recover users with no stored insights.
- Modify `backend/tests/test_insight_generation.py`: keep stale/fresh background-generation tests truthful by seeding an existing insight.
- Modify `ios/peppy/Features/Insights/ViewModels/InsightsListViewModel.swift`: expose the loaded-empty presentation state.
- Modify `ios/peppy/Features/Insights/Views/InsightsListView.swift`: use exact copy, the presentation state, and an empty-state preview while preserving existing styling.
- Modify `ios/peppy/peppyTests/InsightsListViewModelTests.swift`: cover exact copy and empty/non-empty state selection.

---

### Task 1: Remove the authenticated Insights redirect

**Files:**
- Create: `backend/tests/test_insights_readiness.py`
- Modify: `backend/app/api/routes/insights.py:38`

**Interfaces:**
- Consumes: iOS `Endpoint.getInsights.path == "/insights"` and the FastAPI router prefix `/api/v1/insights`.
- Produces: canonical authenticated `GET /api/v1/insights` with no redirect.

- [ ] **Step 1: Write the failing canonical-route test**

Create `backend/tests/test_insights_readiness.py` with:

```python
import json
from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import Settings
from app.ml.insights_engine import GeneratedInsight, InsightsEngine
from app.ml.narrator import Narrator
from app.models.checkin import Checkin
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.user import User
from app.services.insight import InsightService
from app.services.insight_generation import run_generation


async def _auth_headers(client, email: str) -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123"},
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password123"},
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


@pytest.mark.asyncio
async def test_insights_collection_path_does_not_redirect_authenticated_request(client):
    headers = await _auth_headers(client, "insights-canonical@example.com")

    response = await client.get("/api/v1/insights", headers=headers)

    assert response.status_code == 200
    assert response.history == []
```

- [ ] **Step 2: Run the test to verify the redirect failure**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py::test_insights_collection_path_does_not_redirect_authenticated_request -q
```

Expected: FAIL with status `307`, proving the iOS path is redirected before authorization reaches the handler.

- [ ] **Step 3: Register the collection handler at the canonical path**

In `backend/app/api/routes/insights.py`, replace:

```python
@router.get("/", response_model=list[InsightResponse])
```

with:

```python
@router.get("", response_model=list[InsightResponse])
```

Do not change the iOS endpoint and do not register a second slash alias.

- [ ] **Step 4: Run the canonical-route test**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py::test_insights_collection_path_does_not_redirect_authenticated_request -q
```

Expected: PASS with one direct `200` response.

- [ ] **Step 5: Commit the redirect fix**

```bash
cd /Users/gabri/peppy
git add backend/app/api/routes/insights.py backend/tests/test_insights_readiness.py
git commit -m "fix: avoid insights authentication redirect"
```

---

### Task 2: Generate a conservative baseline after three check-ins

**Files:**
- Create: `backend/app/ml/rules/checkin_baseline.py`
- Modify: `backend/app/ml/insights_engine.py:48-61`
- Modify: `backend/tests/test_insights_readiness.py`

**Interfaces:**
- Consumes: `Checkin` rows in the requested analysis window and the existing `GeneratedInsight` contract.
- Produces: `checkin_baseline_rule(db, user_id, start_date, end_date) -> list[GeneratedInsight]`; `InsightsEngine.analyze_user_data` returns its result only when configured stronger rules return no candidates.

- [ ] **Step 1: Add failing threshold, evidence, and precedence tests**

Append to `backend/tests/test_insights_readiness.py`:

```python
async def _create_user(db: AsyncSession, email: str) -> User:
    user = User(email=email, hashed_password="x")
    db.add(user)
    await db.flush()
    return user


async def _seed_baseline_checkins(db: AsyncSession, user_id, count: int = 3) -> None:
    values = [
        (date(2026, 7, 1), 80.0, 5, 7, 6),
        (date(2026, 7, 2), 80.5, 7, 8, 7),
        (date(2026, 7, 3), 81.0, 6, 9, 8),
    ]
    for checkin_date, weight, energy, mood, sleep in values[:count]:
        db.add(
            Checkin(
                user_id=user_id,
                date=checkin_date,
                weight_kg=weight,
                energy_level=energy,
                mood=mood,
                sleep_quality=sleep,
            )
        )
    await db.commit()


@pytest.mark.asyncio
async def test_engine_returns_baseline_from_latest_three_when_stronger_rules_are_silent(
    db_session,
):
    user = await _create_user(db_session, "baseline-three@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert len(results) == 1
    candidate = results[0]
    assert candidate.type == InsightType.TREND
    assert candidate.severity == InsightSeverity.INFO
    assert candidate.title == "Your recent check-in pattern"
    assert candidate.description == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )
    assert candidate.confidence == 0.6
    assert json.loads(candidate.source_data_refs) == {
        "rule": "checkin_baseline_v1"
    }
    assert json.loads(candidate.supporting_data) == [
        {
            "icon_key": "weight",
            "label": "Weight",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "80.0 → 81.0 kg",
        },
        {
            "icon_key": "chart",
            "label": "Average energy",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "6.0 / 10",
        },
        {
            "icon_key": "chart",
            "label": "Average mood",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "8.0 / 10",
        },
        {
            "icon_key": "sleep",
            "label": "Average sleep quality",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "7.0 / 10",
        },
        {
            "icon_key": "calendar",
            "label": "Check-ins analyzed",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "3",
        },
    ]


@pytest.mark.asyncio
async def test_engine_does_not_return_baseline_before_three_checkins(db_session):
    user = await _create_user(db_session, "baseline-two@example.com")
    await _seed_baseline_checkins(db_session, user.id, count=2)
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == []


@pytest.mark.asyncio
async def test_engine_does_not_invent_baseline_for_date_only_checkins(db_session):
    user = await _create_user(db_session, "baseline-empty@example.com")
    for offset in range(3):
        db_session.add(
            Checkin(
                user_id=user.id,
                date=date(2026, 7, 1) + timedelta(days=offset),
            )
        )
    await db_session.commit()
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == []


@pytest.mark.asyncio
async def test_engine_prefers_stronger_candidate_over_baseline(db_session):
    user = await _create_user(db_session, "baseline-stronger@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    stronger = GeneratedInsight(
        type=InsightType.ANOMALY,
        severity=InsightSeverity.WARNING,
        title="Stronger finding",
        description="A threshold-backed finding.",
        explanation="Computed by the configured strong rule.",
        confidence=0.8,
        source_data_refs='{"rule":"stronger"}',
    )

    async def strong_rule(db, user_id, start_date, end_date):
        return [stronger]

    engine = InsightsEngine(db_session, rules=[strong_rule])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == [stronger]
```

- [ ] **Step 2: Run the three-check-in test to verify the missing fallback**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py::test_engine_returns_baseline_from_latest_three_when_stronger_rules_are_silent -q
```

Expected: FAIL because `InsightsEngine(..., rules=[])` currently returns an empty list.

- [ ] **Step 3: Implement the deterministic baseline rule**

Create `backend/app/ml/rules/checkin_baseline.py`:

```python
import json
from datetime import date
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.insight import InsightSeverity, InsightType

_MIN_CHECKINS = 3
_SOURCE_REFERENCE = json.dumps(
    {"rule": "checkin_baseline_v1"},
    sort_keys=True,
)


def _average(values: list[float]) -> float:
    return sum(values) / len(values)


async def checkin_baseline_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    result = await db.execute(
        select(Checkin)
        .where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
        .order_by(Checkin.date.desc(), Checkin.id.desc())
        .limit(_MIN_CHECKINS)
    )
    checkins = list(reversed(result.scalars().all()))
    if len(checkins) < _MIN_CHECKINS:
        return []

    date_range = f"{checkins[0].date.isoformat()} – {checkins[-1].date.isoformat()}"
    description_parts: list[str] = []
    supporting_data: list[dict] = []

    weights = [
        float(checkin.weight_kg)
        for checkin in checkins
        if checkin.weight_kg is not None
    ]
    if weights:
        if len(weights) == 1:
            description_parts.append(f"Your recorded weight was {weights[0]:.1f} kg")
            weight_value = f"{weights[0]:.1f} kg"
        else:
            description_parts.append(
                f"Your weight moved from {weights[0]:.1f} kg to {weights[-1]:.1f} kg"
            )
            weight_value = f"{weights[0]:.1f} → {weights[-1]:.1f} kg"
        supporting_data.append(
            {
                "icon_key": "weight",
                "label": "Weight",
                "sublabel": date_range,
                "value": weight_value,
            }
        )

    rating_metrics = (
        ("energy_level", "Energy", "Average energy", "chart"),
        ("mood", "Mood", "Average mood", "chart"),
        ("sleep_quality", "Sleep quality", "Average sleep quality", "sleep"),
    )
    for field, description_label, row_label, icon_key in rating_metrics:
        values = [
            float(value)
            for checkin in checkins
            if (value := getattr(checkin, field)) is not None
        ]
        if not values:
            continue
        average = _average(values)
        description_parts.append(f"{description_label} averaged {average:.1f}/10")
        supporting_data.append(
            {
                "icon_key": icon_key,
                "label": row_label,
                "sublabel": date_range,
                "value": f"{average:.1f} / 10",
            }
        )

    if not description_parts:
        return []

    supporting_data.append(
        {
            "icon_key": "calendar",
            "label": "Check-ins analyzed",
            "sublabel": date_range,
            "value": str(len(checkins)),
        }
    )
    description = ". ".join(description_parts[:2]) + "."

    return [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Your recent check-in pattern",
            description=description,
            explanation=(
                "Computed from your latest 3 check-ins from "
                f"{checkins[0].date.isoformat()} to {checkins[-1].date.isoformat()}. "
                "Only values you recorded are included."
            ),
            confidence=0.6,
            source_data_refs=_SOURCE_REFERENCE,
            supporting_data=json.dumps(supporting_data),
        )
    ]
```

- [ ] **Step 4: Invoke the fallback only after stronger rules are silent**

Replace the end of `InsightsEngine.analyze_user_data` in
`backend/app/ml/insights_engine.py` with:

```python
        results: list[GeneratedInsight] = []
        for rule in self._rules:
            results.extend(await rule(self.db, user_id, start_date, end_date))
        if results:
            return results

        from app.ml.rules.checkin_baseline import checkin_baseline_rule

        return await checkin_baseline_rule(
            self.db,
            user_id,
            start_date,
            end_date,
        )
```

- [ ] **Step 5: Run the focused baseline tests**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py -q
```

Expected: all tests present so far PASS.

- [ ] **Step 6: Add the failing persistence/deduplication test**

Append to `backend/tests/test_insights_readiness.py`:

```python
@pytest.mark.asyncio
async def test_generation_persists_deterministic_baseline_only_once(db_session):
    user = await _create_user(db_session, "baseline-persistence@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    narrator = Narrator(settings=Settings(anthropic_api_key="", debug=True))

    first = await run_generation(
        db_session,
        user.id,
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 31),
        narrator=narrator,
    )
    second = await run_generation(
        db_session,
        user.id,
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 31),
        narrator=narrator,
    )

    assert first == {"insights_generated": 1, "types_breakdown": {"trend": 1}}
    assert second == {"insights_generated": 0, "types_breakdown": {}}
    persisted = await InsightService(db_session).list_for_user(user.id)
    assert len(persisted) == 1
    assert persisted[0].title == "Your recent check-in pattern"
    assert persisted[0].description == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )
```

- [ ] **Step 7: Verify persistence and existing insight generation**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py tests/test_insight_generation.py tests/test_insight_generation_persistence.py -q
```

Expected: all selected tests PASS, including narrator-disabled baseline persistence and existing high-signal rules.

- [ ] **Step 8: Commit the fallback**

```bash
cd /Users/gabri/peppy
git add backend/app/ml/insights_engine.py backend/app/ml/rules/checkin_baseline.py backend/tests/test_insights_readiness.py
git commit -m "fix: generate an early check-in baseline insight"
```

---

### Task 3: Return the first baseline in the same list response

**Files:**
- Modify: `backend/app/services/insight.py:38-118`
- Modify: `backend/app/api/routes/insights.py:55-70`
- Modify: `backend/tests/test_insights_readiness.py`
- Modify: `backend/tests/test_insight_generation.py:755-810`

**Interfaces:**
- Consumes: `InsightService.list_for_user`, `run_generation`, and the stable baseline deduplication key from Task 2.
- Produces: `InsightService.has_any_for_user(user_id) -> bool`; a first successful list request synchronously generates and returns an eligible user's initial baseline.

- [ ] **Step 1: Add the failing same-response recovery test**

Append to `backend/tests/test_insights_readiness.py`:

```python
@pytest.mark.asyncio
async def test_list_returns_baseline_in_same_response_for_existing_checkins(
    client,
    engine,
):
    email = "baseline-route-recovery@example.com"
    headers = await _auth_headers(client, email)
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as db:
        user = (
            await db.execute(select(User).where(User.email == email))
        ).scalar_one()
        await _seed_baseline_checkins(db, user.id)

    response = await client.get("/api/v1/insights", headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["title"] == "Your recent check-in pattern"
    assert payload[0]["description"] == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )
```

- [ ] **Step 2: Run the recovery test to verify the empty first response**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py::test_list_returns_baseline_in_same_response_for_existing_checkins -q
```

Expected: FAIL because the current list handler schedules generation after it has already built the empty response.

- [ ] **Step 3: Add an ownership-scoped stored-insight query**

Add this method to `InsightService` after `list_for_user` in
`backend/app/services/insight.py`:

```python
    async def has_any_for_user(self, user_id: UUID) -> bool:
        """Return whether the user has ever stored an insight, including hidden rows."""
        result = await self.db.execute(
            select(exists().where(Insight.user_id == user_id))
        )
        return bool(result.scalar())
```

- [ ] **Step 4: Generate before returning only for users with no stored insight**

Replace the generation block at the end of `list_insights` in
`backend/app/api/routes/insights.py` with:

```python
    if not await service.has_any_for_user(current_user.id):
        await run_generation(db, current_user.id)
        insights = await service.list_for_user(
            user_id=current_user.id,
            unread_only=unread_only,
            type=ModelInsightType(type.value) if type else None,
            severity=ModelInsightSeverity(severity.value) if severity else None,
            include_dismissed=include_dismissed,
            limit=limit,
            offset=offset,
        )
    elif is_stale(current_user):
        background_tasks.add_task(
            run_generation_in_background,
            current_user.id,
        )
    return insights
```

This deliberately treats dismissed or snoozed rows as stored insights so a
user action cannot cause repeated neutral baselines.

- [ ] **Step 5: Keep the stale/fresh background tests on their intended branch**

In both `test_get_insights_runs_background_generation_when_stale` and
`test_get_insights_does_not_regenerate_when_fresh` in
`backend/tests/test_insight_generation.py`, add an existing informational
insight in their setup sessions before committing:

```python
        setup_db.add(
            Insight(
                user_id=user.id,
                type=InsightType.TREND,
                severity=InsightSeverity.INFO,
                title="Existing insight",
                description="Existing description",
                explanation="Existing explanation",
                confidence=0.7,
                source_data_refs='{"rule":"existing-route-test"}',
            )
        )
```

For the stale test, open a setup session before the request using its existing
`test_session_factory`, load the user by email, add the row above, and commit.
For the fresh test, add the row inside its existing `setup_db` block alongside
the `last_insight_run_at` update.

- [ ] **Step 6: Run route, generation, and service regressions**

Run:

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py tests/test_insight_generation.py tests/test_insight_service.py -q
```

Expected: all selected tests PASS. The new route test returns the baseline
immediately; existing rows still use stale background generation and fresh
rows do not regenerate.

- [ ] **Step 7: Commit same-response recovery**

```bash
cd /Users/gabri/peppy
git add backend/app/api/routes/insights.py backend/app/services/insight.py backend/tests/test_insights_readiness.py backend/tests/test_insight_generation.py
git commit -m "fix: return first insight generation immediately"
```

---

### Task 4: Simplify and verify the iOS learning state

**Files:**
- Modify: `ios/peppy/Features/Insights/ViewModels/InsightsListViewModel.swift:24-30`
- Modify: `ios/peppy/Features/Insights/Views/InsightsListView.swift:3-40`
- Modify: `ios/peppy/peppyTests/InsightsListViewModelTests.swift:56-120`

**Interfaces:**
- Consumes: `InsightsStore.insights`, `InsightsStore.isLoading`, and the existing `PepEmptyState`.
- Produces: `InsightsListViewModel.showsLearningState`; exact static copy constants on `InsightsListView`; unchanged loaded-list presentation.

- [ ] **Step 1: Add failing presentation-state and exact-copy tests**

Add these tests to `InsightsListViewModelTests` before the helper section:

```swift
    func testLearningStateUsesApprovedCopy() {
        XCTAssertEqual(
            InsightsListView.learningTitle,
            "peppy is learning your patterns."
        )
        XCTAssertEqual(
            InsightsListView.learningMessage,
            "Keep checking in daily and logging doses"
        )
    }

    func testLearningStateShownForLoadedEmptyInsights() async {
        let (model, _, _) = await loadedModel(insights: [])

        XCTAssertTrue(model.showsLearningState)
    }

    func testLearningStateHiddenForLoadedInsights() async {
        let (model, _, _) = await loadedModel(
            insights: [Insight.fixture()]
        )

        XCTAssertFalse(model.showsLearningState)
    }
```

- [ ] **Step 2: Run the focused iOS test to verify missing presentation API**

Run:

```bash
cd /Users/gabri/peppy/ios
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild test -project peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:peppyTests/InsightsListViewModelTests
```

Expected: build FAIL because `learningTitle`, `learningMessage`, and
`showsLearningState` do not exist.

- [ ] **Step 3: Expose the loaded-empty presentation state**

Add to `InsightsListViewModel` after `showsSummaryCard`:

```swift
    var showsLearningState: Bool {
        store.insights.isEmpty && !store.isLoading
    }
```

- [ ] **Step 4: Apply the exact copy without changing visual structure**

Add these constants immediately inside `InsightsListView`:

```swift
    static let learningTitle = "peppy is learning your patterns."
    static let learningMessage = "Keep checking in daily and logging doses"
```

Replace the state branch in `InsightsListView.body` with:

```swift
                    if store.insights.isEmpty && store.isLoading {
                        PepLoadingView(message: "Loading your insights")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if model.showsLearningState {
                        PepEmptyState(
                            icon: "sparkles",
                            title: Self.learningTitle,
                            message: Self.learningMessage
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        insightSections
                    }
```

Do not change the `VStack` spacing, horizontal/vertical padding, filters,
header, colors, fonts, icon, privacy card, navigation, or `PepEmptyState`.

- [ ] **Step 5: Add a dedicated learning-state preview for one-pass visual QA**

Append to `InsightsListView.swift`:

```swift
#Preview("Insights learning state") {
    let deps = Dependencies.mock()
    if let api = deps.api as? MockAPIClient {
        api.setMockResponse(
            [Insight](),
            for: Endpoint.getInsights(unreadOnly: nil, type: nil, severity: nil)
        )
        api.setMockResponse(
            WeeklySummaryEnvelope(available: false, summary: nil),
            for: Endpoint.getWeeklySummary
        )
    }
    return InsightsListView(
        store: deps.insightsStore,
        navigation: deps.protocolNavigation
    )
    .withDependencies(deps)
}
```

- [ ] **Step 6: Run the focused Insights tests**

Run:

```bash
cd /Users/gabri/peppy/ios
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild test -project peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:peppyTests/InsightsListViewModelTests -only-testing:peppyTests/InsightsStoreTests -only-testing:peppyTests/InsightAPIModelsTests
```

Expected: all selected tests PASS.

- [ ] **Step 7: Perform one scoped Figma comparison**

Open the `Insights learning state` preview at an iPhone portrait size and
compare its surrounding hierarchy against:

```text
/Users/gabri/.claude/projects/-Users-gabri-peppy/figma-frames/insights-list.png
```

Check only:

- header and title hierarchy;
- filter-chip placement;
- centered empty-state alignment;
- title/message wrapping and clipping;
- shared Peppy colors and typography;
- one larger Dynamic Type size.

If these are structurally correct, stop. Do not iterate over individual pixel
offsets or redesign the empty-state component.

- [ ] **Step 8: Commit the iOS copy/state fix**

```bash
cd /Users/gabri/peppy
git add ios/peppy/Features/Insights/ViewModels/InsightsListViewModel.swift ios/peppy/Features/Insights/Views/InsightsListView.swift ios/peppy/peppyTests/InsightsListViewModelTests.swift
git commit -m "fix: simplify the insights learning state"
```

---

### Task 5: Verify the complete Insights fix

**Files:**
- Verify: `backend/app/api/routes/insights.py`
- Verify: `backend/app/ml/insights_engine.py`
- Verify: `backend/app/ml/rules/checkin_baseline.py`
- Verify: `backend/app/services/insight.py`
- Verify: `ios/peppy/Features/Insights/ViewModels/InsightsListViewModel.swift`
- Verify: `ios/peppy/Features/Insights/Views/InsightsListView.swift`

**Interfaces:**
- Consumes: all deliverables from Tasks 1–4.
- Produces: fresh evidence that the backend, focused iOS tests, and app build pass together.

- [ ] **Step 1: Run formatting and whitespace validation**

```bash
cd /Users/gabri/peppy
git diff --check
```

Expected: exit `0` with no output.

- [ ] **Step 2: Run the relevant backend regression suite**

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest tests/test_insights_readiness.py tests/test_insight_generation.py tests/test_insight_generation_persistence.py tests/test_insight_service.py tests/test_insights_schema.py -q
```

Expected: all selected tests PASS.

- [ ] **Step 3: Run the full backend suite**

```bash
cd /Users/gabri/peppy/backend
venv/bin/python -m pytest -q
```

Expected: all backend tests PASS.

- [ ] **Step 4: Run the focused iOS Insights suite**

```bash
cd /Users/gabri/peppy/ios
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild test -project peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:peppyTests/InsightsListViewModelTests -only-testing:peppyTests/InsightsStoreTests -only-testing:peppyTests/InsightDetailViewModelTests -only-testing:peppyTests/InsightAPIModelsTests -only-testing:peppyTests/WeeklySummaryViewModelTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Build the complete iOS app**

```bash
cd /Users/gabri/peppy/ios
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -project peppy/peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify requirements against the approved design**

Confirm:

- authenticated `/api/v1/insights` returns directly;
- three supported check-ins produce one neutral baseline when strong rules are silent;
- two or date-only check-ins produce no baseline;
- strong rules suppress the fallback;
- repeated generation does not duplicate the baseline;
- eligible first-time users receive the baseline in the same list response;
- iOS uses the two exact approved strings;
- the existing Figma-aligned layout and shared components remain intact.

- [ ] **Step 7: Inspect final repository state**

```bash
cd /Users/gabri/peppy
git status --short
git log -5 --oneline
```

Expected: no uncommitted task changes and four focused bug-fix commits after
the committed design and plan documentation.
