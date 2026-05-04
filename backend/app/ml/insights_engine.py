from dataclasses import dataclass
from datetime import date
from typing import Optional
from enum import Enum


class InsightType(Enum):
    ANOMALY = "anomaly"
    TREND = "trend"
    SUGGESTION = "suggestion"
    MILESTONE = "milestone"


class InsightSeverity(Enum):
    INFO = "info"
    WARNING = "warning"
    ALERT = "alert"


@dataclass
class GeneratedInsight:
    type: InsightType
    severity: InsightSeverity
    title: str
    description: str
    explanation: str
    confidence: float
    source_data_refs: Optional[list[str]] = None


class InsightsEngine:
    """
    The adaptive insights engine that analyzes user data and generates
    personalized insights, anomaly alerts, and suggestions.

    This is the core ML component of Peppy.
    """

    def __init__(self):
        # TODO: Load models, configure thresholds
        pass

    async def analyze_user_data(
        self,
        user_id: str,
        start_date: date,
        end_date: date,
    ) -> list[GeneratedInsight]:
        """
        Analyze a user's data over a time range and generate insights.

        This method:
        1. Fetches user's checkins, labs, wearable data, and protocol info
        2. Establishes/updates user's baseline metrics
        3. Detects anomalies from baseline
        4. Identifies trends (improving, declining, stable)
        5. Generates suggestions based on patterns
        6. Flags milestones (weight goals, lab improvements)
        """
        insights = []

        # TODO: Implement analysis pipeline
        # - Load user data
        # - Calculate baselines
        # - Detect anomalies (z-score, isolation forest, etc.)
        # - Trend detection (linear regression, LOESS)
        # - Rule-based suggestions
        # - ML-based pattern matching

        return insights

    async def detect_anomalies(self, user_id: str, metric: str, value: float) -> Optional[GeneratedInsight]:
        """
        Check if a single metric value is anomalous for this user.
        Used for real-time flagging during check-in.
        """
        # TODO: Compare against user's baseline
        # Use z-score or percentile-based detection
        return None

    async def generate_dosing_suggestion(self, user_id: str) -> Optional[GeneratedInsight]:
        """
        Based on user's response data, suggest protocol adjustments.

        Considers:
        - Side effect severity trends
        - Weight loss velocity
        - Lab markers (if recent)
        - Time on current dose
        """
        # TODO: Implement dosing suggestion logic
        return None
