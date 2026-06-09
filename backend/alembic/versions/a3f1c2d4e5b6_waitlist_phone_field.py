"""add waitlist_entries table with phone and optional email

Revision ID: a3f1c2d4e5b6
Revises: 19381cefe6c7
Create Date: 2026-06-09 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from app.models.base import GUID


revision: str = "a3f1c2d4e5b6"
down_revision: Union[str, None] = "19381cefe6c7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if "waitlist_entries" not in tables:
        op.create_table(
            "waitlist_entries",
            sa.Column("phone", sa.String(20), nullable=True),
            sa.Column("email", sa.String(320), nullable=True),
            sa.Column("id", GUID(length=36), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_waitlist_entries_phone"), "waitlist_entries", ["phone"], unique=True)
        op.create_index(op.f("ix_waitlist_entries_email"), "waitlist_entries", ["email"], unique=True)
    else:
        op.add_column("waitlist_entries", sa.Column("phone", sa.String(20), nullable=True))
        op.create_index(op.f("ix_waitlist_entries_phone"), "waitlist_entries", ["phone"], unique=True)
        with op.batch_alter_table("waitlist_entries") as batch_op:
            batch_op.alter_column("email", existing_type=sa.String(320), nullable=True)


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [c["name"] for c in inspector.get_columns("waitlist_entries")]

    if "phone" in columns:
        op.drop_index(op.f("ix_waitlist_entries_phone"), table_name="waitlist_entries")
        op.drop_column("waitlist_entries", "phone")

    with op.batch_alter_table("waitlist_entries") as batch_op:
        batch_op.alter_column("email", existing_type=sa.String(320), nullable=False)
