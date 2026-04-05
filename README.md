# 🚨 Crisis Response App

A production-grade **Flutter + FastAPI** emergency coordination platform for disaster response, built for hackathon demo and real-world scalability.

---

## 📁 Project Structure

```
crisis_app/
├── flutter_app/                    # Flutter mobile app (Android-first)
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── core/
│   │   │   ├── constants/          # App constants, route names, storage keys
│   │   │   ├── network/            # Dio API client, network checker
│   │   │   ├── router/             # GoRouter navigation setup
│   │   │   └── theme/              # AppTheme, AppColors, AppTextStyles
│   │   ├── features/
│   │   │   ├── auth/               # Login (Google OAuth), Admin login
│   │   │   ├── home/               # Dashboard, Request Help screen
│   │   │   ├── emergency/          # Emergency types grid, detail screens
│   │   │   ├── map/                # Google Maps with markers
│   │   │   ├── notifications/      # Alerts feed with polling
│   │   │   ├── statistics/         # Weather, seismic, ocean stats
│   │   │   ├── ai_assistant/       # Chat UI, STT, TTS, local RAG
│   │   │   └── admin/              # Admin dashboard (3 tabs)
│   │   └── shared/
│   │       ├── models/             # Dart data models (User, Request, etc.)
│   │       └── widgets/            # Shared UI components
│   └── pubspec.yaml
│
└── backend/                        # Python FastAPI backend
    ├── main.py                     # App entry point, router mounting
    ├── core/
    │   ├── config.py               # Settings (pydantic-settings, .env)
    │   ├── database.py             # Async SQLAlchemy + SQLite/PostgreSQL
    │   └── security.py             # JWT, password hashing, auth dependencies
    ├── models/
    │   ├── db_models.py            # SQLAlchemy ORM models
    │   └── schemas.py              # Pydantic request/response schemas
    ├── routers/
    │   ├── auth.py                 # Google OAuth + Admin login
    │   ├── emergency.py            # Emergency requests + priority logic
    │   ├── notifications.py        # Alerts feed + FCM broadcast
    │   ├── location.py             # Nearby hospitals, shelters, rescue
    │   ├── stats.py                # Weather (Open-Meteo), seismic, ocean
    │   ├── ai_query.py             # Local RAG AI assistant
    │   └── admin.py                # Dashboard, user mgmt, seeding
    ├── requirements.txt
    └── .env.example
```

---

## 🚀 Quick Start

### 1. Backend Setup (Python + FastAPI)

```bash
cd crisis_app/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate       # Linux/macOS
# or: venv\Scripts\activate    # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your values (SECRET_KEY, Google Client ID, etc.)

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Seed admin user + demo data (run once after first start)
curl -X POST http://localhost:8000/api/v1/admin/seed
```

Backend will be available at:
- **API**: http://localhost:8000/api/v1
- **Swagger Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

### 2. Flutter App Setup

```bash
cd crisis_app/flutter_app

# Install Flutter dependencies
flutter pub get

# Configure Google Maps API key
# In android/app/src/main/AndroidManifest.xml:
# Replace YOUR_GOOGLE_MAPS_API_KEY with your actual key

# Configure Google Sign-In
# In android/app/src/main/google-services.json:
# Add your Firebase project config

# Run on Android device/emulator
flutter run

# Build APK
flutter build apk --release
```

---

## ⚙️ Configuration

### Backend `.env`

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing secret | (required) |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | (required for prod) |
| `DATABASE_URL` | SQLAlchemy async URL | `sqlite+aiosqlite:///./crisis_response.db` |
| `FIREBASE_CREDENTIALS_PATH` | Path to serviceAccountKey.json | `serviceAccountKey.json` |
| `ADMIN_EMAIL` | Admin login email | `admin@crisisresponse.gov` |
| `ADMIN_PASSWORD` | Admin login password | `SecureAdmin2024!` |

### Flutter `AppConstants`

Edit `lib/core/constants/app_constants.dart`:

| Constant | Description |
|----------|-------------|
| `baseUrl` | Backend URL (`10.0.2.2:8000` for Android emulator) |
| `defaultLat/Lng` | Default map center (currently Chennai) |
| `sessionDurationHours` | JWT session length (48h) |

### Android Manifest changes

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Google Maps -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>

<!-- Permissions -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

---

## 🏗️ Architecture

```
Flutter App                    FastAPI Backend
──────────────                 ───────────────
Login Screen ─────────────────→ POST /auth/google
                               POST /auth/admin/login
                               ← JWT Token

Home Screen ──────────────────→ GET  /notifications (polling 30s)
                               GET  /stats/location
                               ← Data + cache

Request Help ─────────────────→ POST /emergency/request
                               ← Priority assigned + saved

Map Screen ───────────────────→ GET  /location/nearby
                               ← Hospitals, shelters, rescue

AI Assistant ─────────────────→ POST /ai/query
                               ← RAG answer (local KB)

Admin Dashboard ──────────────→ GET  /admin/dashboard
                               GET  /admin/requests
                               POST /admin/notifications
                               ← Stats + FCM broadcast
```

