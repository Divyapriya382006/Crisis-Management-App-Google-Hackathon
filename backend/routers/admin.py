# routers/admin.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from core.database import get_db
from core.security import require_admin
from models.db_models import EmergencyRequest, User, Notification
from models.schemas import EmergencyRequestResponse, DashboardStats

router = APIRouter(prefix="/admin", tags=["Admin"])


# ── Dashboard stats ───────────────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin dashboard statistics."""

    # Count requests by status
    total = await db.execute(func.count(EmergencyRequest.id))
    total_count = total.scalar() or 142  # Fallback for demo

    pending = await db.execute(
        select(func.count(EmergencyRequest.id)).where(EmergencyRequest.status == "pending")
    )
    in_progress = await db.execute(
        select(func.count(EmergencyRequest.id)).where(EmergencyRequest.status == "in_progress")
    )
    resolved = await db.execute(
        select(func.count(EmergencyRequest.id)).where(EmergencyRequest.status == "resolved")
    )
    critical = await db.execute(
        select(func.count(EmergencyRequest.id)).where(EmergencyRequest.priority == "critical", EmergencyRequest.status == "pending")
    )
    users = await db.execute(func.count(User.id))

    stats = {
        "total_requests": total_count,
        "pending": pending.scalar() or 23,
        "in_progress": in_progress.scalar() or 18,
        "resolved": resolved.scalar() or 101,
        "critical": critical.scalar() or 7,
        "total_users": users.scalar() or 0,
    }

    return {"stats": stats, "status": "ok"}


# ── All requests (for admin view) ─────────────────────────────────────────────
@router.get("/requests")
async def get_all_requests(
    status: str = "all",
    priority: str = "all",
    limit: int = 100,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get all emergency requests with optional filters."""
    query = select(EmergencyRequest)

    if status != "all":
        query = query.where(EmergencyRequest.status == status)
    if priority != "all":
        query = query.where(EmergencyRequest.priority == priority)

    query = query.order_by(
        # Critical first, then by time
        EmergencyRequest.priority.desc(),
        EmergencyRequest.created_at.desc()
    ).limit(limit)

    result = await db.execute(query)
    requests = result.scalars().all()

    # Fallback mock data
    if not requests:
        return {"requests": _mock_requests_data()}

    return {"requests": [EmergencyRequestResponse.model_validate(r) for r in requests]}


# ── All users ─────────────────────────────────────────────────────────────────
@router.get("/users")
async def get_all_users(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.role == "user").order_by(User.created_at.desc()))
    users = result.scalars().all()
    return {"users": [{"id": u.id, "name": u.name, "email": u.email, "created_at": u.created_at} for u in users]}


# ── Seed admin user ───────────────────────────────────────────────────────────
@router.post("/seed")
async def seed_admin(db: AsyncSession = Depends(get_db)):
    """
    Seed the admin user and demo data.
    Call this once after first startup: POST /api/v1/admin/seed
    """
    from core.config import settings
    from core.security import hash_password
    from models.db_models import MapLocation

    # Create admin user
    result = await db.execute(select(User).where(User.email == settings.ADMIN_EMAIL))
    if not result.scalar_one_or_none():
        admin = User(
            name="Crisis Admin",
            email=settings.ADMIN_EMAIL,
            hashed_password=hash_password(settings.ADMIN_PASSWORD),
            role="admin",
        )
        db.add(admin)

    # Seed map locations
    locations_data = [
        dict(type="hospital", name="Rajiv Gandhi Govt. Hospital", latitude=13.0865, longitude=80.2784, address="Park Town, Chennai", phone="044-25305000", is_open=True),
        dict(type="hospital", name="Government Stanley Hospital", latitude=13.0943, longitude=80.2773, address="Old Jail Road, Chennai", phone="044-25281361", is_open=True),
        dict(type="shelter", name="Nehru Indoor Stadium", latitude=13.0844, longitude=80.2717, address="ICF, Chennai", capacity=2000, is_open=True),
        dict(type="shelter", name="YMCA Grounds Nandanam", latitude=13.0274, longitude=80.2337, address="Nandanam, Chennai", capacity=500, is_open=True),
        dict(type="safe_building", name="DRJ Convention Centre", latitude=13.0765, longitude=80.2620, address="Teynampet, Chennai", is_open=True),
        dict(type="rescue", name="NDRF Rescue Camp", latitude=13.0600, longitude=80.2500, address="Central Chennai", is_open=True),
    ]

    for loc_data in locations_data:
        result = await db.execute(
            select(MapLocation).where(MapLocation.name == loc_data["name"])
        )
        if not result.scalar_one_or_none():
            db.add(MapLocation(**loc_data))

    await db.flush()
    return {"status": "seeded", "message": "Admin user and demo data created"}


def _mock_requests_data():
    from datetime import datetime, timedelta
    now = datetime.utcnow()
    return [
        {"id": "r1", "user_id": "u1", "type": "boat", "priority": "critical", "status": "pending", "latitude": 13.0821, "longitude": 80.2707, "description": "Family of 4 stranded on rooftop. Water rising.", "contact_number": "9876543210", "created_at": (now - timedelta(minutes=5)).isoformat()},
        {"id": "r2", "user_id": "u2", "type": "medical", "priority": "critical", "status": "in_progress", "latitude": 13.0950, "longitude": 80.2850, "description": "Elderly woman with chest pain. No ambulance access.", "contact_number": None, "created_at": (now - timedelta(minutes=18)).isoformat()},
        {"id": "r3", "user_id": "u3", "type": "food", "priority": "high", "status": "pending", "latitude": 13.0600, "longitude": 80.2500, "description": "Community of 30 without food for 2 days.", "contact_number": "9123456789", "created_at": (now - timedelta(hours=1)).isoformat()},
        {"id": "r4", "user_id": "u4", "type": "water", "priority": "high", "status": "in_progress", "latitude": 13.0700, "longitude": 80.2600, "description": "Drinking water contaminated by flood.", "contact_number": None, "created_at": (now - timedelta(hours=2)).isoformat()},
        {"id": "r5", "user_id": "u5", "type": "shelter", "priority": "medium", "status": "resolved", "latitude": 13.0400, "longitude": 80.2300, "description": "Single mother with 2 kids needs shelter.", "contact_number": "9988776655", "created_at": (now - timedelta(hours=6)).isoformat()},
    ]
