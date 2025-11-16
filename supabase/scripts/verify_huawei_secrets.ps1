<#
PowerShell script to verify Huawei APP ID/Secret by calling the HMS token endpoint.
Usage:
  .\verify_huawei_secrets.ps1 -HuaWeiAppId <id> -HuaweiAppSecret <secret>
Or rely on environment variables HUAWEI_APP_ID/HUAWEI_APP_SECRET.
#>

param(
  [string]$HuaweiAppId = $env:HUAWEI_APP_ID,
  [string]$HuaweiAppSecret = $env:HUAWEI_APP_SECRET
)

if (-not $HuaweiAppId -or -not $HuaweiAppSecret) {
  Write-Host "Missing HUAWEI_APP_ID or HUAWEI_APP_SECRET. Provide as parameters or via environment variables." -ForegroundColor Red
  exit 1
}

Write-Host "Verifying Huawei App ID/Secret by requesting an OAuth token..." -ForegroundColor Cyan

try {
  $body = @{ grant_type = 'client_credentials'; client_id = $HuaweiAppId; client_secret = $HuaweiAppSecret } | 
          ForEach-Object { ($_ | Get-Member -MemberType NoteProperty | ForEach-Object { "{0}={1}" -f $_.Name, ($body.$($_.Name) -as [string]) }) } # fallback
  # Use application/x-www-form-urlencoded
  $form = "grant_type=client_credentials&client_id={0}&client_secret={1}" -f [System.Web.HttpUtility]::UrlEncode($HuaweiAppId), [System.Web.HttpUtility]::UrlEncode($HuaweiAppSecret)
  $res = Invoke-RestMethod -Uri 'https://oauth-login.cloud.huawei.com/oauth2/v3/token' -Method Post -ContentType 'application/x-www-form-urlencoded' -Body $form -TimeoutSec 15
  if ($res.access_token) {
    Write-Host "✅ Huawei token fetched successfully. Token expires_in: $($res.expires_in) seconds" -ForegroundColor Green
    exit 0
  } else {
    Write-Host "❌ Failed to get access token. Response: $($res | ConvertTo-Json -Depth 4)" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Error while verifying Huawei credentials: $_" -ForegroundColor Red
  exit 1
}
