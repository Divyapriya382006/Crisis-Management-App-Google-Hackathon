# main.py — FastAPI application entry point
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from core.database import create_tables
from routers import auth, emergency, notifications, location, stats, ai_query, admin, mesh


# ── Lifespan: startup + shutdown tasks ────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print(f"🚀 Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    await create_tables()
    print("✅ Database tables ready")
    yield
    # Shutdown
    print("🛑 Shutting down")


# ── App instantiation ─────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
## Crisis Response API

Production-grade backend for the Crisis Response mobile application.

### Features
- 🔐 JWT authentication (Google OAuth + Admin)
- 🆘 Emergency request management with auto-priority
- 📢 Push notifications via Firebase Cloud Messaging
- 🗺️ Location-based services (hospitals, shelters, rescue)
- 📊 Real-time weather & seismic statistics
- 🤖 AI assistant with local knowledge base (RAG)
- 👨‍💼 Admin dashboard & monitoring

### First-time setup
After starting the server, seed the database:
```
POST /api/v1/admin/seed
```
This creates the admin user and demo location data.
    """,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ── CORS middleware ───────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict to your domains in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Global exception handler ──────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "error": str(exc) if settings.DEBUG else "Contact support"},
    )


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
    }

@app.get("/", tags=["System"])
async def root():
    return {
        "message": f"Welcome to {settings.APP_NAME}",
        "docs": "/docs",
        "health": "/health",
    }


# ── Mount routers under /api/v1 ───────────────────────────────────────────────
API_PREFIX = "/api/v1"

app.include_router(auth.router,          prefix=API_PREFIX)
app.include_router(emergency.router,     prefix=API_PREFIX)
app.include_router(notifications.router, prefix=API_PREFIX)
app.include_router(location.router,      prefix=API_PREFIX)
app.include_router(stats.router,         prefix=API_PREFIX)
app.include_router(ai_query.router,      prefix=API_PREFIX)
app.include_router(admin.router,         prefix=API_PREFIX)
app.include_router(mesh.router,          prefix=API_PREFIX)


# ── Run directly ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info",
    )
