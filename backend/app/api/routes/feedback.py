import logging
import smtplib
from email.message import EmailMessage

from fastapi import APIRouter
from pydantic import BaseModel, EmailStr

from app.config import get_settings

router = APIRouter()
logger = logging.getLogger(__name__)


class FeedbackEmail(BaseModel):
    to: EmailStr
    subject: str
    text: str
    reply_to: EmailStr | None = None


@router.post("/email")
async def send_feedback_email(body: FeedbackEmail):
    settings = get_settings()

    if not all([settings.smtp_host, settings.smtp_user, settings.smtp_password]):
        logger.warning("SMTP not configured — logging feedback instead")
        logger.info("[feedback] to=%s subject=%s\n%s", body.to, body.subject, body.text)
        return {"status": "logged"}

    msg = EmailMessage()
    msg["Subject"] = body.subject
    msg["From"] = settings.smtp_from or settings.smtp_user
    msg["To"] = body.to
    if body.reply_to:
        msg["Reply-To"] = body.reply_to
    msg.set_content(body.text)

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
            server.starttls()
            server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)
        return {"status": "sent"}
    except Exception:
        logger.exception("Failed to send feedback email to %s", body.to)
        return {"status": "logged"}
