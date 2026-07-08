from sqlalchemy import Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.models.base import Base, GUID, TimestampMixin, UUIDMixin


class DoseLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "dose_logs"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    protocol_id = Column(GUID(), ForeignKey("protocols.id", ondelete="CASCADE"), nullable=False, index=True)
    compound_id = Column(GUID(), ForeignKey("compounds.id", ondelete="CASCADE"), nullable=False, index=True)
    dose = Column(Float, nullable=False)
    unit = Column(String(20), nullable=False)
    administered_at = Column(DateTime(timezone=True), nullable=False, index=True)
    route = Column(String(50), nullable=False)
    notes = Column(Text, nullable=True)

    user = relationship("User", back_populates="dose_logs")
    protocol = relationship("Protocol", back_populates="dose_logs")
    compound = relationship("Compound", back_populates="dose_logs")
