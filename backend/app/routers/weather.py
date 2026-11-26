from datetime import date, time
from fastapi import APIRouter, Query

from app.integration.weather import get_weather_forecast
from app.schemas.weather import WeatherForecast

router = APIRouter(
    prefix="/weather",
    tags=["Weather"],
)


@router.get("/forecast", response_model=WeatherForecast)
def check_weather_forecast(
    target_date: date = Query(default_factory=date.today),
    target_time: time = Query(default=time(17, 0)),
    location: str | None = Query(default=None, max_length=150),
):
    return get_weather_forecast(
        target_date=target_date,
        target_time=target_time,
        location=location,
    )