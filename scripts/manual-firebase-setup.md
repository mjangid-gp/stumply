# Manual Firebase setup (no CLI login link needed)

Use this if `auth.firebase.tools` shows "Missing required parameters".

## Step 0 — Enable Authentication (REQUIRED)

**Without this step, login, register, Google sign-in, and OTP will all fail.**

1. Open https://console.firebase.google.com/project/papakejamanekegaane/authentication
2. Click **Get started**
3. Open **Sign-in method** tab
4. Enable **Email/Password**
5. Enable **Google** (add support email when prompted)

Verify from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-auth-setup.ps1
```

## Step 1 — Add Android app in Firebase Console

1. Open https://console.firebase.google.com/project/papakejamanekegaane/settings/general
2. Scroll to **Your apps** → click **Add app** → **Android**
3. Package name: `com.crick.app.crick_app`
4. Download **google-services.json**
5. Copy it to: `apps/mobile/android/app/google-services.json`

## Step 2 — Enable services

In Firebase Console for project `papakejamanekegaane`:

- **Authentication** → Sign-in method → Email/Password + Google
- **Firestore** → Create database
- **Realtime Database** → Create database  
- **Storage** → Get started

## Step 3 — Register SHA-1 (for Google Sign-In)

In PowerShell:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copy **SHA-1** → Firebase Console → Project settings → Your Android app → Add fingerprint.

## Step 4 — CLI login (run in your own terminal)

Open **PowerShell** or **CMD** (not through a stale link):

```powershell
firebase login
```

This opens your browser with a valid session. After login:

```powershell
cd "c:\Users\HP\Desktop\Crick"
powershell -ExecutionPolicy Bypass -File scripts\setup-production.ps1
```

## Step 5 — Build APK

```powershell
cd "c:\Users\HP\Desktop\Crick\apps\mobile"
flutter build apk --release
```

Install: `build\app\outputs\flutter-apk\app-release.apk`
