from enum import Enum
from sqlalchemy import Column, String, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class JobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class Job(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "jobs"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    job_type = Column(String(50), nullable=False)
    status = Column(SAEnum(JobStatus), nullable=False, default=JobStatus.PENDING)
    result = Column(Text, nullable=True)
    error = Column(Text, nullable=True)

    user = relationship("User", back_populates="jobs")
