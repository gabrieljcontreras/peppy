from sqlalchemy import Column, Float, Integer, Date, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class Checkin(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "checkins"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)

    # Metrics (all optional - user logs what they want)
    weight_kg = Column(Float, nullable=True)
    energy_level = Column(Integer, nullable=True)  # 1-10
    sleep_quality = Column(Integer, nullable=True)  # 1-10
    appetite_level = Column(Integer, nullable=True)  # 1-10
    mood = Column(Integer, nullable=True)  # 1-10

    # Side effects (0-10 severity)
    nausea = Column(Integer, nullable=True)
    injection_site_reaction = Column(Integer, nullable=True)
    fatigue = Column(Integer, nullable=True)
    headache = Column(Integer, nullable=True)
    gi_issues = Column(Integer, nullable=True)  # GI discomfort

    notes = Column(Text, nullable=True)

    # Relationships
    user = relationship("User", back_populates="checkins")
