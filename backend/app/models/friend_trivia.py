from datetime import datetime

from sqlalchemy import (
    Boolean,
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


class FriendTriviaRound(Base):
    """One question about a selected player in a Friend Trivia room."""

    __tablename__ = "friend_trivia_rounds"
    __table_args__ = (
        UniqueConstraint("room_id", "round_number", name="uq_friend_trivia_room_round"),
        CheckConstraint(
            "status IN ('answering', 'guessing', 'completed')",
            name="ck_friend_trivia_round_status",
        ),
        CheckConstraint(
            "correct_choice IS NULL OR correct_choice IN ('A', 'B', 'C', 'D')",
            name="ck_friend_trivia_correct_choice",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(
        ForeignKey("game_rooms.id", ondelete="CASCADE"), nullable=False, index=True
    )
    round_number: Mapped[int] = mapped_column(Integer, nullable=False)
    subject_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    question_text: Mapped[str] = mapped_column(String(500), nullable=False)
    option_a: Mapped[str] = mapped_column(String(250), nullable=False)
    option_b: Mapped[str] = mapped_column(String(250), nullable=False)
    option_c: Mapped[str] = mapped_column(String(250), nullable=False)
    option_d: Mapped[str] = mapped_column(String(250), nullable=False)
    correct_choice: Mapped[str | None] = mapped_column(String(1), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="answering", server_default="answering"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class FriendTriviaGuess(Base):
    """A non-subject participant's guess for one Friend Trivia round."""

    __tablename__ = "friend_trivia_guesses"
    __table_args__ = (
        UniqueConstraint("round_id", "user_id", name="uq_friend_trivia_round_user_guess"),
        CheckConstraint("choice IN ('A', 'B', 'C', 'D')", name="ck_friend_trivia_guess_choice"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    round_id: Mapped[int] = mapped_column(
        ForeignKey("friend_trivia_rounds.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    choice: Mapped[str] = mapped_column(String(1), nullable=False)
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )
