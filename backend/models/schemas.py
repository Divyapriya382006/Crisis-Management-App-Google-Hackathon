# models/schemas.py
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Literal
from datetime import datetime


# ──── Auth ────────────────────────────────────────────────────────────────────

class GoogleAuthRequest(BaseModel):
    id_token: Optional[str] = None
    email: str
    name: str
    photo_url: Optional[str] = None


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserResponse"


class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    role: str
    photo_url: Optional[str] = None
    phone: Optional[str] = None

    class Config:
        from_attributes = True


# ──── Emergency Requests ──────────────────────────────────────────────────────

class EmergencyRequestCreate(BaseModel):
    type: Literal["food", "water", "electricity", "medical", "boat", "helicopter", "shelter", "evacuation"]
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    description: Optional[str] = Field(None, max_length=1000)
    contact_number: Optional[str] = Field(None, max_length=20)


class EmergencyRequestResponse(BaseModel):
    id: str
    user_id: str
    type: str
    priority: str
    status: str
    latitude: float
    longitude: float
    description: Optional[str]
    contact_number: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class UpdateRequestStatus(BaseModel):
    status: Literal["pending", "accepted", "in_progress", "resolved", "cancelled"]
    assigned_to: Optional[str] = None


# ──── Notifications ───────────────────────────────────────────────────────────

class NotificationCreate(BaseModel):
    title: str = Field(..., max_length=300)
    body: str = Field(..., max_length=2000)
    type: Literal["critical", "warning", "info", "alert"] = "warning"
    source: str = "Crisis Response Admin"
    action_url: Optional[str] = None


class NotificationResponse(BaseModel):
    id: str
    title: str
    body: str
    type: str
    source: str
    timestamp: datetime
    is_read: bool = False
    action_url: Optional[str] = None

    class Config:
        from_attributes = True


# ──── Map / Location ──────────────────────────────────────────────────────────

class MapLocationResponse(BaseModel):
    id: str
    type: str
    name: str
    latitude: float
    longitude: float
    address: Optional[str]
    phone: Optional[str]
    capacity: Optional[int]
    is_open: bool

    class Config:
        from_attributes = True


# ──── Stats ───────────────────────────────────────────────────────────────────

class WeatherData(BaseModel):
    temperature: float
    humidity: float
    condition: str
    wind_speed: float
    wind_direction: str
    updated_at: str


class SeismicData(BaseModel):
    magnitude: float
    level: str
    region: str
    last_activity: Optional[str] = None


class StatsResponse(BaseModel):
    weather: WeatherData
    seismic: SeismicData
    location: str
    ocean: dict


# ──── AI Query ────────────────────────────────────────────────────────────────

class AIQueryRequest(BaseModel):
    query: str = Field(..., max_length=500)
    context: str = "crisis_response"
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class AIQueryResponse(BaseModel):
    query: str
    answer: str
    sources: list[str] = []
    confidence: float = 1.0


# ──── Admin Dashboard ─────────────────────────────────────────────────────────

class DashboardStats(BaseModel):
    total_requests: int
    pending: int
    in_progress: int
    resolved: int
    critical: int


class FCMTokenUpdate(BaseModel):
    fcm_token: str


# Forward reference resolution
TokenResponse.model_rebuild()
