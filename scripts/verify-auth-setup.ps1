# Verifies Firebase Authentication is enabled for Stumply
param(
    [string]$ProjectId = "papakejamanekegaane",
    [string]$ApiKey = "AIzaSyCGTTQpI4ReztUjjhmktywYor0qGzZeuvM"
)

$ErrorActionPreference = "Stop"
$testEmail = "stumply-auth-check-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())@example.com"

Write-Host "Checking Firebase Auth for project: $ProjectId" -ForegroundColor Cyan

$body = @{
    email = $testEmail
    password = "TestPass1!"
    returnSecureToken = $true
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod `
        -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$ApiKey" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body
    if ($response.idToken) {
        Write-Host "SUCCESS: Firebase Authentication is enabled." -ForegroundColor Green
        Write-Host "Email/password sign-up works. Test user was created: $testEmail" -ForegroundColor Green
        exit 0
    }
} catch {
    $errorBody = $_.ErrorDetails.Message
}

if ($errorBody -match "CONFIGURATION_NOT_FOUND") {
    Write-Host "FAILED: Firebase Authentication is NOT set up yet." -ForegroundColor Red
    Write-Host ""
    Write-Host "Do this once in your browser:" -ForegroundColor Yellow
    Write-Host "  1. Open https://console.firebase.google.com/project/$ProjectId/authentication"
    Write-Host "  2. Click 'Get started'"
    Write-Host "  3. Go to Sign-in method -> Enable Email/Password"
    Write-Host "  4. Enable Google (optional, for Google Sign-In)"
    Write-Host ""
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Unexpected response:" -ForegroundColor Red
Write-Host $errorBody
exit 1
