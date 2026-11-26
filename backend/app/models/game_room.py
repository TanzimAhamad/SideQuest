from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class GameRoom(Base):
    __tablename__ = "game_rooms"
    __table_args__ = (
        CheckConstraint(
            "game_type IN ('friend_trivia', 'would_you_rather')",
            name="ck_game_rooms_game_type",
        ),
        CheckConstraint(
            "status IN ('lobby', 'in_progress', 'completed')",
            name="ck_game_rooms_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    game_type: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    host_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="lobby", server_default="lobby"
    )
    max_players: Mapped[int] = mapped_column(Integer, nullable=False, default=8)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class GameRoomParticipant(Base):
    __tablename__ = "game_room_participants"
    __table_args__ = (
        UniqueConstraint("room_id", "user_id", name="uq_game_room_participant"),
        CheckConstraint(
            "invitation_status IN ('invited', 'accepted', 'declined')",
            name="ck_game_room_invitation_status",
        ),
        CheckConstraint(
            "role IN ('host', 'player')",
            name="ck_game_room_participant_role",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(
        ForeignKey("game_rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(20), nullable=False, default="player", server_default="player"
    )
    invitation_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="invited", server_default="invited"
    )
    invited_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class WouldYouRatherRound(Base):
    __tablename__ = "would_you_rather_rounds"
    __table_args__ = (
        UniqueConstraint("room_id", "round_number", name="uq_wyr_room_round"),
        CheckConstraint(
            "status IN ('active', 'completed')",
            name="ck_wyr_round_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(
        ForeignKey("game_rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    round_number: Mapped[int] = mapped_column(Integer, nullable=False)
    question_text: Mapped[str] = mapped_column(String(500), nullable=False)
    option_a: Mapped[str] = mapped_column(String(300), nullable=False)
    option_b: Mapped[str] = mapped_column(String(300), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="active", server_default="active"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class WouldYouRatherVote(Base):
    __tablename__ = "would_you_rather_votes"
    __table_args__ = (
        UniqueConstraint("round_id", "user_id", name="uq_wyr_round_user_vote"),
        CheckConstraint("choice IN ('A', 'B')", name="ck_wyr_vote_choice"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    round_id: Mapped[int] = mapped_column(
        ForeignKey("would_you_rather_rounds.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    choice: Mapped[str] = mapped_column(String(1), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
