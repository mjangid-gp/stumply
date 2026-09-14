# Stumply production setup: Firebase cloud + release APK
# Requires: Node 20+, Flutter, Firebase CLI (npm i -g firebase-tools)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/setup-production.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/setup-production.ps1 -ProjectId "your-firebase-project-id"

param(
    [string]$ProjectId = "papakejamanekegaane",
    [string]$ProjectName = "PapaKeJamaneKeGaane"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$env:Path = "C:\src\flutter\bin;C:\Program Files\GitHub CLI;" + $env:Path

function Require-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Missing command: $name"
    }
}

Write-Host "=== Stumply production setup ===" -ForegroundColor Cyan

Require-Command firebase
Require-Command flutter
Require-Command npm
Require-Command dart

# 1. Firebase login
$login = firebase login:list 2>&1 | Out-String
if ($login -match "No authorized accounts") {
    Write-Host "`nOpening browser for Firebase login..." -ForegroundColor Yellow
    firebase login
}

# 2. Create project if missing
$projects = firebase projects:list 2>&1 | Out-String
if ($projects -notmatch $ProjectId) {
    Write-Host "Creating Firebase project: $ProjectId" -ForegroundColor Yellow
    firebase projects:create $ProjectId --display-name $ProjectName
}

Set-Location $Root
firebase use $ProjectId

# 3. FlutterFire configure (Android + Web)
Write-Host "`nConfiguring Flutter Firebase..." -ForegroundColor Cyan
dart pub global activate flutterfire_cli 2>$null
Set-Location "$Root\apps\mobile"
flutterfire configure --project=$ProjectId --platforms=android,web --yes
Set-Location $Root

# 4. Install function dependencies and deploy backend
Write-Host "`nDeploying Firebase rules and functions..." -ForegroundColor Cyan
Set-Location "$Root\functions"
npm install
npm run build
Set-Location $Root

Write-Host @"

IMPORTANT: In Firebase Console (https://console.firebase.google.com/project/$ProjectId):
  1. Authentication -> Sign-in method -> Enable Email/Password and Google
  2. Firestore Database -> Create database (production mode, asia-south1)
  3. Realtime Database -> Create database (asia-south1)
  4. Storage -> Get started
  5. Upgrade to Blaze plan for Cloud Functions (free tier covers light usage)
  6. Project Settings -> Your apps -> Android -> Add SHA-1 fingerprint (see below)

"@ -ForegroundColor Yellow

firebase deploy --only firestore,database,storage,functions

# 5. Print SHA-1 for Google Sign-In
Write-Host "`nAndroid debug SHA-1 (register in Firebase Console):" -ForegroundColor Cyan
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($keytool) {
    keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>$null | Select-String "SHA1:"
}

# 6. Build release APK (uses cloud Firebase, not emulators)
Write-Host "`nBuilding release APK..." -ForegroundColor Cyan
Set-Location "$Root\apps\mobile"
flutter pub get
flutter build apk --release --dart-define=USE_FIREBASE_EMULATORS=false

$apk = "$Root\apps\mobile\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Install this APK on your phone:" -ForegroundColor Green
Write-Host $apk
Write-Host "`nFirebase project: https://console.firebase.google.com/project/$ProjectId" -ForegroundColor Cyan
