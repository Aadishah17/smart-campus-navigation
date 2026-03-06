# Smart Campus Flutter (Android)

Flutter version of your Smart Campus Navigation System with:

- Live integrated OpenStreetMap experience (no static campus-image interaction)
- GPS current location
- Shortest path route planning (via backend API)
- Nearby place suggestions
- AI assistant chat
- Favorite locations and recent destinations (saved on-device)
- Pace-aware route ETA with copyable route summary
- Black-and-white dark theme
- AMOLED contrast tuning (pure-black surfaces + high-contrast controls)

## Project Path

`d:\New folder\smart_campus_flutter`

## Backend Requirement

Run your backend first (from `d:\New folder\backend`), for example on port `5050`.

## API URL in App

Default Android emulator API base URL:

`http://10.0.2.2:5050/api`

You can change this inside the app using the settings icon in the top bar.

## Run on Android

1. Install Android SDK and set `ANDROID_HOME`
2. Connect emulator or physical Android device
3. Run:

```bash
cd smart_campus_flutter
flutter pub get
flutter run
```

## Verify

- `flutter analyze` passed
- `flutter test` passed

## Map Interactions

- Fully live map mode only (street/dark tiles)
- Georeferenced Parul campus guide map overlay on top of the live map
- Pinch/zoom and pan map
- Zoom controls (+ / -), recenter, and follow-user toggle
- Drawn campus graph network (can be toggled on/off)
- Tap map markers to select destination
- Tap near a building to select nearest location
- Follow-user map mode for moving live position
