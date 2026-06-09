import logging
from twilio.rest import Client

from app.config import get_settings

logger = logging.getLogger(__name__)


def send_sms(to: str, body: str) -> bool:
    settings = get_settings()

    if not all([settings.twilio_account_sid, settings.twilio_auth_token, settings.twilio_phone_number]):
        logger.warning("Twilio credentials not configured — skipping SMS to %s", to)
        return False

    try:
        client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
        client.messages.create(
            to=to,
            from_=settings.twilio_phone_number,
            body=body,
        )
        return True
    except Exception:
        logger.exception("Failed to send SMS to %s", to)
        return False
