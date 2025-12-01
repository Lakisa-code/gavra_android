<#
  Test helper: invoke a Supabase Edge Function register-push-token with a token

  Usage:
    .\scripts\register-pending-token.ps1 -Token <token> [-UserId <user_id>] [-ProjectRef <project-ref>]

  Behavior:
    - If no -ProjectRef is supplied, it reads supabase/.env for SUPABASE_PROJECT_REF
    - The function endpoint is: https://<project-ref>.functions.supabase.co/register-push-token
    - This only tests function invocation; the function itself should be configured with SUPABASE_SERVICE_ROLE_KEY env when deployed.
#>

param(
  [Parameter(Mandatory=$true)] [string]$Token,
  [string]$UserId = $null,
  [string]$ProjectRef = $null
)

$envFile = (Join-Path -Path (Resolve-Path "$PSScriptRoot\..") -ChildPath "supabase\.env")
if (-not $ProjectRef) {
  if (Test-Path $envFile) {
    $envContent = Get-Content $envFile | ConvertFrom-StringData
    $ProjectRef = $envContent.SUPABASE_PROJECT_REF
    if (-not $ProjectRef) { throw "SUPABASE_PROJECT_REF not found in $envFile" }
  } else {
    throw "ProjectRef not given and $envFile not found. Provide -ProjectRef or create supabase/.env from example.";
  }
}

$endpoint = "https://$ProjectRef.functions.supabase.co/register-push-token"
$payload = @{ provider = 'huawei'; token = $Token }
if ($UserId) { $payload.user_id = $UserId }

Write-Host "Invoking: $endpoint" -ForegroundColor Cyan
try {
  $resp = Invoke-RestMethod -Uri $endpoint -Method Post -Body ($payload | ConvertTo-Json -Depth 5) -ContentType 'application/json'
  Write-Host "Response: $($resp | ConvertTo-Json -Depth 3)" -ForegroundColor Green
} catch {
  Write-Host "Error invoking function: $_" -ForegroundColor Red
}
