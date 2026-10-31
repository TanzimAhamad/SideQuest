from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DirectConversation(Base):
    """A one-to-one conversation between two distinct users."""

    __tablename__ = "direct_conversations"
    __table_args__ = (
        UniqueConstraint(
            "user1_id",
            "user2_id",
            name="uq_direct_conversation_user_pair",
        ),
        CheckConstraint(
            "user1_id < user2_id",
            name="ck_direct_conversation_ordered_users",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Store the smaller user ID first so the same pair cannot create
    # separate conversations in opposite orders.
    user1_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user2_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
