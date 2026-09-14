# Run after creating a GitHub Personal Access Token (classic) with "repo" scope.
# https://github.com/settings/tokens

param(
    [Parameter(Mandatory = $true)]
    [string]$Token,
    [string]$RepoName = "crick"
)

$ErrorActionPreference = "Stop"
$env:Path = "C:\Program Files\GitHub CLI;" + $env:Path

$Token | gh auth login --hostname github.com --git-protocol https --with-token
[Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $Token, "User")
$env:GITHUB_TOKEN = $Token

Set-Location (Split-Path $PSScriptRoot -Parent)
gh repo create $RepoName --private --source=. --remote=origin --push

Write-Host "Done. Repo: https://github.com/mjangid-gp/$RepoName"
