# routers/location.py
import math
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from core.database import get_db
from core.security import get_current_user
from models.db_models import MapLocation
from models.schemas import MapLocationResponse

router = APIRouter(prefix="/location", tags=["Location Services"])


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine formula — great-circle distance between two points in km."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


# ── Nearby facilities ─────────────────────────────────────────────────────────
@router.get("/nearby", response_model=list[MapLocationResponse])
async def get_nearby_locations(
    lat: float = Query(default=13.0827, description="User latitude"),
    lng: float = Query(default=80.2707, description="User longitude"),
    radius_km: float = Query(default=15.0, le=100),
    type: str = Query(default="all"),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return locations within radius_km of the user, optionally filtered by type."""
    query = select(MapLocation).where(MapLocation.is_open == True)
    if type != "all":
        query = query.where(MapLocation.type == type)

    result = await db.execute(query)
    locations = result.scalars().all()

    # Filter by actual distance & sort
    nearby = sorted(
        [loc for loc in locations if haversine_km(lat, lng, loc.latitude, loc.longitude) <= radius_km],
        key=lambda loc: haversine_km(lat, lng, loc.latitude, loc.longitude),
    )

    # Fallback to mock data if DB empty
    if not nearby:
        return _mock_locations()

    return [MapLocationResponse.model_validate(loc) for loc in nearby]


# ── Get all locations (for map display) ───────────────────────────────────────
@router.get("/all", response_model=list[MapLocationResponse])
async def get_all_locations(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(MapLocation).where(MapLocation.is_open == True))
    locations = result.scalars().all()
    if not locations:
        return _mock_locations()
    return [MapLocationResponse.model_validate(loc) for loc in locations]


# ── Mock location seed ─────────────────────────────────────────────────────────
def _mock_locations() -> list[MapLocationResponse]:
    return [
        MapLocationResponse(id="l1", type="hospital", name="Rajiv Gandhi Govt. Hospital", latitude=13.0865, longitude=80.2784, address="Park Town, Chennai", phone="044-25305000", is_open=True, capacity=None),
        MapLocationResponse(id="l2", type="hospital", name="Government Stanley Hospital", latitude=13.0943, longitude=80.2773, address="Old Jail Road, Chennai", phone="044-25281361", is_open=True, capacity=None),
        MapLocationResponse(id="l3", type="shelter", name="Nehru Indoor Stadium", latitude=13.0844, longitude=80.2717, address="ICF, Chennai", is_open=True, capacity=2000),
        MapLocationResponse(id="l4", type="shelter", name="YMCA Grounds Nandanam", latitude=13.0274, longitude=80.2337, address="Nandanam, Chennai", is_open=True, capacity=500),
        MapLocationResponse(id="l5", type="safe_building", name="DRJ Convention Centre", latitude=13.0765, longitude=80.2620, address="Teynampet, Chennai", is_open=True, capacity=None),
        MapLocationResponse(id="l6", type="rescue", name="NDRF Rescue Camp", latitude=13.0600, longitude=80.2500, address="Central Chennai", is_open=True, capacity=None),
    ]
