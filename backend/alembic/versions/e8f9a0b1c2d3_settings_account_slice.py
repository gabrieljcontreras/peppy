"""Add the account settings persistence slice.

Revision ID: e8f9a0b1c2d3
Revises: d7e8f9a0b1c2
Create Date: 2026-07-21 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.models.base import GUID

revision: str = "e8f9a0b1c2d3"
down_revision: Union[str, None] = "d7e8f9a0b1c2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("auth_version", sa.Integer(), server_default="1", nullable=False),
    )
    op.add_column(
        "onboarding_profiles",
        sa.Column("baseline_date", sa.Date(), nullable=True),
    )
    op.add_column(
        "onboarding_profiles",
        sa.Column("primary_goal", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "onboarding_profiles",
        sa.Column("secondary_goal", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "onboarding_profiles",
        sa.Column("focus_area", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "dose_reminders_enabled",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "daily_checkin_reminders_enabled",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column("daily_checkin_time", sa.Time(), nullable=True),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "detailed_previews_enabled",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )

    op.create_table(
        "dose_reminder_settings",
        sa.Column("user_id", GUID(length=36), nullable=False),
        sa.Column("compound_id", GUID(length=36), nullable=False),
        sa.Column("local_time", sa.Time(), nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default=sa.true(), nullable=False),
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
        sa.ForeignKeyConstraint(["compound_id"], ["compounds.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "compound_id",
            name="uq_dose_reminder_user_compound",
        ),
    )
    op.create_index(
        op.f("ix_dose_reminder_settings_user_id"),
        "dose_reminder_settings",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_dose_reminder_settings_compound_id"),
        "dose_reminder_settings",
        ["compound_id"],
        unique=False,
    )

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute(sa.text("LOCK TABLE device_tokens IN SHARE ROW EXCLUSIVE MODE"))

    op.execute(
        sa.text(
            """
            DELETE FROM device_tokens
            WHERE id IN (
                SELECT id
                FROM (
                    SELECT
                        id,
                        ROW_NUMBER() OVER (
                            PARTITION BY token
                            ORDER BY updated_at DESC, created_at DESC, id DESC
                        ) AS duplicate_rank
                    FROM device_tokens
                ) AS ranked_device_tokens
                WHERE duplicate_rank > 1
            )
            """
        )
    )
    with op.batch_alter_table("device_tokens") as batch_op:
        batch_op.create_unique_constraint("uq_device_tokens_token", ["token"])


def downgrade() -> None:
    with op.batch_alter_table("device_tokens") as batch_op:
        batch_op.drop_constraint("uq_device_tokens_token", type_="unique")

    op.drop_index(
        op.f("ix_dose_reminder_settings_compound_id"),
        table_name="dose_reminder_settings",
    )
    op.drop_index(
        op.f("ix_dose_reminder_settings_user_id"),
        table_name="dose_reminder_settings",
    )
    op.drop_table("dose_reminder_settings")

    op.drop_column("notification_preferences", "detailed_previews_enabled")
    op.drop_column("notification_preferences", "daily_checkin_time")
    op.drop_column("notification_preferences", "daily_checkin_reminders_enabled")
    op.drop_column("notification_preferences", "dose_reminders_enabled")
    op.drop_column("onboarding_profiles", "focus_area")
    op.drop_column("onboarding_profiles", "secondary_goal")
    op.drop_column("onboarding_profiles", "primary_goal")
    op.drop_column("onboarding_profiles", "baseline_date")
    op.drop_column("users", "auth_version")
