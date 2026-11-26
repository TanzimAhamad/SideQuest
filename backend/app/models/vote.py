from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Vote(Base):
    __tablename__ = "votes"

    __table_args__ = (
        UniqueConstraint(
            "sidequest_id",
            "user_id",
            name="unique_vote_per_user_per_sidequest",
        ),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    sidequest_id: Mapped[int] = mapped_column(
        ForeignKey("sidequests.id"),
        nullable=False,
        index=True,
    )

    option_id: Mapped[int] = mapped_column(
        ForeignKey("sidequest_options.id"),
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

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        onupdate=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )