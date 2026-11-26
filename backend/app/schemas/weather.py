from datetime import date
from pydantic import BaseModel


class WeatherForecast(BaseModel):
    available: bool
    source: str = "Open-Meteo"
    location: str
    latitude: float | None = None
    longitude: float | None = None
    forecast_date: date
    forecast_time: str | None = None
    timezone: str | None = None
    weather_code: int | None = None
    condition: str | None = None
    temperature_c: float | None = None
    apparent_temperature_c: float | None = None
    precipitation_probability: int | None = None
    precipitation_mm: float | None = None
    wind_speed_kmh: float | None = None
    daily_temp_min_c: float | None = None
    daily_temp_max_c: float | None = None
    daily_precipitation_probability_max: int | None = None
    outdoor_suitability: str | None = None
    advisory: str