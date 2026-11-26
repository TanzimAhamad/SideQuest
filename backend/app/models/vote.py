
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class SideQuestVote(Base):
    """One authenticated user's current vote for one entire SideQuest."""

    __tablename__ = "sidequest_votes"

    __table_args__ = (
        UniqueConstraint(
            "sidequest_id",
            "user_id",
            name="uq_sidequest_vote_user_sidequest",
        ),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    sidequest_id: Mapped[int] = mapped_column(
        ForeignKey("sidequests.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    option_id: Mapped[int] = mapped_column(
        ForeignKey("sidequest_options.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    activity: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        index=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
