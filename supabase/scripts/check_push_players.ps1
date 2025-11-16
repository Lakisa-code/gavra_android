<#
Check push_players for a driver id and summarize providers and active tokens.
Usage:
  pwsh ./supabase/scripts/check_push_players.ps1 -SupabaseUrl 'https://<project>.supabase.co' -ServiceRole '<role>' -DriverId '<driver id>'
#>

param(
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$ServiceRole = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$DriverId,
  [switch]$FailIfNone
)

if (-not $SupabaseUrl -or -not $ServiceRole -or -not $DriverId) {
  Write-Host "Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or DriverId. Provide them as args or env vars." -ForegroundColor Red
  exit 1
}

$projectHost = ($SupabaseUrl -replace '^https?://','')
$url = "https://$projectHost/rest/v1/push_players?select=driver_id,player_id,provider,platform,is_active&driver_id=eq.$DriverId"

try {
  $rows = Invoke-RestMethod -Uri $url -Method Get -Headers @{ 'apikey' = $ServiceRole; 'Authorization' = "Bearer $ServiceRole" } -TimeoutSec 15
  if (-not $rows) {
    Write-Host "No push players found for driver: $DriverId" -ForegroundColor Yellow
    if ($FailIfNone) { exit 1 } else { exit 0 }
  }
  $count = $rows.Count
  Write-Host "Found $count push players for driver $DriverId" -ForegroundColor Cyan
  $byProvider = @{}
  foreach ($r in $rows) {
    $p = $r.provider
    if (-not $byProvider.ContainsKey($p)) { $byProvider[$p] = @() }
    $byProvider[$p] += $r.player_id
  }
  foreach ($k in $byProvider.Keys) {
    Write-Host ("Provider: {0} -> {1} token(s)" -f $k, $byProvider[$k].Count)
  }
} catch {
  Write-Host "Error fetching push_players: $_" -ForegroundColor Red
  exit 1
}
