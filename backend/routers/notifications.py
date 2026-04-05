# routers/notifications.py
import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from core.database import get_db
from core.security import get_current_user, require_admin
from models.db_models import Notification, User
from models.schemas import NotificationCreate, NotificationResponse

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _to_response(n: Notification) -> NotificationResponse:
    return NotificationResponse(
        id=n.id,
        title=n.title,
        body=n.body,
        type=n.type,
        source=n.source,
        timestamp=n.created_at,
        action_url=n.action_url,
    )


# ── Get notifications feed (for users) ───────────────────────────────────────
@router.get("")
async def get_notifications(
    limit: int = 30,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch recent active notifications sorted by recency."""
    result = await db.execute(
        select(Notification)
        .where(Notification.is_active == True)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    notifications = [_to_response(n) for n in result.scalars().all()]

    # Fallback: if no DB entries yet, return seeded mock
    if not notifications:
        notifications = _mock_notifications()

    return {"notifications": notifications}


# ── Publish notification (admin only) ─────────────────────────────────────────
@router.post("", response_model=NotificationResponse)
async def publish_notification(
    payload: NotificationCreate,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Publish a new alert.
    Saves to DB and sends via Firebase Cloud Messaging to all registered devices.
    """
    n = Notification(
        title=payload.title,
        body=payload.body,
        type=payload.type,
        source=payload.source,
        action_url=payload.action_url,
    )
    db.add(n)
    await db.flush()

    # Send via FCM to all users with tokens
    fcm_result = await _send_fcm_broadcast(payload, db)
    n.sent_via_fcm = fcm_result

    return _to_response(n)


# ── Delete notification (admin) ───────────────────────────────────────────────
@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: str,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Notification).where(Notification.id == notification_id))
    n = result.scalar_one_or_none()
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_active = False
    return {"status": "deleted"}


# ── FCM broadcast helper ──────────────────────────────────────────────────────
async def _send_fcm_broadcast(payload: NotificationCreate, db: AsyncSession) -> bool:
    """Send FCM push notification to all users with registered tokens."""
    try:
        import firebase_admin
        from firebase_admin import messaging, credentials

        # Initialize Firebase only once
        if not firebase_admin._apps:
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
            if os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
            else:
                return False  # Firebase not configured

        # Fetch all FCM tokens
        result = await db.execute(
            select(User.fcm_token).where(User.fcm_token != None, User.is_active == True)
        )
        tokens = [row[0] for row in result.fetchall() if row[0]]

        if not tokens:
            return False

        # Send multicast
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=payload.title, body=payload.body),
            data={"type": payload.type, "source": payload.source},
            tokens=tokens,
        )
        response = messaging.send_each_for_multicast(message)
        return response.success_count > 0

    except Exception as e:
        print(f"FCM error: {e}")
        return False


# ── Mock fallback data ─────────────────────────────────────────────────────────
def _mock_notifications() -> list[NotificationResponse]:
    from datetime import timedelta
    now = datetime.utcnow()
    return [
        NotificationResponse(id="m1", title="Cyclone Alert: Bay of Bengal", body="IMD warns of cyclonic storm forming in Bay of Bengal. Coastal areas on high alert.", type="critical", source="IMD / Govt. of India", timestamp=now - timedelta(minutes=12)),
        NotificationResponse(id="m2", title="Heavy Rainfall Warning — Red Alert", body="Red alert issued for Chennai. 150mm+ rainfall expected in 24 hours. Avoid low-lying areas.", type="warning", source="Chennai Corporation", timestamp=now - timedelta(hours=1)),
        NotificationResponse(id="m3", title="NDRF Teams Deployed", body="4 NDRF teams deployed across North Chennai in anticipation of flooding.", type="info", source="NDRF HQ", timestamp=now - timedelta(hours=2)),
        NotificationResponse(id="m4", title="Power Outage — North Chennai", body="Planned shutdown in Perambur, Kolathur zones from 9AM–4PM for maintenance.", type="warning", source="TANGEDCO", timestamp=now - timedelta(hours=5)),
    ]
