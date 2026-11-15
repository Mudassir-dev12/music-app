"""0002_user_data

Revision ID: 0002_user_data
Revises: 0001_init
Create Date: 2026-11-15 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "0002_user_data"
down_revision = "0001_init"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. tracks (server-managed metadata)
    op.create_table(
        "tracks",
        sa.Column("video_id", sa.String(length=11), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("artist", sa.String(length=255), nullable=False),
        sa.Column("artists_json", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("album", sa.String(length=255), nullable=True),
        sa.Column("album_id", sa.String(length=255), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("thumbnail", sa.Text(), nullable=True),
        sa.Column("is_explicit", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("video_id"),
    )

    # 2. play_history
    op.create_table(
        "play_history",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("video_id", sa.String(length=11), nullable=False),
        sa.Column("played_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("listened_seconds", sa.Integer(), nullable=False),
        sa.Column("client_event_id", sa.String(length=64), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["video_id"], ["tracks.video_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_event_id", name="uq_play_history_user_client_event"),
    )
    op.create_index(
        "ix_play_history_user_played_at",
        "play_history",
        ["user_id", sa.text("played_at DESC")],
        unique=False,
    )

    # 3. liked_tracks
    op.create_table(
        "liked_tracks",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("video_id", sa.String(length=11), nullable=False),
        sa.Column("liked_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["video_id"], ["tracks.video_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "video_id"),
    )

    # 4. playlists
    op.create_table(
        "playlists",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.String(length=300), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_playlists_user_id", "playlists", ["user_id"], unique=False)

    # 5. playlist_tracks
    op.create_table(
        "playlist_tracks",
        sa.Column("playlist_id", sa.String(length=36), nullable=False),
        sa.Column("video_id", sa.String(length=11), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("added_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["playlist_id"], ["playlists.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["video_id"], ["tracks.video_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("playlist_id", "video_id"),
    )
    op.create_index(
        "ix_playlist_tracks_position",
        "playlist_tracks",
        ["playlist_id", "position"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_table("playlist_tracks")
    op.drop_table("playlists")
    op.drop_table("liked_tracks")
    op.drop_table("play_history")
    op.drop_table("tracks")
