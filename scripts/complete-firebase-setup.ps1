# Run after: firebase login --no-localhost  (paste the auth code below)
# Usage: powershell -ExecutionPolicy Bypass -File scripts/complete-firebase-setup.ps1 -AuthCode "YOUR_CODE"

param(
    [Parameter(Mandatory = $true)]
    [string]$AuthCode
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$ProjectId = "papakejamanekegaane"
$env:Path = "C:\src\flutter\bin;C:\Users\HP\AppData\Local\Pub\Cache\bin;" + $env:Path

Write-Host "Logging into Firebase CLI..." -ForegroundColor Cyan
firebase login $AuthCode

Set-Location $Root
firebase use $ProjectId

Write-Host "Configuring Flutter for project $ProjectId..." -ForegroundColor Cyan
Set-Location "$Root\apps\mobile"
flutterfire configure --project=$ProjectId --platforms=android,web --yes

Set-Location "$Root\functions"
npm install
npm run build

Set-Location $Root
Write-Host "Deploying rules and functions..." -ForegroundColor Cyan
firebase deploy --only firestore,database,storage,functions

Set-Location "$Root\apps\mobile"
flutter pub get
flutter build apk --release --dart-define=USE_FIREBASE_EMULATORS=false

$apk = "$Root\apps\mobile\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "`nDone! Install APK:" -ForegroundColor Green
Write-Host $apk
