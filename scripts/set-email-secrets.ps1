# Store Gmail SMTP credentials as Firebase secrets (run once after firebase login)
param(
    [Parameter(Mandatory = $true)]
    [string]$SmtpUser,
    [Parameter(Mandatory = $true)]
    [string]$SmtpPassword
)

$ErrorActionPreference = "Stop"
Write-Host "Setting SMTP_USER..." -ForegroundColor Cyan
$SmtpUser | firebase functions:secrets:set SMTP_USER

Write-Host "Setting SMTP_PASSWORD..." -ForegroundColor Cyan
$SmtpPassword | firebase functions:secrets:set SMTP_PASSWORD

Write-Host "Done. Deploy functions: firebase deploy --only functions" -ForegroundColor Green
