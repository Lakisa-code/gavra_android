# Simple P12 converter
Write-Host "Creating P12 certificate..." -ForegroundColor Yellow

if (-not (Test-Path "ios_distribution.cer")) {
    Write-Host "Certificate file not found!" -ForegroundColor Red
    exit 1
}

# For now, let's use online conversion method
Write-Host "Please use online tool to convert:" -ForegroundColor Yellow
Write-Host "1. Go to: https://www.ssl.com/online-tools/ssl-converter/" -ForegroundColor Cyan
Write-Host "2. Upload ios_distribution.cer" -ForegroundColor Cyan  
Write-Host "3. Upload gavra_ios_private.key" -ForegroundColor Cyan
Write-Host "4. Convert to P12 format" -ForegroundColor Cyan
Write-Host "5. Use password: GavraApp2025" -ForegroundColor Cyan
Write-Host "6. Download P12 file and convert to Base64" -ForegroundColor Cyan
