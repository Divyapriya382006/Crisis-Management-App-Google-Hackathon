# core/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # JWT
    SECRET_KEY: str = "dev-secret-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_HOURS: int = 48

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./crisis_response.db"

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "serviceAccountKey.json"

    # Admin
    ADMIN_EMAIL: str = "admin@crisisresponse.gov"
    ADMIN_PASSWORD: str = "admin123"

    # App
    APP_NAME: str = "Crisis Response API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
