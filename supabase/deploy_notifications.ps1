# PowerShell script to deploy notification functions and migrations for Gavra Android
# Run this script in the repo root with Supabase CLI logged in

param(
  [string]$supabaseUrl = $env:SUPABASE_URL,
  [string]$serviceRole = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$fcmServerKey = $env:FCM_SERVER_KEY,
  [string]$huaweiAppId = $env:HUAWEI_APP_ID,
  [string]$huaweiAppSecret = $env:HUAWEI_APP_SECRET,
  [string]$fcmV1AccessToken = $env:FCM_V1_ACCESS_TOKEN,
  [string]$fcmProjectId = $env:FCM_PROJECT_ID,
  [string]$googleServiceAccountJson = $env:GOOGLE_SERVICE_ACCOUNT_JSON
  ,[switch]$VerifyHuawei
)

if (-not $supabaseUrl -or -not $serviceRole -or -not $fcmServerKey) {
  Write-Host "Missing required environment variables. Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_SERVER_KEY (and optionally HUAWEI_APP_ID/HUAWEI_APP_SECRET) before running." -ForegroundColor Red
  exit 1
}

# 1. Push migrations
Write-Host "Running migrations..." -ForegroundColor Cyan
supabase db push

# 2. Set secrets
Write-Host "Setting Supabase secrets..." -ForegroundColor Cyan
supabase secrets set SUPABASE_URL=$supabaseUrl
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceRole
supabase secrets set FCM_SERVER_KEY=$fcmServerKey
if ($huaweiAppId -and $huaweiAppSecret) {
  supabase secrets set HUAWEI_APP_ID=$huaweiAppId
  supabase secrets set HUAWEI_APP_SECRET=$huaweiAppSecret
}
if ($fcmV1AccessToken) {
  supabase secrets set FCM_V1_ACCESS_TOKEN=$fcmV1AccessToken
}
if ($fcmProjectId) {
  supabase secrets set FCM_PROJECT_ID=$fcmProjectId
}
if ($googleServiceAccountJson) {
  Write-Host "Setting GOOGLE_SERVICE_ACCOUNT_JSON secret..." -ForegroundColor Cyan
  supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$googleServiceAccountJson"
}

# Optional: Run a quick verification of Huawei secrets if they were provided or if flag is set
if ($VerifyHuawei -or ($huaweiAppId -and $huaweiAppSecret)) {
  Write-Host "Verifying Huawei secrets..." -ForegroundColor Cyan
  try {
    # Attempt to run the verify script in the repo
    $scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'scripts\verify_huawei_secrets.ps1'
    if (Test-Path $scriptPath) {
      & $scriptPath -HuaweiAppId $huaweiAppId -HuaweiAppSecret $huaweiAppSecret
    } else {
      Write-Host "verify_huawei_secrets.ps1 not found; skipping verification" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "Huawei verification failed: $_" -ForegroundColor Red
  }
}

# Check for agconnect json file (warning only)
$agconnectPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) '..\android\app\agconnect-services.json'
if (-not (Test-Path $agconnectPath)) {
  Write-Host "Note: agconnect-services.json not found in android/app/. If you're using HMS, please add the file locally or use supabase/scripts/set_huawei_secrets.ps1 to copy it." -ForegroundColor Yellow
} else {
  Write-Host "Found agconnect-services.json at $agconnectPath" -ForegroundColor Green
}

# 3. Deploy functions
Write-Host "Deploying Edge Functions..." -ForegroundColor Cyan
supabase functions deploy send-fcm-notification
supabase functions deploy send-push-notification
supabase functions deploy cleanup-push-players

Write-Host "✅ Done. Please verify function logs and test notifications with the provided commands in docs." -ForegroundColor Green
Write-Host "Tip: Pass the service account JSON content via environment or as a parameter. Example usage (PowerShell):" -ForegroundColor Yellow
Write-Host ".
\$env:GOOGLE_SERVICE_ACCOUNT_JSON = Get-Content -Raw path\\to\\service-account.json
.\supabase\deploy_notifications.ps1" -ForegroundColor White
