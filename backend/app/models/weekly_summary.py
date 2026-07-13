from sqlalchemy import Column, Date, ForeignKey, String, Text, UniqueConstraint

from app.models.base import GUID, Base, TimestampMixin, UUIDMixin


class WeeklySummary(Base, UUIDMixin, TimestampMixin):
    """Cached AI weekly summary, unique per user and completed week."""

    __tablename__ = "weekly_summaries"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "week_start",
            name="uq_weekly_summary_user_week",
        ),
    )

    user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    week_start = Column(Date, nullable=False)
    payload = Column(Text, nullable=False)
    model_used = Column(String(100), nullable=True)
