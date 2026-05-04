from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Text, Enum
from sqlalchemy.orm import relationship
import enum
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


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

    # Relationships
    user = relationship("User", back_populates="insights")
