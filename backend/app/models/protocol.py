from sqlalchemy import Boolean, Column, Date, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class Protocol(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "protocols"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(200), nullable=False)
    start_date = Column(Date, nullable=False, index=True)
    end_date = Column(Date, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    setup_status = Column(String(30), default="active", nullable=False, index=True)
    is_starter = Column(Boolean, default=False, nullable=False)
    notes = Column(Text, nullable=True)

    # Relationships
    user = relationship("User", back_populates="protocols")
    compounds = relationship("Compound", back_populates="protocol", cascade="all, delete-orphan")
    dose_logs = relationship("DoseLog", back_populates="protocol", cascade="all, delete")


class Compound(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "compounds"

    protocol_id = Column(GUID(), ForeignKey("protocols.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)  # e.g., "Retatrutide", "Semaglutide"
    dose_mg = Column(Float, nullable=False)
    dose_unit = Column(String(20), default="mg", nullable=False)
    frequency = Column(String(50), nullable=False)  # e.g., "weekly", "daily"
    administration_route = Column(String(50), default="subcutaneous", nullable=False)
    notes = Column(Text, nullable=True)

    # Relationships
    protocol = relationship("Protocol", back_populates="compounds")
    dose_logs = relationship("DoseLog", back_populates="compound", cascade="all, delete")
