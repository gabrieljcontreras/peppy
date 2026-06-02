from sqlalchemy import Column, String
from app.models.base import Base, UUIDMixin, TimestampMixin


class WaitlistEntry(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "waitlist_entries"

    email = Column(String(320), unique=True, nullable=False, index=True)
