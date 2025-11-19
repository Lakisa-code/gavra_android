param(
    [string]$EnvFile = "supabase-mcp-official/.env",
    [switch]$Install,
    [switch]$Build
)

# Simple helper to run the official Supabase MCP server from the workspace.
# Usage examples:
#  .\scripts\run-official-mcp.ps1           # run dev, loads env from default path
#  .\scripts\run-official-mcp.ps1 -Install  # install pnpm deps in the official repo
#  .\scripts\run-official-mcp.ps1 -Build    # build the official packages

Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path "$scriptDir\.." | Select-Object -ExpandProperty Path
$mcpDir = Join-Path $repoRoot 'supabase-mcp-official'

Write-Host "Repo root: $repoRoot"
Write-Host "MCP dir: $mcpDir"

if (-not (Test-Path $mcpDir)) {
    Write-Error "Official supabase-mcp directory not found at $mcpDir. Clone or extract it first."
    exit 1
}

function Load-EnvFile($path) {
    if (-not (Test-Path $path)) { return }
    Get-Content $path | ForEach-Object {
        $_ = $_.Trim()
        if ($_.StartsWith('#')) { return }
        if ($_.Length -eq 0) { return }
        $parts = $_ -split '='; if ($parts.Length -lt 2) { return }
        $key = $parts[0].Trim(); $value = ($parts[1..($parts.Length-1)] -join '=').Trim('"')
        Write-Host "Setting env: $key"
        $env:$key = $value
    }
}

if ($Install) {
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Host "pnpm is not installed; installing..."
        npm i -g pnpm
    }
    Write-Host "Installing workspace dependencies in $mcpDir"
    pnpm --prefix $mcpDir install
    exit 0
}

if ($Build) {
    Write-Host "Building official MCP packages in $mcpDir"
    pnpm --prefix $mcpDir build
    exit 0
}

# Load env file from parameter path (relative to repo root)
$envFileAbs = Join-Path $repoRoot $EnvFile
if (Test-Path $envFileAbs) {
    Write-Host "Loading env file: $envFileAbs"
    Load-EnvFile $envFileAbs
}

Write-Host "Starting official MCP dev server (workspace package: @supabase/mcp-server-supabase)"
pnpm --prefix $mcpDir --filter @supabase/mcp-server-supabase dev
