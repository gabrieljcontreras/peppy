"""Add the Insights AI schema slice.

Revision ID: d7e8f9a0b1c2
Revises: c5d6e7f8a9b0
Create Date: 2026-07-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.models.base import GUID

revision: str = "d7e8f9a0b1c2"
down_revision: Union[str, None] = "c5d6e7f8a9b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "insights",
        sa.Column("supporting_data", sa.Text(), nullable=True),
    )
    op.add_column(
        "insights",
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("last_insight_run_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        "weekly_summaries",
        sa.Column("user_id", GUID(length=36), nullable=False),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column("model_used", sa.String(length=100), nullable=True),
        sa.Column("id", GUID(length=36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "week_start",
            name="uq_weekly_summary_user_week",
        ),
    )
    op.create_index(
        op.f("ix_weekly_summaries_user_id"),
        "weekly_summaries",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_weekly_summaries_user_id"),
        table_name="weekly_summaries",
    )
    op.drop_table("weekly_summaries")
    op.drop_column("users", "last_insight_run_at")
    op.drop_column("insights", "snoozed_until")
    op.drop_column("insights", "supporting_data")
