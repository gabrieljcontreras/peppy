"""add protocol dose logs

Revision ID: c5d6e7f8a9b0
Revises: b4c5d6e7f8a9
Create Date: 2026-07-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.base import GUID


revision: str = "c5d6e7f8a9b0"
down_revision: Union[str, None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "dose_logs",
        sa.Column("user_id", GUID(length=36), nullable=False),
        sa.Column("protocol_id", GUID(length=36), nullable=False),
        sa.Column("compound_id", GUID(length=36), nullable=False),
        sa.Column("dose", sa.Float(), nullable=False),
        sa.Column("unit", sa.String(length=20), nullable=False),
        sa.Column("administered_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("route", sa.String(length=50), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
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
        sa.ForeignKeyConstraint(["protocol_id"], ["protocols.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_dose_logs_user_id"), "dose_logs", ["user_id"], unique=False)
    op.create_index(op.f("ix_dose_logs_protocol_id"), "dose_logs", ["protocol_id"], unique=False)
    op.create_index(op.f("ix_dose_logs_compound_id"), "dose_logs", ["compound_id"], unique=False)
    op.create_index(
        op.f("ix_dose_logs_administered_at"),
        "dose_logs",
        ["administered_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_dose_logs_administered_at"), table_name="dose_logs")
    op.drop_index(op.f("ix_dose_logs_compound_id"), table_name="dose_logs")
    op.drop_index(op.f("ix_dose_logs_protocol_id"), table_name="dose_logs")
    op.drop_index(op.f("ix_dose_logs_user_id"), table_name="dose_logs")
    op.drop_table("dose_logs")
