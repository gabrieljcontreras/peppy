from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AppleTransactionRequest(BaseModel):
    signed_transaction: str = Field(..., min_length=1)


class SubscriptionResponse(BaseModel):
    tier: str
    product_id: Optional[str] = None
    expires_at: Optional[datetime] = None
    is_premium: bool
