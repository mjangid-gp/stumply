# Downloads latest google-services.json and updates Google web client ID in app constants
param(
    [string]$ProjectId = "papakejamanekegaane",
    [string]$AppId = "1:897719037338:android:1c7050e3383cd2e8895e23"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$OutFile = Join-Path $Root "apps\mobile\android\app\google-services.json"
$ConstantsFile = Join-Path $Root "apps\mobile\lib\core\constants\app_constants.dart"

Write-Host "Downloading google-services.json..." -ForegroundColor Cyan
$config = firebase apps:sdkconfig ANDROID $AppId --project $ProjectId | Out-String
$jsonStart = $config.IndexOf("{")
if ($jsonStart -lt 0) { throw "Could not parse Firebase SDK config output." }
$json = $config.Substring($jsonStart) | ConvertFrom-Json
$json | ConvertTo-Json -Depth 20 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "Saved: $OutFile" -ForegroundColor Green

$webClientId = ""
foreach ($client in $json.client) {
    foreach ($oauth in $client.oauth_client) {
        if ($oauth.client_type -eq 3) {
            $webClientId = $oauth.client_id
            break
        }
    }
}

if ($webClientId) {
    $content = Get-Content $ConstantsFile -Raw
    $content = $content -replace "static const googleWebClientId = '[^']*';", "static const googleWebClientId = '$webClientId';"
    Set-Content -Path $ConstantsFile -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Updated googleWebClientId in app_constants.dart" -ForegroundColor Green
} else {
    Write-Host "No web OAuth client found yet. Enable Google sign-in in Firebase Console, then run this script again." -ForegroundColor Yellow
}
