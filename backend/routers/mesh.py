# routers/mesh.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from core.database import get_db
from core.security import get_current_user
from models.db_models import User

router = APIRouter(prefix="/mesh", tags=["BLE Mesh Network"])


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class BridgedMessage(BaseModel):
    """A mesh message forwarded to the server by a bridge node."""
    id: str                         # Original UUID (for dedup on server too)
    sender_id: str
    sender_name: str
    type: str                       # 'sos' | 'text' | 'ping'
    priority: str                   # 'critical' | 'high' | 'normal'
    text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    target_id: Optional[str] = None
    created_at: str                 # ISO datetime string
    hop_count: int = 0
    battery_level: Optional[int] = None


class BridgedMessageResponse(BaseModel):
    id: str
    sender_id: str
    sender_name: str
    type: str
    priority: str
    text: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    target_id: Optional[str]
    created_at: datetime
    hop_count: int
    battery_level: Optional[int]
    received_at: datetime
    bridge_node_id: str


# ── In-memory store (swap with DB table in production) ────────────────────────
# For the MVP, we store bridged messages in memory + forward SOS to admin
_bridged_messages: list[dict] = []
_seen_ids: set[str] = set()   # Server-side deduplication


# ── Receive bridged messages from mesh ───────────────────────────────────────
@router.post("/bridge")
async def receive_bridged_message(
    payload: BridgedMessage,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Called by a bridge node (device with internet) to forward accumulated
    mesh messages to the server.

    The server:
    1. Deduplicates by message ID
    2. Stores the message
    3. For SOS messages, creates an emergency request
    4. Returns success/skip status
    """
    # Server-side deduplication
    if payload.id in _seen_ids:
        return {"status": "duplicate", "id": payload.id}

    _seen_ids.add(payload.id)

    # Parse datetime
    try:
        created = datetime.fromisoformat(payload.created_at)
    except ValueError:
        created = datetime.utcnow()

    record = {
        "id": payload.id,
        "sender_id": payload.sender_id,
        "sender_name": payload.sender_name,
        "type": payload.type,
        "priority": payload.priority,
        "text": payload.text,
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "target_id": payload.target_id,
        "created_at": created,
        "hop_count": payload.hop_count,
        "battery_level": payload.battery_level,
        "received_at": datetime.utcnow(),
        "bridge_node_id": current_user["id"],
    }
    _bridged_messages.append(record)

    # For SOS messages: auto-create an emergency request so rescuers see it
    if payload.type == "sos" and payload.latitude and payload.longitude:
        await _create_emergency_from_mesh(payload, current_user["id"], db)

    return {
        "status": "ok",
        "id": payload.id,
        "action": "emergency_created" if payload.type == "sos" else "stored",
    }


# ── Batch receive (more efficient for many messages) ──────────────────────────
@router.post("/bridge/batch")
async def receive_batch(
    messages: list[BridgedMessage],
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Forward a batch of mesh messages in one API call."""
    results = []
    for msg in messages:
        if msg.id in _seen_ids:
            results.append({"id": msg.id, "status": "duplicate"})
            continue

        _seen_ids.add(msg.id)
        try:
            created = datetime.fromisoformat(msg.created_at)
        except ValueError:
            created = datetime.utcnow()

        _bridged_messages.append({
            "id": msg.id,
            "sender_id": msg.sender_id,
            "sender_name": msg.sender_name,
            "type": msg.type,
            "priority": msg.priority,
            "text": msg.text,
            "latitude": msg.latitude,
            "longitude": msg.longitude,
            "target_id": msg.target_id,
            "created_at": created,
            "hop_count": msg.hop_count,
            "battery_level": msg.battery_level,
            "received_at": datetime.utcnow(),
            "bridge_node_id": current_user["id"],
        })

        if msg.type == "sos" and msg.latitude and msg.longitude:
            await _create_emergency_from_mesh(msg, current_user["id"], db)

        results.append({"id": msg.id, "status": "ok"})

    return {"results": results, "total": len(messages), "stored": sum(1 for r in results if r["status"] == "ok")}


# ── Admin: get all bridged messages ──────────────────────────────────────────
@router.get("/messages")
async def get_mesh_messages(
    type: Optional[str] = None,
    priority: Optional[str] = None,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
):
    """
    Retrieve mesh messages that have been bridged to the server.
    Filterable by type and priority.
    Useful for admin dashboard and rescuer view.
    """
    msgs = _bridged_messages.copy()

    if type:
        msgs = [m for m in msgs if m["type"] == type]
    if priority:
        msgs = [m for m in msgs if m["priority"] == priority]

    # Sort: critical first, then newest
    priority_order = {"critical": 0, "high": 1, "normal": 2}
    msgs.sort(key=lambda m: (priority_order.get(m["priority"], 3), -m["received_at"].timestamp()))

    return {
        "messages": msgs[:limit],
        "total": len(_bridged_messages),
        "sos_count": sum(1 for m in _bridged_messages if m["type"] == "sos"),
    }


# ── SOS messages only (for rescuer quick view) ───────────────────────────────
@router.get("/sos")
async def get_sos_messages(
    current_user: dict = Depends(get_current_user),
):
    """Return only SOS messages from the mesh — sorted by priority and time."""
    sos = [m for m in _bridged_messages if m["type"] == "sos"]
    sos.sort(key=lambda m: m["received_at"], reverse=True)
    return {"sos_messages": sos, "count": len(sos)}


# ── Network stats (for admin dashboard) ──────────────────────────────────────
@router.get("/stats")
async def get_mesh_stats(current_user: dict = Depends(get_current_user)):
    """Summary statistics for the mesh network activity."""
    total = len(_bridged_messages)
    sos_count = sum(1 for m in _bridged_messages if m["type"] == "sos")
    text_count = sum(1 for m in _bridged_messages if m["type"] == "text")
    avg_hops = (
        sum(m["hop_count"] for m in _bridged_messages) / total if total > 0 else 0
    )
    unique_senders = len(set(m["sender_id"] for m in _bridged_messages))

    return {
        "total_messages": total,
        "sos_count": sos_count,
        "text_count": text_count,
        "average_hops": round(avg_hops, 2),
        "unique_senders": unique_senders,
        "server_deduplicated": len(_seen_ids),
    }


# ── Helper: create emergency request from mesh SOS ────────────────────────────
async def _create_emergency_from_mesh(
    msg: BridgedMessage,
    bridge_user_id: str,
    db: AsyncSession,
):
    """
    When a SOS arrives via mesh bridge, auto-create an EmergencyRequest
    so it appears in the admin dashboard alongside regular requests.
    """
    from models.db_models import EmergencyRequest

    # Check if we already created a request for this mesh message
    result = await db.execute(
        select(EmergencyRequest).where(
            EmergencyRequest.description.contains(f"[MESH:{msg.id[:8]}]")
        )
    )
    if result.scalar_one_or_none():
        return  # Already exists

    # Find or use sender user ID
    sender_db_id = bridge_user_id  # Fallback to bridge node

    req = EmergencyRequest(
        user_id=sender_db_id,
        type="medical",          # SOS defaults to medical/rescue
        priority="critical",     # All mesh SOS are critical
        status="pending",
        latitude=msg.latitude,
        longitude=msg.longitude,
        description=(
            f"[MESH:{msg.id[:8]}] MESH SOS from {msg.sender_name} "
            f"(via {msg.hop_count} hops). "
            + (msg.text or "No description provided.")
            + (f" Battery: {msg.battery_level}%" if msg.battery_level else "")
        ),
        contact_number=None,
    )
    db.add(req)
    # Commit handled by session dependency
