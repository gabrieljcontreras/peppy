from uuid import UUID
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.job import Job, JobStatus


class JobService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, user_id: UUID, job_type: str) -> Job:
        job = Job(
            user_id=user_id,
            job_type=job_type,
            status=JobStatus.PENDING,
        )
        self.db.add(job)
        await self.db.commit()
        await self.db.refresh(job)
        return job

    async def get_by_id(self, job_id: UUID, user_id: UUID) -> Optional[Job]:
        result = await self.db.execute(
            select(Job).where(
                and_(
                    Job.id == job_id,
                    Job.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def update_status(
        self,
        job: Job,
        status: JobStatus,
        result: Optional[str] = None,
        error: Optional[str] = None,
    ) -> Job:
        job.status = status
        if result is not None:
            job.result = result
        if error is not None:
            job.error = error
        await self.db.commit()
        await self.db.refresh(job)
        return job
