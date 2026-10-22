# Stores the Play upload key (and optionally the Play service account key) as
# GitHub Actions secrets for this repository. Values are read from local files
# and piped to `gh secret set`; nothing is printed.
#
#   .\tool\set_play_secrets.ps1
#   .\tool\set_play_secrets.ps1 -ServiceAccountJson C:\path\to\play-service-account.json
param([string]$ServiceAccountJson)

$ErrorActionPreference = 'Stop'
$props = Get-Content (Join-Path $PSScriptRoot '..\android\play-signing.properties') | ConvertFrom-StringData

[Convert]::ToBase64String([IO.File]::ReadAllBytes($props.storeFile)) | gh secret set PLAY_UPLOAD_KEYSTORE
$props.storePassword | gh secret set PLAY_UPLOAD_STORE_PASSWORD
$props.keyAlias | gh secret set PLAY_UPLOAD_KEY_ALIAS
$props.keyPassword | gh secret set PLAY_UPLOAD_KEY_PASSWORD

if ($ServiceAccountJson) {
    Get-Content -Raw $ServiceAccountJson | gh secret set PLAY_SERVICE_ACCOUNT_JSON
}

gh secret list
