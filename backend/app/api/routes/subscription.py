from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.schemas.subscription import AppleTransactionRequest, SubscriptionResponse
from app.database import get_db
from app.services.subscription import (
    AppleTransactionError,
    apply_transaction,
    current_entitlement,
    decode_apple_transaction,
)

router = APIRouter()


@router.get("", response_model=SubscriptionResponse)
async def get_subscription(current_user: CurrentUser):
    return current_entitlement(current_user)


@router.post("/apple", response_model=SubscriptionResponse)
async def sync_apple_transaction(
    request: AppleTransactionRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        payload = decode_apple_transaction(request.signed_transaction)
    except AppleTransactionError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc

    user = await apply_transaction(db, current_user, payload)
    return current_entitlement(user)
