from sqlalchemy import Column, String, Float, Date, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class LabResult(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "lab_results"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    panel_type = Column(String(50), nullable=False)  # metabolic, lipid, hormone, liver, kidney
    lab_name = Column(String(200), nullable=True)
    notes = Column(Text, nullable=True)

    # Relationships
    user = relationship("User", back_populates="lab_results")
    markers = relationship("LabMarker", back_populates="lab_result", cascade="all, delete-orphan")


class LabMarker(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "lab_markers"

    lab_result_id = Column(GUID(), ForeignKey("lab_results.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)  # e.g., "HbA1c", "ALT", "TSH"
    value = Column(Float, nullable=False)
    unit = Column(String(30), nullable=False)
    reference_low = Column(Float, nullable=True)
    reference_high = Column(Float, nullable=True)

    # Relationships
    lab_result = relationship("LabResult", back_populates="markers")
