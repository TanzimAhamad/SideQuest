from datetime import date, time, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field, ConfigDict, model_validator

from app.schemas.weather import WeatherForecast


ActivityType = Literal[
    "RESTAURANT",
    "MOVIE",
    "SHOPPING",
    "GAMES",
    "OUTDOOR",
    "OTHER",
]


class SideQuestCreate(BaseModel):
    title: str = Field(min_length=3, max_length=150)
    description: str | None = None

    activity_type: ActivityType
    location: str | None = Field(default=None, max_length=150)

    proposed_date: date
    proposed_time: time

    budget_min: Decimal = Field(
        ge=0, max_digits=10, decimal_places=2
    )
    budget_max: Decimal = Field(
        ge=0, max_digits=10, decimal_places=2
    )

    group_id: int = Field(gt=0)

    @model_validator(mode="after")
    def validate_budget_range(self):
        if self.budget_max < self.budget_min:
            raise ValueError(
                "Maximum budget cannot be less than minimum budget"
            )
        return self


class SideQuestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    activity_type: str
    location: str | None = None
    proposed_date: date
    proposed_time: time
    budget_min: Decimal
    budget_max: Decimal
    weather_forecast: WeatherForecast | None = None
    created_by: int
    group_id: int
    status: str
    created_at: datetime