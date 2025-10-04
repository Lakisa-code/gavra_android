# Gavra Development Environment PowerShell Script
# Optimized for Intel Celeron N4020 + 8GB RAM

Write-Host "🚀 Starting Gavra optimized development environment..." -ForegroundColor Green

# Check Docker status
Write-Host "🐳 Checking Docker status..." -ForegroundColor Blue
$dockerStatus = docker version --format '{{.Server.Version}}' 2>$null
if (-not $dockerStatus) {
    Write-Host "❌ Docker not running. Starting Docker Desktop..." -ForegroundColor Red
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "⏳ Waiting for Docker to start..." -ForegroundColor Yellow
    Start-Sleep 30
}

# Set resource limits for development
Write-Host "⚙️ Setting resource limits for Gavra app..." -ForegroundColor Blue
$env:COMPOSE_HTTP_TIMEOUT = "120"
$env:DOCKER_BUILDKIT = "1"

# Clean up any existing containers to free memory
Write-Host "🧹 Cleaning up unused containers..." -ForegroundColor Yellow
docker system prune -f --volumes 2>$null

# Check available memory
$totalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$availableRAM = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024
Write-Host "💾 Total RAM: $([math]::Round($totalRAM, 1))GB | Available: $([math]::Round($availableRAM, 1))GB" -ForegroundColor Cyan

if ($availableRAM -lt 2) {
    Write-Host "⚠️  Low memory detected. Consider closing other applications." -ForegroundColor Yellow
}

# Start Supabase with optimizations
Write-Host "📊 Starting Supabase with optimized settings..." -ForegroundColor Green
supabase start

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Gavra development environment ready!" -ForegroundColor Green
    Write-Host "📱 Run 'flutter run' to start the app" -ForegroundColor White
    Write-Host "🌐 Studio: http://127.0.0.1:54323" -ForegroundColor Cyan
    Write-Host "🔗 API: http://127.0.0.1:54321" -ForegroundColor Cyan
    
    # Show container resource usage
    Write-Host "💾 Container resource usage:" -ForegroundColor Blue
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | Select-Object -First 10
} else {
    Write-Host "❌ Failed to start Supabase. Check Docker resources." -ForegroundColor Red
}