Set-StrictMode -Version Latest

param(
    [switch]$OpenDashboard
)

$supabaseCmd = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCmd) {
    Write-Error "Supabase CLI not found. Install it: https://supabase.com/docs/guides/cli"
    exit 1
}

Write-Host "Starting Supabase local development (this may require Docker)"
supabase start

if ($OpenDashboard) {
    Start-Process "https://localhost:8080"
}

Write-Host "Supabase local started. MCP endpoint (if enabled by CLI): http://localhost:54321/mcp"
