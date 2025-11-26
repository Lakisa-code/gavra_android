# Script to watch Flutter debug output for geocoding logs
# Usage: Run this in a separate terminal while flutter run is active

Write-Host "🔍 Watching for geocoding debug output..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Create a temporary file to store captured logs
$logFile = "$env:TEMP\geocoding_debug_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-Host "📝 Logs will be saved to: $logFile" -ForegroundColor Green
Write-Host ""

# Monitor the flutter process output
# Since we can't directly tap into the running flutter process,
# let's create a simple ADB logcat filter

Write-Host "Starting ADB logcat filter for Flutter debug messages..." -ForegroundColor Cyan

# Run adb logcat and filter for our debug messages
adb logcat -v time flutter:V *:S 2>&1 | ForEach-Object {
    $line = $_
    
    # Check for our geocoding debug markers
    if ($line -match "GEOCODING DEBUG|Putnik:|Adresa:|adresaId|koordinate|Nominatim|OPTIMIZATION") {
        # Color code different types of messages
        if ($line -match "===") {
            Write-Host $line -ForegroundColor Magenta
        }
        elseif ($line -match "Putnik:") {
            Write-Host $line -ForegroundColor Cyan
        }
        elseif ($line -match "Adresa:") {
            Write-Host $line -ForegroundColor Yellow
        }
        elseif ($line -match "koordinate|coordinates") {
            Write-Host $line -ForegroundColor Green
        }
        elseif ($line -match "ERROR|error|Error") {
            Write-Host $line -ForegroundColor Red
        }
        else {
            Write-Host $line -ForegroundColor White
        }
        
        # Also save to file
        $line | Out-File -FilePath $logFile -Append
    }
}
