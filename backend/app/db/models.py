import datetime
import uuid
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    refresh_tokens = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    audio_usages = relationship(
        "AudioUsage",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    playlists = relationship(
        "Playlist",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    liked_tracks = relationship(
        "LikedTrack",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    play_history = relationship(
        "PlayHistory",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    download_usages = relationship(
        "DownloadUsage",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    family_id = Column(String(36), nullable=False, index=True)
    token_hash = Column(String(64), unique=True, nullable=False, index=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    replaced_by = Column(String(36), nullable=True)
    user_agent = Column(String(200), nullable=True)
    ip_hash = Column(String(64), nullable=True)

    user = relationship("User", back_populates="refresh_tokens")


class AudioUsage(Base):
    __tablename__ = "audio_usage"

    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    day = Column(Date, primary_key=True, nullable=False)
    bytes = Column(Integer, default=0, nullable=False)

    user = relationship("User", back_populates="audio_usages")


class DownloadUsage(Base):
    __tablename__ = "download_usage"

    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    day = Column(Date, primary_key=True, nullable=False)
    bytes = Column(Integer, default=0, nullable=False)

    user = relationship("User", back_populates="download_usages")


class Track(Base):
    __tablename__ = "tracks"

    video_id = Column(String(11), primary_key=True)
    title = Column(String(255), nullable=False)
    artist = Column(String(255), nullable=False)
    artists_json = Column(Text, nullable=False, default="[]")
    album = Column(String(255), nullable=True)
    album_id = Column(String(255), nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    thumbnail = Column(Text, nullable=True)
    is_explicit = Column(Boolean, default=False, nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )


class PlayHistory(Base):
    __tablename__ = "play_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    video_id = Column(
        String(11),
        ForeignKey("tracks.video_id", ondelete="CASCADE"),
        nullable=False,
    )
    played_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )
    listened_seconds = Column(Integer, nullable=False)
    client_event_id = Column(String(64), nullable=False)

    __table_args__ = (
        Index("ix_play_history_user_played_at", "user_id", played_at.desc()),
        UniqueConstraint("user_id", "client_event_id", name="uq_play_history_user_client_event"),
    )

    user = relationship("User", back_populates="play_history")
    track = relationship("Track")


class LikedTrack(Base):
    __tablename__ = "liked_tracks"

    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    video_id = Column(
        String(11),
        ForeignKey("tracks.video_id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    liked_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )

    user = relationship("User", back_populates="liked_tracks")
    track = relationship("Track")


class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name = Column(String(100), nullable=False)
    description = Column(String(300), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )

    user = relationship("User", back_populates="playlists")
    tracks = relationship(
        "PlaylistTrack",
        back_populates="playlist",
        cascade="all, delete-orphan",
        order_by="PlaylistTrack.position",
        passive_deletes=True,
    )


class PlaylistTrack(Base):
    __tablename__ = "playlist_tracks"

    playlist_id = Column(
        String(36),
        ForeignKey("playlists.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    video_id = Column(
        String(11),
        ForeignKey("tracks.video_id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    position = Column(Integer, nullable=False)
    added_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.datetime.now(datetime.timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_playlist_tracks_position", "playlist_id", "position"),
    )

    playlist = relationship("Playlist", back_populates="tracks")
    track = relationship("Track")

