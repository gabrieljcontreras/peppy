from dataclasses import dataclass
from datetime import date
from typing import Awaitable, Callable, Optional, Sequence
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.insight import InsightSeverity, InsightType


@dataclass
class GeneratedInsight:
    """A candidate insight produced by the engine.

    Pure data — the engine never persists. The route layer is responsible
    for turning these into `Insight` rows via `InsightService.create`.
    """
    type: InsightType
    severity: InsightSeverity
    title: str
    description: str
    explanation: str
    confidence: float
    source_data_refs: Optional[str] = None
    supporting_data: Optional[str] = None  # JSON list of evidence rows


Rule = Callable[[AsyncSession, UUID, date, date], Awaitable[list[GeneratedInsight]]]


class InsightsEngine:
    """
    The adaptive insights engine. Reads a user's check-ins, labs, wearable
    data, and protocol info over a date range and returns candidate
    insights.

    Its public interface is intentionally small — `analyze_user_data` — so
    detection rules can be added behind it without changing callers.
    """

    def __init__(self, db: AsyncSession, rules: Optional[Sequence[Rule]] = None):
        self.db = db
        if rules is None:
            from app.ml.rules import DEFAULT_RULES
            rules = DEFAULT_RULES
        self._rules: Sequence[Rule] = rules

    async def analyze_user_data(
        self,
        user_id: UUID,
        start_date: date,
        end_date: date,
    ) -> list[GeneratedInsight]:
        """
        Analyze a user's data over a time range and return candidate
        insights. No persistence — caller decides what to do with the result.
        """
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
