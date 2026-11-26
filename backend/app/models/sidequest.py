from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    JSON,
    Numeric,
    String,
    Text,
    Time,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class SideQuest(Base):
    __tablename__ = "sidequests"

    __table_args__ = (
        CheckConstraint(
            "budget_min >= 0",
            name="check_sidequest_budget_min",
        ),
        CheckConstraint(
            "budget_max >= budget_min",
            name="check_sidequest_budget_range",
        ),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    activity_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    location: Mapped[str | None] = mapped_column(
        String(150),
        nullable=True,
    )

    proposed_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    proposed_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    budget_min: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )

    budget_max: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )

    weather_forecast: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )

    created_by: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    group_id: Mapped[int] = mapped_column(
        ForeignKey("groups.id"),
        nullable=False,
        index=True,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="OPEN",
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("CURRENT_TIMESTAMP"),
        nullable=False,
    )