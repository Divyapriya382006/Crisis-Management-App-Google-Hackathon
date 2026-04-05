# models/db_models.py
import uuid
from datetime import datetime
from sqlalchemy import (
    String, DateTime, Float, Boolean, Text,
    ForeignKey, Enum as SQLEnum
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from core.database import Base


def gen_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(200))
    email: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    hashed_password: Mapped[str | None] = mapped_column(String(200), nullable=True)
    google_id: Mapped[str | None] = mapped_column(String(200), nullable=True, unique=True)
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    role: Mapped[str] = mapped_column(
        SQLEnum("user", "admin", "hospital", "rescuer", "hospitality", name="user_role"),
        default="user",
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    fcm_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    requests: Mapped[list["EmergencyRequest"]] = relationship(back_populates="user")


class EmergencyRequest(Base):
    __tablename__ = "emergency_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    type: Mapped[str] = mapped_column(
        SQLEnum("food", "water", "electricity", "medical", "boat", "helicopter", "shelter", "evacuation", name="request_type")
    )
    priority: Mapped[str] = mapped_column(
        SQLEnum("critical", "high", "medium", "low", name="priority_level"),
        default="medium",
    )
    status: Mapped[str] = mapped_column(
        SQLEnum("pending", "accepted", "in_progress", "resolved", "cancelled", name="request_status"),
        default="pending",
    )
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    contact_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    assigned_to: Mapped[str | None] = mapped_column(String(36), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationship
    user: Mapped["User"] = relationship(back_populates="requests")


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    title: Mapped[str] = mapped_column(String(300))
    body: Mapped[str] = mapped_column(Text)
    type: Mapped[str] = mapped_column(
        SQLEnum("critical", "warning", "info", "alert", name="notification_type"),
        default="info",
    )
    source: Mapped[str] = mapped_column(String(200), default="Crisis Response Admin")
    action_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    sent_via_fcm: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MapLocation(Base):
    __tablename__ = "map_locations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=gen_uuid)
    type: Mapped[str] = mapped_column(
        SQLEnum("hospital", "shelter", "safe_building", "rescue", "relief_camp", name="location_type")
    )
    name: Mapped[str] = mapped_column(String(300))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    capacity: Mapped[int | None] = mapped_column(nullable=True)
    is_open: Mapped[bool] = mapped_column(Boolean, default=True)
    city: Mapped[str] = mapped_column(String(100), default="Chennai")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
