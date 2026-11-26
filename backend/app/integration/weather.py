from datetime import date, time as dt_time
import time
import requests

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"

DEFAULT_LOCATION_NAME = "Dhaka, Bangladesh"
DEFAULT_LATITUDE = 23.8103
DEFAULT_LONGITUDE = 90.4125

CACHE_DURATION = 15 * 60  # 15 minutes
_geocode_cache: dict[str, tuple[float, dict]] = {}
_forecast_cache: dict[tuple, tuple[float, dict]] = {}

WMO_WEATHER_CODES: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Foggy",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    56: "Light freezing drizzle",
    57: "Dense freezing drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    66: "Light freezing rain",
    67: "Heavy freezing rain",
    71: "Slight snow fall",
    73: "Moderate snow fall",
    75: "Heavy snow fall",
    77: "Snow grains",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    85: "Slight snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}


def _unavailable_response(
    target_date: date,
    location_label: str,
    advisory: str,
) -> dict:
    return {
        "available": False,
        "source": "Open-Meteo",
        "location": location_label,
        "latitude": None,
        "longitude": None,
        "forecast_date": target_date.isoformat(),
        "forecast_time": None,
        "timezone": None,
        "weather_code": None,
        "condition": None,
        "temperature_c": None,
        "apparent_temperature_c": None,
        "precipitation_probability": None,
        "precipitation_mm": None,
        "wind_speed_kmh": None,
        "daily_temp_min_c": None,
        "daily_temp_max_c": None,
        "daily_precipitation_probability_max": None,
        "outdoor_suitability": None,
        "advisory": advisory,
    }


def geocode_location(location: str) -> dict | None:
    """Resolve a city or area name to latitude/longitude using Open-Meteo Geocoding."""
    key = location.strip().casefold()
    now = time.time()

    cached = _geocode_cache.get(key)
    if cached and (now - cached[0] < CACHE_DURATION):
        return cached[1]

    response = requests.get(
        GEOCODING_URL,
        params={
            "name": location.strip(),
            "count": 1,
            "language": "en",
            "format": "json",
        },
        timeout=10,
    )
    response.raise_for_status()
    results = response.json().get("results") or []

    if not results:
        return None

    top = results[0]
    name = top.get("name", location.strip())
    country = top.get("country")
    resolved = {
        "name": f"{name}, {country}" if country else name,
        "latitude": float(top["latitude"]),
        "longitude": float(top["longitude"]),
    }
    _geocode_cache[key] = (now, resolved)
    return resolved


def evaluate_outdoor_suitability(
    weather_code: int | None,
    precipitation_probability: int | None,
    precipitation_mm: float | None,
    temperature_c: float | None,
    wind_speed_kmh: float | None,
) -> tuple[str, str]:
    """Rate outdoor hangout suitability and generate a human-readable advisory."""
    severe_codes = {65, 67, 75, 81, 82, 86, 95, 96, 99}
    caution_codes = {45, 48, 51, 53, 55, 56, 57, 61, 63, 66, 71, 73, 77, 80, 85}

    rain_prob = precipitation_probability or 0
    rain_mm = precipitation_mm or 0.0
    wind = wind_speed_kmh or 0.0

    if (weather_code in severe_codes) or rain_prob >= 60 or rain_mm >= 2.0:
        return (
            "POOR",
            "High chance of rain or severe weather — consider an indoor backup plan.",
        )

    if (
        (weather_code in caution_codes)
        or rain_prob >= 30
        or wind >= 30.0
        or (temperature_c is not None and (temperature_c >= 36.0 or temperature_c <= 10.0))
    ):
        return (
            "CAUTION",
            "Mixed weather conditions expected — check updates closer to the hangout.",
        )

    return (
        "GOOD",
        "Weather looks favorable for outdoor hangout plans.",
    )


