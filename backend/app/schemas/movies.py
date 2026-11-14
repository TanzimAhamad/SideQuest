
from datetime import date
from pydantic import BaseModel


# -------------------------
# NOW SHOWING MODELS
# -------------------------

class MovieInfo(BaseModel):
    movie_id: str
    title: str
    format: str
    rating: str | None = None
    genre: str
    cast: str
    price: str
    poster_url: str
    details_url: str


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
    hall: str
    showtimes: list[ShowtimeInfo]


class MovieScheduleInfo(BaseModel):
    movie_id: str
    title: str
    format_and_genre: str
    poster_url: str
    halls: list[HallInfo]
    date: date


class MovieScheduleResponse(BaseModel):
    source: str
    date: date
    count: int
    schedule: list[MovieScheduleInfo]
