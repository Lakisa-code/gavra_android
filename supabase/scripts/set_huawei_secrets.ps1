<#
Set Huawei App ID/Secret and optional AGC file for AppGallery Connect.
Usage:
  .\set_huawei_secrets.ps1 -HuaweiAppId <id> -HuaweiAppSecret <secret> -AgconnectPath '<path to agconnect-services.json>' -SetSecrets -Verify -Deploy
  Or run interactively with no args to be prompted.

Prerequisites:
  - supabase CLI should be installed and authenticated
  - PowerShell (Windows) or pwsh (cross-platform)

What it does:
  - Optionally copies `agconnect-services.json` to `android/app/` if provided
  - Optionally runs `supabase secrets set HUAWEI_APP_ID` and `HUAWEI_APP_SECRET`
  - Optionally verify credentials using `verify_huawei_secrets.ps1`
  - Optionally run deploy (`deploy_notifications.ps1`) after secrets are set

#>

param(
  [string]$HuaweiAppId = $null,
  [string]$HuaweiAppSecret = $null,
  [string]$AgconnectPath = $null,
  [switch]$SetSecrets,
  [switch]$Verify,
  [switch]$Deploy
)

# Helper to read input
function Ask([string]$prompt, [string]$default = '') {
  if ($host.UI.RawUI.KeyAvailable -eq $false) { # if running non-interactive; fallback
    return $default
  }
  $value = Read-Host $prompt
  if (-not $value -and $default) { return $default }
  return $value
}

# Prompt for values if not provided
if (-not $HuaweiAppId) { $HuaweiAppId = Ask "Enter HUAWEI_APP_ID (or press Enter to skip)" }
if (-not $HuaweiAppSecret) { $HuaweiAppSecret = Ask "Enter HUAWEI_APP_SECRET (or press Enter to skip)" }
if (-not $AgconnectPath) { $AgconnectPath = Ask "Path to agconnect-services.json (optional, press Enter to skip)" }

# Copy agconnect-services.json to android/app
if ($AgconnectPath) {
  if (-not (Test-Path $AgconnectPath)) {
    Write-Host "agconnect path not found: $AgconnectPath" -ForegroundColor Red
  } else {
    $targetDir = Join-Path -Path (Split-Path -Parent (Get-Location)) -ChildPath "android/app"
    if (-not (Test-Path $targetDir)) { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null }
    $destPath = Join-Path $targetDir 'agconnect-services.json'
    Copy-Item -Path $AgconnectPath -Destination $destPath -Force
    Write-Host "Copied agconnect-services.json to: $destPath" -ForegroundColor Green
  }
}

# Optionally set supabase secrets
if ($SetSecrets) {
  if (-not $HuaweiAppId -or -not $HuaweiAppSecret) {
    Write-Host "Huawei App ID and Secret required to set secrets. Provide them or re-run with parameters." -ForegroundColor Yellow
  } else {
    Write-Host "Setting Supabase secrets..." -ForegroundColor Cyan
    try {
      supabase secrets set HUAWEI_APP_ID=$HuaweiAppId
      supabase secrets set HUAWEI_APP_SECRET=$HuaweiAppSecret
      Write-Host "Supabase secrets set for Huawei." -ForegroundColor Green
    } catch {
      Write-Host "Failed to set Supabase secrets: $_" -ForegroundColor Red
    }
  }
}

# Optionally verify using verify_huawei_secrets.ps1
if ($Verify) {
  if (-not $HuaweiAppId -or -not $HuaweiAppSecret) {
    Write-Host "Huawei App ID and Secret required for verify. Provide them or re-run with parameters." -ForegroundColor Yellow
  } else {
    $scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'verify_huawei_secrets.ps1'
    if (Test-Path $scriptPath) {
      Write-Host "Running Huawei verification..." -ForegroundColor Cyan
      & $scriptPath -HuaweiAppId $HuaweiAppId -HuaweiAppSecret $HuaweiAppSecret
    } else {
      Write-Host 'verify_huawei_secrets.ps1 not found; run it manually: "./verify_huawei_secrets.ps1 -HuaweiAppId <id> -HuaweiAppSecret <secret>"' -ForegroundColor Yellow
    }
  }
}

# Optionally deploy
if ($Deploy) {
  Write-Host "Deploying notifications (migrations + functions) via deploy_notifications.ps1" -ForegroundColor Cyan
  $deployScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) '..\deploy_notifications.ps1'
  if (Test-Path $deployScript) {
    # If we had secrets set, pass VerifyHuawei
    if ($Verify) { & $deployScript -VerifyHuawei } else { & $deployScript }
  } else {
    Write-Host "deploy_notifications.ps1 not found in supabase folder; run it manually" -ForegroundColor Yellow
  }
}

Write-Host "Done. If you ran set secrets, you may want to run 'supabase secrets list' and 'supabase functions logs' after deploy for verification." -ForegroundColor Green
