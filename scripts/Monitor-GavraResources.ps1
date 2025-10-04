# Gavra Docker Memory Monitor
# Monitors resource usage and suggests optimizations

param(
    [switch]$Continuous,
    [int]$IntervalSeconds = 30
)

function Show-ResourceUsage {
    Clear-Host
    Write-Host "📊 GAVRA DOCKER RESOURCE MONITOR" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host ""
    
    # System Memory
    $totalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $availableRAM = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024
    $usedRAM = $totalRAM - $availableRAM
    $ramPercent = ($usedRAM / $totalRAM) * 100
    
    Write-Host "💾 SYSTEM MEMORY:" -ForegroundColor Cyan
    Write-Host "   Total: $([math]::Round($totalRAM, 1))GB"
    Write-Host "   Used:  $([math]::Round($usedRAM, 1))GB ($([math]::Round($ramPercent, 1))%)"
    Write-Host "   Free:  $([math]::Round($availableRAM, 1))GB"
    
    if ($ramPercent -gt 85) {
        Write-Host "   ⚠️  HIGH MEMORY USAGE!" -ForegroundColor Red
    } elseif ($ramPercent -gt 70) {
        Write-Host "   ⚠️  Moderate memory usage" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Memory usage OK" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Docker Containers
    Write-Host "🐳 DOCKER CONTAINERS:" -ForegroundColor Cyan
    try {
        $containers = docker stats --no-stream --format "{{.Container}};{{.CPUPerc}};{{.MemUsage}};{{.MemPerc}}" 2>$null
        if ($containers) {
            Write-Host "   Container                    CPU%    Memory Usage    Mem%"
            Write-Host "   -------------------------    ----    ------------    ----"
            foreach ($container in $containers) {
                $parts = $container -split ';'
                if ($parts.Count -eq 4) {
                    $name = $parts[0] -replace 'supabase_', '' -replace '_gavra_android', ''
                    Write-Host "   $($name.PadRight(28)) $($parts[1].PadLeft(6)) $($parts[2].PadLeft(12)) $($parts[3].PadLeft(6))"
                }
            }
        } else {
            Write-Host "   No running containers found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   Error reading Docker stats" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Recommendations
    if ($ramPercent -gt 85) {
        Write-Host "💡 OPTIMIZATION SUGGESTIONS:" -ForegroundColor Yellow
        Write-Host "   • Close unused applications"
        Write-Host "   • Run: docker system prune -f"
        Write-Host "   • Restart Docker Desktop"
        Write-Host "   • Consider reducing Supabase services"
    }
    
    Write-Host ""
    Write-Host "Last updated: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($Continuous) {
        Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Gray
    }
}

if ($Continuous) {
    while ($true) {
        Show-ResourceUsage
        Start-Sleep $IntervalSeconds
    }
} else {
    Show-ResourceUsage
}