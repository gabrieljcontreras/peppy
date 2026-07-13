import json
import asyncio
from uuid import UUID
from datetime import date
from collections import Counter

from app.celery_app import celery_app
from app.database import async_session_maker
from app.services.insight import InsightService
from app.services.job import JobService
from app.services.notification import NotificationService
from app.ml.insights_engine import InsightsEngine
from app.models.job import JobStatus
from app.models.insight import InsightSeverity
from app.integrations.push import PushAdapter


async def _run_insight_generation(
    job_id: UUID,
    user_id: UUID,
    start_date: date,
    end_date: date,
    ios_adapter: PushAdapter | None = None,
    android_adapter: PushAdapter | None = None,
) -> dict:
    async with async_session_maker() as db:
        job_service = JobService(db)
        job = await job_service.get_by_id(job_id, user_id)
        if not job:
            return {"error": "Job not found"}

        await job_service.update_status(job, JobStatus.RUNNING)

        try:
            engine = InsightsEngine(db)
            candidates = await engine.analyze_user_data(user_id, start_date, end_date)

            insight_service = InsightService(db)
            notification_service = NotificationService(db)
            created = []
            for candidate in candidates:
                if await insight_service.exists_matching(
                    user_id, candidate.type, candidate.source_data_refs
                ):
                    continue
                insight = await insight_service.create(
                    user_id=user_id,
                    type=candidate.type,
                    severity=candidate.severity,
                    title=candidate.title,
                    description=candidate.description,
                    explanation=candidate.explanation,
                    confidence=candidate.confidence,
                    source_data_refs=candidate.source_data_refs,
                    supporting_data=candidate.supporting_data,
                )
                created.append(candidate)

                if candidate.severity == InsightSeverity.ALERT:
                    await notification_service.send_insight_notification(
                        user_id=user_id,
                        insight_id=insight.id,
                        title=candidate.title,
                        body=candidate.description,
                        severity=candidate.severity,
                        ios_adapter=ios_adapter,
                        android_adapter=android_adapter,
                    )

            breakdown = Counter(c.type.value for c in created)
            result = {
                "insights_generated": len(created),
                "types_breakdown": dict(breakdown),
            }

            await job_service.update_status(
                job, JobStatus.COMPLETED, result=json.dumps(result)
            )
            return result

        except Exception as e:
            await job_service.update_status(
                job, JobStatus.FAILED, error=str(e)
            )
            raise


@celery_app.task(bind=True, name="generate_insights")
def generate_insights_task(
    self,
    job_id: str,
    user_id: str,
    start_date: str,
    end_date: str,
):
    return asyncio.run(
        _run_insight_generation(
            UUID(job_id),
            UUID(user_id),
            date.fromisoformat(start_date),
            date.fromisoformat(end_date),
        )
    )
