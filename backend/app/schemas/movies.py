from datetime import date
from pydantic import BaseModel


class MovieInfo(BaseModel):
    movie_id: str
    title: str
    format: str | None = None
    rating: str | None = None
    genre: str | None = None
    cast: str | None = None
    price: str | None = None
    poster_url: str | None = None
    details_url: str


class NowShowingResponse(BaseModel):
    source: str
    count: int
    movies: list[MovieInfo]


class ShowtimeInfo(BaseModel):
    time: str
    booking_url: str


class HallInfo(BaseModel):
    hall: str
    showtimes: list[ShowtimeInfo]


class MovieScheduleInfo(BaseModel):
    movie_id: str
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
