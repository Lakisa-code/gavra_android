<#
  PowerShell helper script to deploy Supabase Edge Functions and migrations
  (register-push-token, send-push-notification, etc.)

  Usage:
    1. Copy `supabase/.env.example` to `supabase/.env` and fill in values
    2. Run in PowerShell (from repo root):
       .\scripts\deploy-supabase-functions.ps1

  Notes:
    - Requires `supabase` CLI installed & logged in (https://supabase.com/docs/guides/cli)
    - `SUPABASE_SERVICE_ROLE_KEY` is sensitive. Provide it only in local `.env` or CI secrets.
    - This script performs basic checks and deploys DB migrations and Edge Functions.
#>

Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path "$scriptDir\.."
$envFile = "${repoRoot}\supabase\.env"

function fail($msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  fail "Supabase CLI is not installed. Install from https://supabase.com/docs/guides/cli and login (supabase login)."
}

if (-not (Test-Path $envFile)) {
  Write-Host "No env file found at $envFile" -ForegroundColor Yellow
  Write-Host "Please copy supabase/.env.example to supabase/.env and edit values (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_PROJECT_REF)." -ForegroundColor Yellow
  exit 1
}

$envContent = Get-Content $envFile | ConvertFrom-StringData
if (-not $envContent.SUPABASE_PROJECT_REF -or -not $envContent.SUPABASE_URL -or -not $envContent.SUPABASE_SERVICE_ROLE_KEY) {
  fail "One or more required environment variables are missing in $envFile (SUPABASE_PROJECT_REF/SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY)."
}

$projectRef = $envContent.SUPABASE_PROJECT_REF
$serviceRole = $envContent.SUPABASE_SERVICE_ROLE_KEY

Write-Host "Using Supabase project ref: $projectRef" -ForegroundColor Green

Write-Host "1) Running migrations (if any) using supabase db push..." -ForegroundColor Cyan
Push-Location "$repoRoot/supabase"
try {
  # push database schema. Requires supabase-cli to be logged in and have required rights.
  & supabase db push --project-ref $projectRef
} catch {
  Write-Host "Warning: supabase db push failed or not configured for this project. Please run migrations manually or via Supabase web UI." -ForegroundColor Yellow
}
Pop-Location

Write-Host "2) Deploying edge functions..." -ForegroundColor Cyan
$functionsDir = "$repoRoot/supabase/functions"

if (-not (Test-Path $functionsDir)) {
  fail "Directory $functionsDir not found. Make sure repo contains supabase functions." 
}

$toDeploy = @(
  "register-push-token"
  # add more function names here if you add them to supabase/functions
)

foreach ($fn in $toDeploy) {
  $fnPath = "$functionsDir\$fn"
  if (-not (Test-Path $fnPath)) {
    Write-Host "Skipping $fn - not found in $functionsDir" -ForegroundColor Yellow
    continue
  }
  Write-Host " - Deploying function: $fn" -ForegroundColor Green
  $deployCmd = "supabase functions deploy $fn --project-ref $projectRef --env-file $envFile"
  Write-Host "Running: $deployCmd" -ForegroundColor Gray
  $deployResult = & supabase functions deploy $fn --project-ref $projectRef --env-file $envFile 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Function $fn deploy failed:" -ForegroundColor Red
    Write-Host $deployResult
  } else {
    Write-Host "  -> deployed $fn successfully." -ForegroundColor Green
  }
}

Write-Host "3) Optional: Verify function routes from Supabase"
Write-Host "You can check the list of deployed function routes by running: supabase functions list --project-ref $projectRef" -ForegroundColor Cyan

Write-Host "If you rely on the Edge function to register push tokens, keep SUPABASE_SERVICE_ROLE_KEY secret. Consider using CI/CD secrets to handle this in production." -ForegroundColor Yellow

Write-Host "Done. After deploy, run the app again and we should see token registration succeed (or pending token will be registered)." -ForegroundColor Green