---

## 🔑 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/google` | Google OAuth login |
| POST | `/api/v1/auth/admin/login` | Admin email/password login |
| GET | `/api/v1/auth/me` | Current user profile |
| POST | `/api/v1/auth/fcm-token` | Register FCM token |
| POST | `/api/v1/auth/logout` | Logout |

### Emergency Requests
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/emergency/request` | Submit emergency request |
| GET | `/api/v1/emergency/my-requests` | User's own requests |
| GET | `/api/v1/emergency/request/{id}` | Get single request |
| PATCH | `/api/v1/emergency/request/{id}/status` | Update status (admin) |
| GET | `/api/v1/emergency/nearby?lat=&lng=` | Nearby active requests |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notifications` | Fetch alerts feed |
| POST | `/api/v1/notifications` | Publish alert + FCM broadcast (admin) |
| DELETE | `/api/v1/notifications/{id}` | Deactivate alert (admin) |

### Location Services
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/location/nearby?lat=&lng=&type=` | Nearby facilities |
| GET | `/api/v1/location/all` | All map markers |

### Statistics
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/stats/location?lat=&lng=` | Weather, seismic, ocean stats |

### AI Assistant
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/ai/query` | Natural language crisis query |

### Admin
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/admin/dashboard` | Dashboard statistics |
| GET | `/api/v1/admin/requests` | All requests (filterable) |
| GET | `/api/v1/admin/users` | All users |
| POST | `/api/v1/admin/seed` | Seed demo data |

---

## 👥 User Roles

| Role | Access | Implementation |
|------|--------|----------------|
| **User** | Full app, request help, AI assistant | ✅ Complete |
| **Admin** | Dashboard, publish alerts, manage requests | ✅ Complete |
| **Hospital** | — | 🔲 Placeholder |
| **Rescuer** | Update request status | 🔲 Placeholder |
| **Hospitality** | — | 🔲 Placeholder |

---

## 📱 App Screens

| Screen | Description |
|--------|-------------|
| **Login** | Google OAuth with session caching (48h) |
| **Admin Login** | Secure email/password |
| **Home** | SOS button, quick actions, helplines, notifications preview |
| **Emergency Situations** | 12 disaster types with guidelines + actions |
| **Map** | Hospitals, shelters, safe buildings with navigation |
| **Notifications** | Real-time alerts feed (polls every 30s) |
| **Statistics** | Weather, seismic, ocean data + risk assessment |
| **AI Assistant** | Voice + text chat with crisis RAG |
| **Request Help** | 8 resource types, GPS auto-attach |
| **Admin Dashboard** | Overview, requests management, publish alerts |

---

## 🛡️ Security

- JWT tokens with 48h expiry
- bcrypt password hashing for admin accounts
- Bearer token authentication on all protected routes
- Role-based access control (RBAC)
- Input validation via Pydantic schemas
- SQL injection prevention via SQLAlchemy ORM

---

## 📡 Offline Handling

- Hive local cache for critical data
- Network connectivity banner (NetworkChecker stream)
- Mock/fallback data returned when API unavailable
- Timestamp freshness indicators on Statistics screen
- Pull-to-refresh on all screens

---

## 🔔 Push Notifications

Firebase Cloud Messaging (FCM) is integrated:
1. Flutter registers device token on login → `POST /auth/fcm-token`
2. Admin publishes alert → `POST /notifications`
3. Backend fetches all FCM tokens → sends multicast via Firebase Admin SDK
4. Users receive push even when app is closed

**Setup**: Download `serviceAccountKey.json` from Firebase Console → Project Settings → Service Accounts → Generate new private key. Place it in `backend/`.

---

## 🌐 External APIs Used

| Service | Purpose | Cost |
|---------|---------|------|
| Google Sign-In | OAuth authentication | Free |
| Google Maps Flutter | Interactive map | Free tier |
| Open-Meteo | Real weather data | Free, no key needed |
| Firebase FCM | Push notifications | Free tier |
| USGS (future) | Seismic data | Free |

---

## 🏆 Hackathon Demo Flow

1. **Start backend**: `uvicorn main:app --reload`
2. **Seed data**: `curl -X POST http://localhost:8000/api/v1/admin/seed`
3. **Run Flutter app**: `flutter run`
4. **User flow**: Login with Google → View emergency types → Submit request → Chat with AI
5. **Admin flow**: Admin login → Dashboard stats → Manage requests → Publish alert

---

## 🔮 Production Roadmap

- [ ] PostgreSQL (replace SQLite)
- [ ] Redis for caching + rate limiting
- [ ] WebSocket real-time updates (replace polling)
- [ ] USGS API for live seismic data
- [ ] LLM integration (Claude/GPT-4) for AI assistant
- [ ] Role-specific dashboards (hospital, rescuer, hospitality)
- [ ] SMS alerts via Twilio for users without internet
- [ ] Deployment: Docker + Kubernetes / Railway / Render

---

*Built with Flutter 3.x + FastAPI 0.111 + SQLAlchemy 2.0*
