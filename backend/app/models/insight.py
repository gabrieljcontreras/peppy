import enum

from sqlalchemy import Column, DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.models.base import GUID, Base, TimestampMixin, UUIDMixin


class InsightType(enum.Enum):
    ANOMALY = "anomaly"
    TREND = "trend"
    SUGGESTION = "suggestion"
    MILESTONE = "milestone"


class InsightSeverity(enum.Enum):
    INFO = "info"
    WARNING = "warning"
    ALERT = "alert"


class Insight(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "insights"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    type = Column(Enum(InsightType), nullable=False)
    severity = Column(Enum(InsightSeverity), nullable=False, default=InsightSeverity.INFO)

    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    explanation = Column(Text, nullable=False)  # Why this insight was generated

    confidence = Column(Float, nullable=False)  # 0.0 to 1.0

    # User interaction
    read_at = Column(DateTime(timezone=True), nullable=True)
    dismissed_at = Column(DateTime(timezone=True), nullable=True)
    action_taken = Column(String(50), nullable=True)  # accept, dismiss, snooze
    action_notes = Column(Text, nullable=True)

    # Reference to source data (JSON paths or IDs)
    source_data_refs = Column(Text, nullable=True)

    # Frozen evidence rows for the detail screen, written at detection time.
    supporting_data = Column(Text, nullable=True)

    # Hidden from default lists until this passes, then resurfaced unread.
    snoozed_until = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="insights")
