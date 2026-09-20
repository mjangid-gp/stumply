# Stumply Feed V2 — Free Cricket Feed

## What changed

- Removed the hard-coded ESPN league IDs.
- Discovers active cricket series dynamically from ESPN's public scoreboard header.
- Fetches live and upcoming matches instead of filtering to live only.
- Adds International / India / Domestic / League filters.
- Adds a cricket news section using public ESPN cricket news endpoints.
- Refreshes match data every 60 seconds instead of every 3 seconds.
- Refreshes news at most every 10 minutes and caches it in memory.
- Keeps the provider isolated in `LiveCricketRepository` so a different API can be added later.
- No API key is required and there is no paid cricket-data subscription in this implementation.

## Files to replace

1. `apps/mobile/lib/features/feed/data/feed_repository.dart`
2. `apps/mobile/lib/features/feed/presentation/feed_screen.dart`

## Run

```powershell
cd C:\Users\HP\Desktop\Crick\apps\mobile
flutter pub get
flutter analyze
flutter run -d chrome
```

## Important

The feed uses public ESPN endpoints. They are not an official paid developer API contract and may change without notice. The code therefore keeps all provider-specific logic inside one repository.

The app does **not** use Firebase scheduled functions for this feed, so this feature does not add Cloud Scheduler / Cloud Functions billing requirements. Firestore is still used only for Stumply's existing community feed posts.
