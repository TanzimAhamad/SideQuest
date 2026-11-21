
from datetime import date

from pydantic import BaseModel


# -------------------------
# NOW SHOWING MODELS
# -------------------------

class MovieInfo(BaseModel):
    movie_id: str | None = None
    title: str
    format: str | None = None
    rating: str | None = None
    genre: str | None = None
    cast: str | None = None
    price: str | None = None
    poster_url: str | None = None
    details_url: str | None = None


class NowShowingResponse(BaseModel):
    source: str
    count: int
    movies: list[MovieInfo]


# -------------------------
# SCHEDULE MODELS
# -------------------------

class ShowtimeInfo(BaseModel):
    time: str
    booking_url: str


class HallInfo(BaseModel):
    hall: str | None = None
    showtimes: list[ShowtimeInfo]


class MovieScheduleInfo(BaseModel):
    movie_id: str | None = None
    title: str
    format_and_genre: str | None = None
    poster_url: str | None = None
    halls: list[HallInfo]
    date: date


class MovieScheduleResponse(BaseModel):
    source: str
    date: date
    count: int
    schedule: list[MovieScheduleInfo]
