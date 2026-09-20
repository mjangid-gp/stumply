# Stumply — Google Places setup for Discover

The Discover screen can find nearby cricket grounds using the device location and Google Places API (New).

## 1. Create/choose a Google Cloud project

Open Google Cloud Console and enable **Places API (New)** for the project.

Google requires a billing account for production Places API usage. Google currently provides free monthly usage thresholds for Google Maps Platform services; for India, the current pricing page lists a 35,000-event monthly free threshold for Places API Nearby Search (Basic/Pro tier shown on the India pricing page). Usage beyond the free threshold can be billed, so set a budget/usage alert.

## 2. Create an API key

Create a Google Maps Platform API key and restrict it to the Places API (New).

For production:
- Android: restrict by Android application/package + SHA-1/SHA-256 as appropriate.
- iOS: restrict by iOS bundle ID.
- Web: restrict by HTTP referrer/domain.

Do not commit the API key to Git.

## 3. Run Flutter with the key

From `apps/mobile`:

```powershell
flutter pub get
flutter run -d chrome --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
```

Android example:

```powershell
flutter run -d <android-device> --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
```

Release builds should receive the key through your CI/CD secret or build configuration rather than source code.

## 4. Location permissions

The patch adds:
- Android fine/coarse location permissions.
- iOS `NSLocationWhenInUseUsageDescription`.
- `geolocator` for device/browser location.

On Chrome, browser location permission must be allowed. Production browser geolocation requires a secure context (HTTPS); localhost is also supported for development.

## 5. What the feature searches

Stumply uses Google Places Nearby Search for sports venues such as:
- athletic fields
- sports complexes
- stadiums
- sports activity locations
- sports clubs

It also performs a nearby Text Search for `cricket ground` so venues whose Google category is generic can still be found.

The UI only requests basic fields needed for the list and directions link.
