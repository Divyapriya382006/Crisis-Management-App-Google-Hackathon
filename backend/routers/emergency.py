# routers/emergency.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from core.database import get_db
from core.security import get_current_user
from models.db_models import EmergencyRequest, User
from models.schemas import (
    EmergencyRequestCreate, EmergencyRequestResponse, UpdateRequestStatus
)

router = APIRouter(prefix="/emergency", tags=["Emergency Requests"])

# ── Priority assignment logic ─────────────────────────────────────────────────
PRIORITY_MAP = {
    "boat": "critical",
    "helicopter": "critical",
    "medical": "critical",
    "water": "high",
    "evacuation": "high",
    "shelter": "high",
    "food": "medium",
    "electricity": "medium",
}


def assign_priority(request_type: str) -> str:
    """Auto-assign priority based on request type."""
    return PRIORITY_MAP.get(request_type, "medium")


# ── Submit emergency request ──────────────────────────────────────────────────
@router.post("/request", response_model=EmergencyRequestResponse)
async def create_request(
    payload: EmergencyRequestCreate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Submit an emergency assistance request.
    Location is auto-attached from the payload (sent by client GPS).
    Priority is auto-assigned based on request type.
    """
    priority = assign_priority(payload.type)

    req = EmergencyRequest(
        user_id=current_user["id"],
        type=payload.type,
        priority=priority,
        status="pending",
        latitude=payload.latitude,
        longitude=payload.longitude,
        description=payload.description,
        contact_number=payload.contact_number,
    )
    db.add(req)
    await db.flush()
    return EmergencyRequestResponse.model_validate(req)


# ── Get user's own requests ───────────────────────────────────────────────────
@router.get("/my-requests", response_model=list[EmergencyRequestResponse])
async def get_my_requests(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(EmergencyRequest)
        .where(EmergencyRequest.user_id == current_user["id"])
        .order_by(EmergencyRequest.created_at.desc())
        .limit(50)
    )
    return [EmergencyRequestResponse.model_validate(r) for r in result.scalars().all()]


# ── Get a single request ──────────────────────────────────────────────────────
@router.get("/request/{request_id}", response_model=EmergencyRequestResponse)
async def get_request(
    request_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(EmergencyRequest).where(EmergencyRequest.id == request_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    # Users can only view their own requests; admins can view all
    if current_user["role"] != "admin" and req.user_id != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied")
    return EmergencyRequestResponse.model_validate(req)


# ── Update request status (admin) ─────────────────────────────────────────────
@router.patch("/request/{request_id}/status", response_model=EmergencyRequestResponse)
async def update_status(
    request_id: str,
    payload: UpdateRequestStatus,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user["role"] not in ("admin", "rescuer"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    result = await db.execute(select(EmergencyRequest).where(EmergencyRequest.id == request_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    req.status = payload.status
    if payload.assigned_to:
        req.assigned_to = payload.assigned_to

    return EmergencyRequestResponse.model_validate(req)


# ── Nearby requests (location-based) ─────────────────────────────────────────
@router.get("/nearby", response_model=list[EmergencyRequestResponse])
async def get_nearby_requests(
    lat: float,
    lng: float,
    radius_km: float = 10.0,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get requests within a radius (km) of a coordinate.
    Uses Haversine approximation via bounding box for SQLite compatibility.
    """
    # Approximate 1 degree lat/lng ≈ 111 km
    lat_delta = radius_km / 111.0
    lng_delta = radius_km / (111.0 * abs(max(0.01, __import__('math').cos(__import__('math').radians(lat)))))

    result = await db.execute(
        select(EmergencyRequest)
        .where(
            EmergencyRequest.latitude.between(lat - lat_delta, lat + lat_delta),
            EmergencyRequest.longitude.between(lng - lng_delta, lng + lng_delta),
            EmergencyRequest.status.in_(["pending", "accepted", "in_progress"]),
        )
        .order_by(EmergencyRequest.priority.desc(), EmergencyRequest.created_at.desc())
        .limit(50)
    )
    return [EmergencyRequestResponse.model_validate(r) for r in result.scalars().all()]