def get_weather_forecast(
    target_date: date,
    target_time: dt_time,
    location: str | None = None,
) -> dict:
    """Fetch weather forecast for a specific date, time, and optional location."""
    clean_location = location.strip() if location and location.strip() else None
    location_label = clean_location or DEFAULT_LOCATION_NAME

    days_ahead = (target_date - date.today()).days
    if days_ahead < 0:
        return _unavailable_response(
            target_date,
            location_label,
            "Weather forecast is not available for past dates.",
        )

    if days_ahead > 15:
        return _unavailable_response(
            target_date,
            location_label,
            "Forecast is only available within 16 days of today. Check back closer to the date.",
        )

    try:
        if clean_location:
            geo = geocode_location(clean_location)
            if geo is None:
                return _unavailable_response(
                    target_date,
                    clean_location,
                    f"Could not find location '{clean_location}'. Try a major city name.",
                )
            lat = geo["latitude"]
            lon = geo["longitude"]
            resolved_name = geo["name"]
        else:
            lat = DEFAULT_LATITUDE
            lon = DEFAULT_LONGITUDE
            resolved_name = DEFAULT_LOCATION_NAME

        matched_hour = min(
            23,
            target_time.hour + (1 if target_time.minute >= 30 else 0),
        )
        cache_key = (
            round(lat, 4),
            round(lon, 4),
            target_date.isoformat(),
            matched_hour,
        )

        now = time.time()
        cached = _forecast_cache.get(cache_key)
        if cached and (now - cached[0] < CACHE_DURATION):
            return dict(cached[1])

        response = requests.get(
            FORECAST_URL,
            params={
                "latitude": lat,
                "longitude": lon,
                "hourly": (
                    "temperature_2m,apparent_temperature,"
                    "precipitation_probability,precipitation,"
                    "weather_code,wind_speed_10m"
                ),
                "daily": (
                    "weather_code,temperature_2m_max,"
                    "temperature_2m_min,precipitation_probability_max"
                ),
                "timezone": "auto",
                "start_date": target_date.isoformat(),
                "end_date": target_date.isoformat(),
            },
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()

        hourly = data.get("hourly") or {}
        hourly_times = hourly.get("time") or []
        if not hourly_times:
            return _unavailable_response(
                target_date,
                resolved_name,
                "Hourly weather data was not returned for this date.",
            )

        target_slot = f"{target_date.isoformat()}T{matched_hour:02d}:00"
        if target_slot in hourly_times:
            idx = hourly_times.index(target_slot)
        else:
            idx = min(matched_hour, len(hourly_times) - 1)

        def _pick(series_name: str):
            values = hourly.get(series_name) or []
            return values[idx] if idx < len(values) else None

        weather_code = _pick("weather_code")
        temperature_c = _pick("temperature_2m")
        apparent_temperature_c = _pick("apparent_temperature")
        precipitation_probability = _pick("precipitation_probability")
        precipitation_mm = _pick("precipitation")
        wind_speed_kmh = _pick("wind_speed_10m")

        daily = data.get("daily") or {}
        daily_min_list = daily.get("temperature_2m_min") or []
        daily_max_list = daily.get("temperature_2m_max") or []
        daily_rain_list = daily.get("precipitation_probability_max") or []

        condition = WMO_WEATHER_CODES.get(weather_code, "Unknown") if weather_code is not None else None
        suitability, advisory = evaluate_outdoor_suitability(
            weather_code=weather_code,
            precipitation_probability=precipitation_probability,
            precipitation_mm=precipitation_mm,
            temperature_c=temperature_c,
            wind_speed_kmh=wind_speed_kmh,
        )

        forecast = {
            "available": True,
            "source": "Open-Meteo",
            "location": resolved_name,
            "latitude": lat,
            "longitude": lon,
            "forecast_date": target_date.isoformat(),
            "forecast_time": f"{matched_hour:02d}:00",
            "timezone": data.get("timezone"),
            "weather_code": weather_code,
            "condition": condition,
            "temperature_c": temperature_c,
            "apparent_temperature_c": apparent_temperature_c,
            "precipitation_probability": precipitation_probability,
            "precipitation_mm": precipitation_mm,
            "wind_speed_kmh": wind_speed_kmh,
            "daily_temp_min_c": daily_min_list[0] if daily_min_list else None,
            "daily_temp_max_c": daily_max_list[0] if daily_max_list else None,
            "daily_precipitation_probability_max": daily_rain_list[0] if daily_rain_list else None,
            "outdoor_suitability": suitability,
            "advisory": advisory,
        }

        _forecast_cache[cache_key] = (now, forecast)
        return dict(forecast)

    except requests.RequestException:
        return _unavailable_response(
            target_date,
            location_label,
            "Weather service is temporarily unavailable. SideQuest was saved without forecast data.",
        )