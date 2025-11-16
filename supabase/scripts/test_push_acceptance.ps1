<#
Trigger a test push to an existing driver or token via the `send-push-notification` Edge function.
Usage:
  pwsh ./supabase/scripts/test_push_acceptance.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<role>' -DriverId 'driver_1'
  or
  pwsh ./supabase/scripts/test_push_acceptance.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<role>' -Token '<device-token>' -Provider 'huawei|fcm'
#>

param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$ServiceRole = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$DriverId = $null,
  [string]$Token = $null,
  [string]$Provider = 'fcm'
)

if (-not $SupabaseUrl -or -not $ServiceRole) {
  Write-Host "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Provide them as args or env vars." -ForegroundColor Red
  exit 1
}

$body = @{}
if ($DriverId) { $body['driver_ids'] = @($DriverId) }
if ($Token) { $body['tokens'] = @(@{ token = $Token; provider = $Provider }) }
$body['title'] = 'Acceptance Test'
$body['body'] = 'This is a CI/manual acceptance test.'
$payload = $body | ConvertTo-Json -Depth 5

$projectHost = ($SupabaseUrl -replace '^https?://','')
$url = "https://$projectHost/functions/v1/send-push-notification"

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{ 'apikey' = $ServiceRole; 'Authorization' = "Bearer $ServiceRole" } -ContentType 'application/json' -Body $payload -TimeoutSec 30
    Write-Host "Response: $($response | ConvertTo-Json -Depth 5)"
    # Basic validation: check common fields for legacy FCM
    try {
      if ($response.success -eq $true) { Write-Host 'send-push-notification reported success' -ForegroundColor Green }
      elseif ($response.failure -gt 0) { Write-Host "send-push-notification had failures: $($response.failure)" -ForegroundColor Yellow }
      else { Write-Host 'Response parse did not yield standard fields; continue to validate via push_players' -ForegroundColor Cyan }
    } catch { Write-Host 'Cannot parse response; continuing to validate using token checks' -ForegroundColor Yellow }

    # Now check whether the driver has active push tokens; fail if none
    if (Test-Path .\supabase\scripts\check_push_players.ps1) {
      pwsh .\supabase\scripts\check_push_players.ps1 -SupabaseUrl $SupabaseUrl -ServiceRole $ServiceRole -DriverId $DriverId -FailIfNone
    } else {
      # Fallback: manual check by querying the REST API
      $checkUrl = "https://$projectHost/rest/v1/push_players?select=player_id,provider,platform,is_active&driver_id=eq.$DriverId&is_active=eq.true"
      try {
        $rows = Invoke-RestMethod -Uri $checkUrl -Method Get -Headers @{ 'apikey' = $ServiceRole; 'Authorization' = "Bearer $ServiceRole" } -TimeoutSec 15
        if (-not $rows -or $rows.Count -eq 0) { Write-Host 'FAIL: No active push players for driver' -ForegroundColor Red; exit 1 }
      } catch { Write-Host "Error while checking tokens: $_" -ForegroundColor Red; exit 1 }
    }
} catch {
  Write-Host "Error calling send-push-notification: $_" -ForegroundColor Red
  exit 1
}

Write-Host "Done" -ForegroundColor Green
