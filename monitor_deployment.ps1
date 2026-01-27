#!/usr/bin/env powershell
<#
.SYNOPSIS
    Monitor GitHub Actions Deployment Status
#>

param(
    [string]$Owner = "kadpitamkurac-hash",
    [string]$Repo = "gavra_android",
    [string]$Workflow = "unified-deploy-all.yml"
)

function Get-WorkflowRuns {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Workflow
    )
    
    Write-Host ""
    Write-Host "Fetching workflow runs..." -ForegroundColor Cyan
    
    $runs = gh run list `
        --repo "$Owner/$Repo" `
        --workflow "$Workflow" `
        --limit 5 `
        --json status,conclusion,name,number,createdAt,url `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $runsObj = $runs | ConvertFrom-Json
        return $runsObj
    } else {
        Write-Host "ERROR: Could not fetch runs" -ForegroundColor Red
        return $null
    }
}

function Show-RunStatus {
    param(
        [PSObject]$Run
    )
    
    $number = $Run.number
    $status = $Run.status
    $conclusion = $Run.conclusion ?? "PENDING"
    $createdAt = $Run.createdAt
    $url = $Run.url
    
    # Emoji based on status
    $emoji = switch ($status) {
        "completed" {
            if ($conclusion -eq "success") { "✅" } 
            elseif ($conclusion -eq "failure") { "❌" } 
            else { "⏸️" }
        }
        "in_progress" { "🔄" }
        "queued" { "⏳" }
        default { "❓" }
    }
    
    $statusStr = "$status".ToUpper()
    if ($conclusion -ne "PENDING") {
        $statusStr += " / $conclusion"
    }
    
    Write-Host "  $emoji Run #$number [$statusStr]" -ForegroundColor Yellow
    Write-Host "     Created: $createdAt" -ForegroundColor Gray
    Write-Host "     URL: $url" -ForegroundColor Cyan
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 GITHUB ACTIONS DEPLOYMENT MONITOR" -ForegroundColor Cyan
Write-Host "   Version 6.0.50+420" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$runs = Get-WorkflowRuns -Owner $Owner -Repo $Repo -Workflow $Workflow

if ($runs -and $runs.Count -gt 0) {
    Write-Host ""
    Write-Host "Recent Workflow Runs:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($run in $runs) {
        Show-RunStatus -Run $run
    }
    
    # Focus on latest
    $latest = $runs[0]
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "Latest Run Details:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Status: $($latest.status.ToUpper())" -ForegroundColor Yellow
    Write-Host "  Conclusion: $($latest.conclusion ?? 'PENDING')" -ForegroundColor Yellow
    Write-Host "  URL: $($latest.url)" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Live Monitoring:" -ForegroundColor Yellow
    Write-Host "  gh run watch --repo $Owner/$Repo" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Detailed Logs:" -ForegroundColor Yellow
    Write-Host "  gh run view $($latest.number) --repo $Owner/$Repo --log" -ForegroundColor Gray
    Write-Host ""
    
} else {
    Write-Host "No runs found" -ForegroundColor Red
}

Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Cyan
