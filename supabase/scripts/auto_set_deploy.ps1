<#
Non-interactive automation script to set secrets and deploy notifications functions.
Usage:
  .\auto_set_deploy.ps1 -SupabaseUrl '<url>' -ServiceRole '<role>' -FcmServerKey '<key>' -HuaweiAppId '<id>' -HuaweiAppSecret '<secret>' -AgconnectPath '<path>' -GoogleServiceAccountJson '<file-or-json>' -FcmProjectId '<id>' -VerifyHuawei -Deploy

This script will:
 - Optionally copy `agconnect-services.json` to android/app
 - Set supabase secrets for FCM/Huawei/GOOGLE_SERVICE_ACCOUNT_JSON
 - Optionally verify Huawei credentials
 - Optionally run `deploy_notifications.ps1` to push migrations and deploy functions

Note: Be careful with secrets: prefer environment variables or CI secrets rather than passing them on the command-line on shared machines.
#>

param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$ServiceRole = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$FcmServerKey = $env:FCM_SERVER_KEY,
  [string]$HuaweiAppId = $env:HUAWEI_APP_ID,
  [string]$HuaweiAppSecret = $env:HUAWEI_APP_SECRET,
  [string]$AgconnectPath = $env:AGCONNECT_JSON_PATH,
  [string]$GoogleServiceAccountJson = $env:GOOGLE_SERVICE_ACCOUNT_JSON,
  [string]$FcmProjectId = $env:FCM_PROJECT_ID,
  [switch]$VerifyHuawei,
  [switch]$Deploy
)

# Validate required args
if (-not $SupabaseUrl -or -not $ServiceRole -or -not $FcmServerKey) {
  Write-Host "Missing required arguments SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY or FCM_SERVER_KEY. Aborting." -ForegroundColor Red
  exit 1
}

# Copy agconnect-services.json if provided
if ($AgconnectPath) {
  if (Test-Path $AgconnectPath) {
    $targetDir = Join-Path -Path (Split-Path -Parent (Get-Location)) -ChildPath "android/app"
    if (-not (Test-Path $targetDir)) { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null }
    $destPath = Join-Path $targetDir 'agconnect-services.json'
    Copy-Item -Path $AgconnectPath -Destination $destPath -Force
    Write-Host "Copied agconnect-services.json to: $destPath" -ForegroundColor Green
  } else {
    Write-Host "agconnect path not found: $AgconnectPath" -ForegroundColor Yellow
  }
}

# Set Supabase secrets (safely)
Write-Host "Setting Supabase secrets (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_SERVER_KEY)..." -ForegroundColor Cyan
supabase secrets set SUPABASE_URL=$SupabaseUrl
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$ServiceRole
supabase secrets set FCM_SERVER_KEY=$FcmServerKey

if ($HuaweiAppId -and $HuaweiAppSecret) {
  Write-Host "Setting HUAWEI secrets..." -ForegroundColor Cyan
  supabase secrets set HUAWEI_APP_ID=$HuaweiAppId
  supabase secrets set HUAWEI_APP_SECRET=$HuaweiAppSecret
} else {
  Write-Host "Huawei secrets not provided; skipping HUAWEI secrets set." -ForegroundColor Yellow
}

if ($GoogleServiceAccountJson) {
  Write-Host "Setting GOOGLE_SERVICE_ACCOUNT_JSON secret..." -ForegroundColor Cyan
  supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$GoogleServiceAccountJson"
}
if ($FcmProjectId) {
  supabase secrets set FCM_PROJECT_ID=$FcmProjectId
}

# Optional verification
if ($VerifyHuawei -and $HuaweiAppId -and $HuaweiAppSecret) {
  $verifyScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'verify_huawei_secrets.ps1'
  if (Test-Path $verifyScript) {
    Write-Host "Verifying Huawei secrets..." -ForegroundColor Cyan
    & $verifyScript -HuaweiAppId $HuaweiAppId -HuaweiAppSecret $HuaweiAppSecret
  } else {
    Write-Host "verify_huawei_secrets.ps1 not found. Skipping verification." -ForegroundColor Yellow
  }
} elseif ($VerifyHuawei) {
  Write-Host "Verify flag set but HUAWEI_APP_ID or HUAWEI_APP_SECRET missing. Skipping verification." -ForegroundColor Yellow
}

# Optional deploy
if ($Deploy) {
  $deployScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) '..\deploy_notifications.ps1'
  if (Test-Path $deployScript) {
    Write-Host "Deploying migrations and functions..." -ForegroundColor Cyan
    & $deployScript -VerifyHuawei
  } else {
    Write-Host "deploy_notifications.ps1 not found; skipping deploy." -ForegroundColor Yellow
  }
}

Write-Host "Auto set+deploy completed (or intended). Check Supabase logs/CLI for confirmation." -ForegroundColor Green
