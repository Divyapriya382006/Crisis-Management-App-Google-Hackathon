# routers/stats.py
import httpx
import math
import random
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from core.security import get_current_user
from models.schemas import StatsResponse, WeatherData, SeismicData

router = APIRouter(prefix="/stats", tags=["Statistics"])


# ── Location-based statistics ─────────────────────────────────────────────────
@router.get("/location", response_model=StatsResponse)
async def get_location_stats(
    lat: float = Query(default=13.0827),
    lng: float = Query(default=80.2707),
    current_user: dict = Depends(get_current_user),
):
    """
    Fetch weather, seismic, and ocean stats for a location.
    Tries Open-Meteo (free, no API key) first; falls back to mock data.
    """
    weather = await _fetch_weather(lat, lng)
    seismic = _get_seismic_mock()
    ocean = _get_ocean_mock()

    return StatsResponse(
        weather=weather,
        seismic=seismic,
        location=f"{lat:.4f}, {lng:.4f}",
        ocean=ocean,
    )


async def _fetch_weather(lat: float, lng: float) -> WeatherData:
    """Fetch real weather from Open-Meteo (free, no API key required)."""
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lng}"
            f"&current_weather=true"
            f"&hourly=relativehumidity_2m,windspeed_10m,winddirection_10m"
            f"&forecast_days=1"
        )
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
            data = resp.json()

        cw = data["current_weather"]
        hourly = data.get("hourly", {})
        humidity = hourly.get("relativehumidity_2m", [75])[0]
        wind_dir_deg = hourly.get("winddirection_10m", [45])[0]

        return WeatherData(
            temperature=cw.get("temperature", 32.0),
            humidity=float(humidity),
            condition=_wmo_to_condition(cw.get("weathercode", 0)),
            wind_speed=cw.get("windspeed", 14.0),
            wind_direction=_deg_to_compass(wind_dir_deg),
            updated_at=datetime.utcnow().isoformat(),
        )
    except Exception:
        return _mock_weather()


def _mock_weather() -> WeatherData:
    return WeatherData(
        temperature=32.4,
        humidity=78.0,
        condition="Partly Cloudy",
        wind_speed=14.5,
        wind_direction="NE",
        updated_at=datetime.utcnow().isoformat(),
    )


def _get_seismic_mock() -> SeismicData:
    """Seismic data — mock (replace with USGS API for real data)."""
    return SeismicData(
        magnitude=1.2,
        level="low",
        region="Bay of Bengal",
        last_activity=datetime.utcnow().replace(hour=datetime.utcnow().hour - 3).isoformat(),
    )


def _get_ocean_mock() -> dict:
    return {
        "wave_height_m": 1.2,
        "sea_temp_c": 28,
        "tsunami_risk": "low",
        "tide": "high",
        "updated_at": datetime.utcnow().isoformat(),
    }


def _wmo_to_condition(code: int) -> str:
    """Convert WMO weather code to human-readable string."""
    mapping = {
        0: "Clear Sky", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast",
        45: "Foggy", 48: "Icy Fog",
        51: "Light Drizzle", 53: "Moderate Drizzle", 55: "Dense Drizzle",
        61: "Slight Rain", 63: "Moderate Rain", 65: "Heavy Rain",
        71: "Slight Snowfall", 73: "Moderate Snowfall", 75: "Heavy Snowfall",
        80: "Slight Showers", 81: "Moderate Showers", 82: "Violent Showers",
        95: "Thunderstorm", 96: "Thunderstorm with Hail", 99: "Thunderstorm w/ Heavy Hail",
    }
    return mapping.get(code, "Unknown")


def _deg_to_compass(degrees: float) -> str:
    directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    idx = round(degrees / 45) % 8
    return directions[idx]
