import pytest

from app.models.user import User


@pytest.mark.anyio
async def test_new_user_defaults_to_free_tier(db_session):
    user = User(email="free@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    assert user.subscription_tier == "free"
    assert user.subscription_product_id is None
    assert user.subscription_expires_at is None
    assert user.subscription_original_transaction_id is None
