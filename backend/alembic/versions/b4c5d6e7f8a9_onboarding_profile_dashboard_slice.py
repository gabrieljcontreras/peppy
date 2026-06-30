"""add onboarding profile dashboard slice

Revision ID: b4c5d6e7f8a9
Revises: a3f1c2d4e5b6
Create Date: 2026-06-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.base import GUID


revision: str = "b4c5d6e7f8a9"
down_revision: Union[str, None] = "a3f1c2d4e5b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if "onboarding_profiles" not in tables:
        op.create_table(
            "onboarding_profiles",
            sa.Column("user_id", GUID(length=36), nullable=False),
            sa.Column("schema_version", sa.Integer(), server_default=sa.text("1"), nullable=False),
            sa.Column("age", sa.Integer(), nullable=True),
            sa.Column("height_cm", sa.Float(), nullable=True),
            sa.Column("preferred_height_unit", sa.String(length=10), nullable=True),
            sa.Column("weight_kg", sa.Float(), nullable=True),
            sa.Column("preferred_weight_unit", sa.String(length=10), nullable=True),
            sa.Column("peptides", sa.JSON(), nullable=False),
            sa.Column("custom_peptides", sa.JSON(), nullable=False),
            sa.Column("other_medications", sa.String(length=200), nullable=True),
            sa.Column("workout_days_per_week", sa.Integer(), nullable=True),
            sa.Column("goals", sa.JSON(), nullable=False),
            sa.Column("custom_goal", sa.String(length=200), nullable=True),
            sa.Column("healthkit_requested", sa.Boolean(), nullable=True),
            sa.Column("healthkit_last_sync_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("notifications_authorized", sa.Boolean(), nullable=True),
            sa.Column("source_draft_id", sa.String(length=200), nullable=True),
            sa.Column("source_draft_created_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("source_draft_updated_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("source_current_step", sa.String(length=100), nullable=True),
            sa.Column("source_is_complete", sa.Boolean(), nullable=True),
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
            sa.CheckConstraint("schema_version = 1", name="ck_onboarding_profiles_schema_version"),
            sa.CheckConstraint("age IS NULL OR age BETWEEN 13 AND 120", name="ck_onboarding_profiles_age"),
            sa.CheckConstraint(
                "height_cm IS NULL OR height_cm BETWEEN 100 AND 250",
                name="ck_onboarding_profiles_height_cm",
            ),
            sa.CheckConstraint(
                "preferred_height_unit IS NULL OR preferred_height_unit IN ('ft_in', 'cm')",
                name="ck_onboarding_profiles_preferred_height_unit",
            ),
            sa.CheckConstraint(
                "weight_kg IS NULL OR weight_kg BETWEEN 27 AND 318",
                name="ck_onboarding_profiles_weight_kg",
            ),
            sa.CheckConstraint(
                "preferred_weight_unit IS NULL OR preferred_weight_unit IN ('lb', 'kg')",
                name="ck_onboarding_profiles_preferred_weight_unit",
            ),
            sa.CheckConstraint(
                "workout_days_per_week IS NULL OR workout_days_per_week BETWEEN 0 AND 7",
                name="ck_onboarding_profiles_workout_days_per_week",
            ),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            op.f("ix_onboarding_profiles_user_id"),
            "onboarding_profiles",
            ["user_id"],
            unique=True,
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    if "onboarding_profiles" in inspector.get_table_names():
        op.drop_index(op.f("ix_onboarding_profiles_user_id"), table_name="onboarding_profiles")
        op.drop_table("onboarding_profiles")
