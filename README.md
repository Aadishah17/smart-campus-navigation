# Smart Campus Navigation System

A comprehensive campus navigation solution featuring a web-based management system, a Node.js backend, and a cross-platform Flutter mobile application.

## 🚀 Key Features

- **Interactive Campus Map**: Digital overlay on Parul University guide imagery.
- **Real-time Navigation**: GPS-based live user positioning and tracking.
- **Shortest-Path Logic**: Optimized routing using Dijkstra's algorithm.
- **AI Assistant**: Context-aware chat for location information and campus guidance.
- **Multi-Platform**: Seamless experience across Web and Mobile (Android/iOS).

## 📂 Project Structure

- `frontend/`: React + Vite web application for map visualization and management.
- `backend/`: Node.js + Express API providing data and routing services.
- `smart_campus_flutter/`: Flutter mobile application for on-the-go navigation.
- `docs/`: Project documentation and assets.

---

## 🛠️ Components Setup

### 1. Backend (Node.js)

```bash
cd backend
npm install
npm run dev
```

*Configurable via `.env` (see `.env.example`).*

### 2. Frontend (React)

```bash
cd frontend
npm install
npm run dev
```

*Access at `http://localhost:5173`.*

### 3. Mobile App (Flutter)

```bash
cd smart_campus_flutter
flutter pub get
flutter run
```

*Requires Flutter SDK and an Android/iOS emulator or device.*

---

## 📡 API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/locations` | GET | List all campus landmarks |
| `/api/navigation/route` | POST | Calculate shortest path between points |
| `/api/assistant/chat` | POST | Interact with the AI campus guide |

---

## 🖼️ Screenshots

Visual previews of the application can be found in the [docs/images](docs/images) directory.

![Mobile App Preview](docs/images/device_screen_after_fix.png)
