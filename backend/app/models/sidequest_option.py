
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class SideQuestOption(Base):
    __tablename__ = "sidequest_options"

    __table_args__ = (
        CheckConstraint(
            "estimated_cost >= 0",
            name="check_option_estimated_cost",
        ),
        CheckConstraint(
            "stop_order >= 1",
            name="check_option_stop_order",
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

    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    address: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    category: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    estimated_cost: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

    stop_order: Mapped[int] = mapped_column(
        Integer,
        default=1,
        nullable=False,
    )

    source: Mapped[str] = mapped_column(
        String(30),
        default="MANUAL",
        nullable=False,
    )

    external_id: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    details: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )

    created_by: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )
