"""0003_download_usage

Revision ID: 0003_download_usage
Revises: 0002_user_data
Create Date: 2026-11-17 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "0003_download_usage"
down_revision = "0002_user_data"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "download_usage",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("bytes", sa.Integer(), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "day"),
    )


def downgrade() -> None:
    op.drop_table("download_usage")

