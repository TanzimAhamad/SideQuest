
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, Field
from pydantic import BaseModel, Field, ConfigDict


OptionCategory = Literal[
    "RESTAURANT",
    "MOVIE",
    "SHOPPING",
    "GAMES",
    "OUTDOOR",
    "OTHER",
]


class SideQuestOptionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)

    address: str | None = Field(
        default=None,
        max_length=500,
    )

    category: OptionCategory

    estimated_cost: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )

    stop_order: int = Field(default=1, ge=1)

    source: Literal["MANUAL"] = "MANUAL"


class SideQuestOptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sidequest_id: int
    name: str
    address: str | None
    category: str
    estimated_cost: Decimal | None
    stop_order: int
    source: str
    external_id: str | None
    details: dict | None
    created_by: int


from pydantic import BaseModel, Field


class MovieOptionCreate(BaseModel):
    movie_id: str = Field(min_length=1, max_length=100)
    hall: str = Field(min_length=1, max_length=100)
    showtime: str = Field(min_length=1, max_length=50)
    stop_order: int = Field(default=1, ge=1)