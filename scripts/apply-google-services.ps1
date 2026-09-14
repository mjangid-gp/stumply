# Generates firebase_options.dart from google-services.json (no flutterfire needed)
# Place google-services.json at: apps/mobile/android/app/google-services.json
# Then run: powershell -ExecutionPolicy Bypass -File scripts/apply-google-services.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$JsonPath = Join-Path $Root "apps\mobile\android\app\google-services.json"
$OutPath = Join-Path $Root "apps\mobile\lib\core\firebase\firebase_options.dart"

if (-not (Test-Path $JsonPath)) {
    Write-Host "Missing: $JsonPath" -ForegroundColor Red
    Write-Host @"

Download from Firebase Console:
  1. https://console.firebase.google.com/project/papakejamanekegaane/settings/general
  2. Your apps -> Add Android app (if needed)
  3. Package: com.crick.app.crick_app
  4. Download google-services.json -> save to path above

"@ -ForegroundColor Yellow
    exit 1
}

$g = Get-Content $JsonPath -Raw | ConvertFrom-Json
$client = $g.client[0]
$projectId = $g.project_info.project_id
$projectNumber = $g.project_info.project_number
$storageBucket = $g.project_info.storage_bucket
$appId = $client.client_info.mobilesdk_app_id
$apiKey = $client.api_key[0].current_key
$packageName = $client.client_info.android_client_info.package_name

# Default RTDB URL (update in Console if you use a different region)
$databaseUrl = "https://${projectId}-default-rtdb.firebaseio.com"

$content = @"
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Generated from google-services.json — project: $projectId
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$apiKey',
    appId: '$appId',
    messagingSenderId: '$projectNumber',
    projectId: '$projectId',
    authDomain: '$projectId.firebaseapp.com',
    storageBucket: '$storageBucket',
    databaseURL: '$databaseUrl',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$apiKey',
    appId: '$appId',
    messagingSenderId: '$projectNumber',
    projectId: '$projectId',
    storageBucket: '$storageBucket',
    databaseURL: '$databaseUrl',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '$apiKey',
    appId: '$appId',
    messagingSenderId: '$projectNumber',
    projectId: '$projectId',
    storageBucket: '$storageBucket',
    databaseURL: '$databaseUrl',
    iosBundleId: '$packageName',
  );
}
"@

Set-Content -Path $OutPath -Value $content -Encoding UTF8
Write-Host "Updated: $OutPath" -ForegroundColor Green
Write-Host "Project: $projectId | Package: $packageName" -ForegroundColor Cyan
