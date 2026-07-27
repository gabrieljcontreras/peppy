"""Add the premium subscription slice.

Revision ID: f9a0b1c2d3e4
Revises: e8f9a0b1c2d3
Create Date: 2026-07-26 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "f9a0b1c2d3e4"
down_revision: Union[str, None] = "e8f9a0b1c2d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "subscription_tier",
            sa.String(length=20),
            server_default="free",
            nullable=False,
        ),
    )
    op.add_column(
        "users", sa.Column("subscription_product_id", sa.String(length=100), nullable=True)
    )
    op.add_column(
        "users", sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(
        "users",
        sa.Column("subscription_original_transaction_id", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "users", sa.Column("subscription_updated_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_index(
        "ix_users_subscription_original_transaction_id",
        "users",
        ["subscription_original_transaction_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_users_subscription_original_transaction_id", table_name="users")
    op.drop_column("users", "subscription_updated_at")
    op.drop_column("users", "subscription_original_transaction_id")
    op.drop_column("users", "subscription_expires_at")
    op.drop_column("users", "subscription_product_id")
    op.drop_column("users", "subscription_tier")
