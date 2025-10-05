#!/usr/bin/env pwsh

# GitHub Actions Monitor Script
# Monitors gavra_android repository builds in real-time

param(
    [int]$RefreshInterval = 30,
    [int]$MaxRuns = 5
)

function Get-GitHubActions {
    try {
        $uri = "https://api.github.com/repos/bojanbc83/gavra_android/actions/runs?per_page=$MaxRuns"
        $response = Invoke-RestMethod -Uri $uri -Headers @{Accept="application/vnd.github.v3+json"}
        return $response.workflow_runs
    }
    catch {
        Write-Error "Failed to fetch GitHub Actions: $($_.Exception.Message)"
        return $null
    }
}

function Show-WorkflowRuns {
    param($runs)
    
    Write-Host "`n=== GITHUB ACTIONS MONITOR ===" -ForegroundColor Green
    Write-Host "Repository: bojanbc83/gavra_android" -ForegroundColor Yellow
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "Refresh every: $RefreshInterval seconds" -ForegroundColor Gray
    Write-Host ("-" * 80) -ForegroundColor Gray
    
    if (-not $runs) {
        Write-Host "No workflow runs found or API error" -ForegroundColor Red
        return
    }
    
    foreach ($run in $runs) {
        # Status color coding
        $statusColor = switch ($run.status) {
            "queued" { "Yellow" }
            "in_progress" { "Blue" }
            "completed" { 
                switch ($run.conclusion) {
                    "success" { "Green" }
                    "failure" { "Red" }
                    "cancelled" { "Gray" }
                    default { "White" }
                }
            }
            default { "White" }
        }
        
        # Format output
        $runId = $run.id.ToString().PadRight(12)
        $status = $run.status.PadRight(12)
        $conclusion = if ($run.conclusion) { "($($run.conclusion))".PadRight(12) } else { " ".PadRight(12) }
        $createdAt = [DateTime]::Parse($run.created_at).ToString("MM/dd HH:mm")
        
        Write-Host "[$runId] " -NoNewline -ForegroundColor Gray
        Write-Host "$($run.name.PadRight(20))" -NoNewline -ForegroundColor White
        Write-Host " $status" -NoNewline -ForegroundColor $statusColor
        Write-Host " $conclusion" -NoNewline -ForegroundColor $statusColor
        Write-Host " $createdAt" -ForegroundColor Gray
        
        # Show commit info
        if ($run.head_commit) {
            $commitMsg = $run.head_commit.message.Split("`n")[0]
            if ($commitMsg.Length -gt 60) { $commitMsg = $commitMsg.Substring(0, 57) + "..." }
            Write-Host "    └─ $commitMsg" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ("-" * 80) -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Magenta
}
}

# Main monitoring loop
try {
    Write-Host "Starting GitHub Actions monitor..." -ForegroundColor Green
    
    while ($true) {
        Clear-Host
        $runs = Get-GitHubActions
        Show-WorkflowRuns -runs $runs
        
        # Check if any runs are in progress
        $inProgress = $runs | Where-Object { $_.status -eq "in_progress" -or $_.status -eq "queued" }
        if ($inProgress) {
            Write-Host "`n🔄 Active builds detected! Monitoring..." -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds $RefreshInterval
    }
}
catch [System.OperationCanceledException] {
    Write-Host "`n`nMonitoring stopped by user." -ForegroundColor Yellow
}
catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host "Monitor session ended." -ForegroundColor Green
}