
from datetime import date

import requests
from fastapi import APIRouter, HTTPException, Query

from app.integration.blockbuster import (
    get_now_showing_movies,
    get_movie_schedule,
)

from app.schemas.movies import (
    NowShowingResponse,
    MovieScheduleResponse,
)

router = APIRouter(
    prefix="/movies",
    tags=["Movies"],
)


@router.get(
    "/now-showing",
    response_model=NowShowingResponse
)
def now_showing():

    try:
        movies = get_now_showing_movies()

        return {
            "source": "Blockbuster Cinemas",
            "count": len(movies),
            "movies": movies,
        }

    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not fetch movies from Blockbuster Cinemas",
        )


@router.get(
    "/schedule",
    response_model=MovieScheduleResponse
)
def movie_schedule(
    target_date: date = Query(default_factory=date.today)
):

    try:
        schedule = get_movie_schedule(target_date.isoformat())

        return {
            "source": "Blockbuster Cinemas",
            "date": target_date,
            "count": len(schedule),
            "schedule": schedule,
        }

    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not fetch schedule from Blockbuster Cinemas",
        )
