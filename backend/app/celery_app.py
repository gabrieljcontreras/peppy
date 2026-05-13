from celery import Celery
from app.config import get_settings

settings = get_settings()

celery_app = Celery(
    "peppy",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.tasks.insights"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    result_expires=3600,
)

if settings.debug:
    celery_app.conf.task_always_eager = True
    celery_app.conf.task_eager_propagates = True
