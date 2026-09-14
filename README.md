# Crick — CricHeroes-Style Cricket Platform

Production-grade Flutter cricket app for iOS & Android with Firebase backend.

## Features

- **Auth** — Email, Google Sign-In, phone OTP ready
- **Player profiles** — Career stats, edit profile, match history
- **Teams** — Create teams, invite players, squad management
- **Live scoring** — Ball-by-ball scoring with offline sync to Firebase RTDB
- **Tournaments** — Round-robin/knockout fixtures, points table, NRR
- **Discover** — Search players/teams/tournaments, follow, "looking for" posts
- **Feed** — Cricket content with AdMob banners
- **CricInsights** — Analytics charts, badges, leaderboards
- **PRO Club** — RevenueCat subscriptions
- **Store** — Product catalog & orders (Razorpay-ready)
- **Live streaming** — Agora integration scaffold
- **Admin panel** — Flutter web for feed, products, tournaments, associations

## Project Structure

```
Crick/
├── apps/
│   ├── mobile/          # Main Flutter app (iOS + Android)
│   └── admin/           # Admin web panel
├── packages/
│   └── scoring_engine/  # Pure Dart cricket rules engine
├── functions/           # Firebase Cloud Functions (TypeScript)
├── firestore.rules
├── database.rules.json
├── storage.rules
└── .github/workflows/ci.yml
```

## Prerequisites

- Flutter 3.x (`flutter doctor`)
- Node.js 20+ (for Cloud Functions)
- Firebase CLI (`npm i -g firebase-tools`)
- Firebase project (dev/staging/prod)

## Setup

### 1. Firebase

```bash
firebase login
firebase use --add   # link dev, staging, prod projects
```

Configure Flutter Firebase:

```bash
cd apps/mobile
dart pub global activate flutterfire_cli
flutterfire configure
```

Update `apps/mobile/lib/core/firebase/firebase_options.dart` with your project credentials.

### 2. Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

### 3. Cloud Functions

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 4. Admin Panel

```bash
cd apps/admin
flutter pub get
flutter run -d chrome
# Build for hosting:
flutter build web
firebase deploy --only hosting
```

### 5. Emulators (local dev)

```bash
firebase emulators:start
```

## Scoring Engine

Pure Dart package with unit tests:

```bash
cd packages/scoring_engine
dart test
```

## CI/CD

GitHub Actions runs on push to `main`/`develop`:
- Scoring engine tests & analyze
- Flutter mobile analyze, test, debug APK build
- Cloud Functions build & test

## Configuration

| Service | File | Key |
|---------|------|-----|
| Firebase | `firebase_options.dart` | Run `flutterfire configure` |
| RevenueCat | `subscription_repository.dart` | `YOUR_REVENUECAT_API_KEY` |
| Agora | `app_constants.dart` | `agoraAppIdPlaceholder` |
| Razorpay | `app_constants.dart` | `razorpayKeyPlaceholder` |
| AdMob | `feed_screen.dart` | Replace test ad unit in production |

## License

Private — all rights reserved.
