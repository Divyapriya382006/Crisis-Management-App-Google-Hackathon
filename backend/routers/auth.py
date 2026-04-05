# routers/auth.py
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from core.database import get_db
from core.security import (
    create_access_token, verify_password, hash_password, get_current_user
)
from core.config import settings
from models.db_models import User
from models.schemas import (
    GoogleAuthRequest, AdminLoginRequest, TokenResponse, UserResponse, FCMTokenUpdate
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Google OAuth login ────────────────────────────────────────────────────────
@router.post("/google", response_model=TokenResponse)
async def google_login(payload: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    """
    Authenticate with Google OAuth.
    1. Verify the id_token with Google (or trust email for demo mode).
    2. Create or update the user record.
    3. Return JWT access token.
    """
    # Optional: verify with Google's tokeninfo endpoint
    if payload.id_token:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"https://oauth2.googleapis.com/tokeninfo?id_token={payload.id_token}",
                    timeout=5.0,
                )
                if resp.status_code != 200:
                    raise HTTPException(status_code=401, detail="Invalid Google token")
        except httpx.TimeoutException:
            pass  # Accept in demo/offline mode

    # Find or create user
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    if not user:
        user = User(
            name=payload.name,
            email=payload.email,
            photo_url=payload.photo_url,
            role="user",
        )
        db.add(user)
        await db.flush()

    else:
        # Update photo if changed
        if payload.photo_url:
            user.photo_url = payload.photo_url

    # Issue JWT
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})

    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


# ── Admin login ───────────────────────────────────────────────────────────────
@router.post("/admin/login", response_model=TokenResponse)
async def admin_login(payload: AdminLoginRequest, db: AsyncSession = Depends(get_db)):
    """Authenticate as admin using email + password."""
    result = await db.execute(select(User).where(User.email == payload.email, User.role == "admin"))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not user.hashed_password or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user.id, "email": user.email, "role": "admin"})

    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


# ── Get current user profile ──────────────────────────────────────────────────
@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == current_user["id"]))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse.model_validate(user)


# ── Update FCM token ──────────────────────────────────────────────────────────
@router.post("/fcm-token")
async def update_fcm_token(
    payload: FCMTokenUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Register device FCM token for push notifications."""
    result = await db.execute(select(User).where(User.id == current_user["id"]))
    user = result.scalar_one_or_none()
    if user:
        user.fcm_token = payload.fcm_token
    return {"status": "ok"}


# ── Logout (client-side token deletion) ──────────────────────────────────────
@router.post("/logout")
async def logout(current_user: dict = Depends(get_current_user)):
    """Logout endpoint — client must delete the token."""
    return {"status": "logged_out", "message": "Delete your local token to complete logout."}
