# 📡 BLE Mesh Network Feature — Setup Guide

## Overview

The BLE Mesh feature enables **device-to-device communication with zero internet** using Google's Nearby Connections API. When cellular/WiFi is down, the app switches to BLE + WiFi Direct to relay SOS alerts and messages between phones.

```
[User A — No Signal]
       │  BLE / WiFi Direct (~100m)
       ▼
[User B — No Signal]  ← relays message forward
       │  BLE / WiFi Direct
       ▼
[User C — Has 4G]  ← "Bridge Node"
       │  Internet
       ▼
[Backend + Admin Dashboard]
```

---

## Files Added

### Flutter
```
lib/features/mesh/
├── screens/
│   └── mesh_screen.dart          ← 6th tab in app (Radar / Messages / Send)
├── services/
│   ├── mesh_service.dart         ← Nearby Connections core (advertise + discover)
│   ├── mesh_message_store.dart   ← Hive local store with TTL & dedup
│   └── mesh_bridge_service.dart  ← Auto + manual server sync
└── widgets/
    ├── mesh_status_banner.dart   ← Persistent banner on all screens
    └── mesh_node_radar.dart      ← Animated radar of nearby peers

lib/shared/models/
└── mesh_message_model.dart       ← MeshMessage + MeshNode data classes
```

### Backend
```
backend/routers/mesh.py           ← /mesh/bridge, /mesh/messages, /mesh/stats
```

---

## Android Setup (Required)

### 1. Add permissions to `AndroidManifest.xml`

See `android_manifest_template.xml` — copy all the BLE/Nearby permissions into your actual manifest.

Key permissions needed:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
```

### 2. Minimum SDK version

In `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 21    // Required for Nearby Connections
        targetSdkVersion 34
    }
}
```

### 3. Kotlin version (for nearby_connections plugin)

In `android/build.gradle`:
```gradle
buildscript {
    ext.kotlin_version = '1.9.0'
}
```

---

## How It Works (Technical)

### Advertising + Discovery
Every device runs **both simultaneously**:
- **Advertising**: Makes itself discoverable to other mesh nodes
- **Discovery**: Actively scans for other mesh nodes

When a peer is found, the app **auto-connects** using `P2P_CLUSTER` strategy — which forms a many-to-many mesh.

### Message Protocol
Each message is a compact JSON payload (~300 bytes):
```json
{
  "id": "uuid",          // Unique ID for deduplication
  "sid": "user-id",      // Sender ID
  "sn": "Name",          // Sender name
  "t": 0,                // Type: 0=SOS, 1=text, 2=ping
  "p": 0,                // Priority: 0=critical, 1=high, 2=normal
  "tx": "Help needed",   // Text content
  "lat": 13.0827,        // GPS latitude
  "lng": 80.2707,        // GPS longitude
  "ca": 1720000000000,   // Created at (epoch ms)
  "h": 2,                // Current hop count
  "mh": 5,               // Max hops (TTL)
  "bat": 45              // Battery level %
}
```

### Relay Logic
When a message arrives at a node:
1. Check if already seen (dedup by `id`) → drop if duplicate
2. Check hop count vs maxHops → drop if expired
3. Store locally in Hive
4. Re-broadcast to ALL other connected peers with `hopCount + 1`
5. If this node has internet → trigger bridge sync

### Bridge Sync
**Auto**: Triggered by:
- Connectivity stream detecting internet restored
- A connected peer's beacon reporting `hasInternet: true`

**Manual**: User taps "Forward Now" in Mesh screen header

The bridge uploads all `getPendingBridge()` messages in priority order to `POST /api/v1/mesh/bridge`.

### Beacon
Every 60 seconds, each node broadcasts a beacon to all connected peers:
```json
{
  "type": "beacon",
  "uid": "user-id",
  "name": "User Name",
  "lat": 13.0827,
  "lng": 80.2707,
  "inet": 1,           // 1 = has internet (bridge candidate)
  "bat": 82
}
```

This keeps node metadata fresh and lets the bridge logic know which peers can forward.

---

## UI Components

### Mesh Screen (6th tab)

**Radar Tab**
- Animated rotating radar sweep
- Nearby nodes shown as dots (green = peer, teal = bridge node with internet)
- Node list below with signal strength, estimated distance, battery

**Messages Tab**
- All received mesh messages
- SOS messages highlighted in red
- Shows: sender name, content, GPS, hop count, battery, forwarded status

**Send SOS Tab**
- Big red SOS button → broadcasts with GPS over BLE
- Text message field → broadcast to all peers
- "How It Works" explainer diagram

### Mesh Status Banner
Sits below the AppBar on all screens:

| State | Display |
|-------|---------|
| `online` | 🟢 Online · Internet connected |
| `meshOnly` | 🟡 Mesh Only · N peers connected |
| `isolated` | 🔴 Isolated · Searching for peers... |
| `starting` | ⚫ Starting Mesh... |

Tapping the banner jumps to the Mesh tab.

---

## Backend Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/mesh/bridge` | User | Forward single mesh message |
| POST | `/api/v1/mesh/bridge/batch` | User | Forward batch of messages |
| GET | `/api/v1/mesh/messages` | User | All bridged messages |
| GET | `/api/v1/mesh/sos` | User | Only SOS messages |
| GET | `/api/v1/mesh/stats` | User | Network activity stats |

### Auto Emergency Creation
When an SOS arrives via mesh bridge, the server **automatically creates an EmergencyRequest** in the database. This means:
- It appears in the admin dashboard alongside regular requests
- Marked with `[MESH:xxxxxx]` prefix so admins know it came via mesh
- Priority set to `critical` always
- Contains GPS, sender name, hop count, battery level

---

## Reality Check — Known Limitations

| Issue | Impact | Mitigation |
|-------|--------|------------|
| App closed = mesh stops | Messages lost if app killed | Foreground service (future) |
| Range ~30–100m per hop | Works in dense crowds/disaster zones | Hop relay extends range |
| Battery drain | Higher BLE usage | Beacon interval = 60s (balanced) |
| iOS not supported | Nearby Connections = Android only | iOS uses MultipeerConnectivity (future) |
| Max ~5 hops = ~500m range | Not citywide | Bridge nodes extend via internet |

---

## Demo Flow (Hackathon)

1. Install app on 3 Android phones
2. Turn off WiFi + mobile data on 2 of them
3. On phone 1 (offline): open Mesh tab → tap **BROADCAST SOS OVER MESH**
4. On phone 2 (offline relay): see message arrive in Messages tab
5. On phone 3 (has internet): message auto-bridges to server
6. On admin dashboard: SOS appears as a new Emergency Request

This demonstrates the full offline → mesh → bridge → server pipeline live.
