# Simple Certificate Conversion - Windows Only
# Uses Windows built-in tools

Write-Host "🔄 Converting iOS certificate (Windows method)..." -ForegroundColor Yellow

# Check files
if (-not (Test-Path "gavra_ios_private.key")) {
    Write-Host "❌ gavra_ios_private.key not found!" -ForegroundColor Red
    exit 1
}

$certFile = Get-ChildItem *.cer | Select-Object -First 1
if (-not $certFile) {
    Write-Host "❌ Certificate .cer file not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found certificate: $($certFile.Name)" -ForegroundColor Green

# For Windows users without OpenSSL, provide manual steps
Write-Host ""
Write-Host "📋 Manual conversion steps (since OpenSSL not available):" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1 - Use online converter:" -ForegroundColor Cyan
Write-Host "1. Go to: https://www.ssl.com/online-csr-and-key-generator/" -ForegroundColor White
Write-Host "2. Upload your certificate and private key" -ForegroundColor White
Write-Host "3. Download as P12 format" -ForegroundColor White
Write-Host ""
Write-Host "Option 2 - Install Git Bash:" -ForegroundColor Cyan
Write-Host "1. Download Git for Windows: https://git-scm.com/download/win" -ForegroundColor White
Write-Host "2. Open Git Bash in this folder" -ForegroundColor White
Write-Host "3. Run these commands:" -ForegroundColor White
Write-Host "   openssl x509 -in $($certFile.Name) -inform DER -out ios_distribution.pem -outform PEM" -ForegroundColor Gray
Write-Host "   openssl pkcs12 -export -out ios_distribution.p12 -inkey gavra_ios_private.key -in ios_distribution.pem -password pass:GavraApp2025" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 3 - Skip for now and use Keychain (macOS runner will handle):" -ForegroundColor Cyan
Write-Host "GitHub Actions macOS runner ima sve potrebne tools" -ForegroundColor White
Write-Host ""
Write-Host "📋 For GitHub Secrets you need:" -ForegroundColor Yellow
Write-Host "IOS_CERTIFICATE_BASE64 = (base64 of P12 file)" -ForegroundColor White
Write-Host "IOS_CERTIFICATE_PASSWORD = GavraApp2025" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next step: Create Provisioning Profile while we figure out P12 conversion" -ForegroundColor Green
