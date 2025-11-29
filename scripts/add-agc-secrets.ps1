<#
Add AGC secrets to GitHub repository (Actions) and Supabase Edge Functions

USAGE (PowerShell):
  .\scripts\add-agc-secrets.ps1 -JsonPath 'C:\path\to\agc-apiclient.json'

This script requires:
- GitHub CLI (gh) authenticated to the repository where you want to set secrets.
- Supabase CLI (if you want to set Supabase Edge Function secrets)

It will NOT commit the JSON to the repo. It will read the local JSON file, extract
client_id, client_secret and project_id and push them to GitHub Secrets and Supabase.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$JsonPath
)

if (-not (Test-Path $JsonPath)) {
    Write-Error "File not found: $JsonPath"
    exit 1
}

$raw = Get-Content -Raw -Path $JsonPath
try {
    $j = $raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON: $_"
    exit 1
}

$clientId = $j.client_id
$clientSecret = $j.client_secret
$projectId = $j.project_id

if (-not $clientId -or -not $clientSecret -or -not $projectId) {
    Write-Warning "JSON missing one of required fields: client_id | client_secret | project_id"
    Write-Warning "Proceeding anyway; verify values after running."
}

Write-Host "Setting GitHub secrets: AGC_CLIENT_ID, AGC_CLIENT_SECRET, AGC_APP_ID"
gh secret set AGC_CLIENT_ID --body $clientId; if ($LASTEXITCODE -ne 0) { Write-Warning "gh secret set AGC_CLIENT_ID failed" }
gh secret set AGC_CLIENT_SECRET --body $clientSecret; if ($LASTEXITCODE -ne 0) { Write-Warning "gh secret set AGC_CLIENT_SECRET failed" }
gh secret set AGC_APP_ID --body $projectId; if ($LASTEXITCODE -ne 0) { Write-Warning "gh secret set AGC_APP_ID failed" }

if (Get-Command supabase -ErrorAction SilentlyContinue) {
    Write-Host "Setting Supabase Edge Function secrets: AGC_APICLIENT_JSON, AGC_APP_ID"
    supabase secrets set AGC_APICLIENT_JSON="$raw"; if ($LASTEXITCODE -ne 0) { Write-Warning "supabase secrets set AGC_APICLIENT_JSON failed" }
    supabase secrets set AGC_APP_ID=$projectId; if ($LASTEXITCODE -ne 0) { Write-Warning "supabase secrets set AGC_APP_ID failed" }
} else {
    Write-Host "Supabase CLI not found - skip adding Supabase secrets (install supabase CLI to enable)."
}
