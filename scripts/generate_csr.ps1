# iOS Certificate Generation - PowerShell Script
# Generates CSR for Apple Developer Console

Write-Host "🔐 Generating iOS Certificate Signing Request (CSR)..." -ForegroundColor Yellow

# Create directory for certificates
New-Item -ItemType Directory -Force -Path "ios_certificates" | Out-Null
Set-Location "ios_certificates"

Write-Host "📋 You need OpenSSL to generate CSR." -ForegroundColor Cyan
Write-Host "Options:" -ForegroundColor White
Write-Host "1. Install OpenSSL: https://wiki.openssl.org/index.php/Binaries" -ForegroundColor Green
Write-Host "2. Use Git Bash: Run 'bash ../generate_csr.sh'" -ForegroundColor Green  
Write-Host "3. Use online CSR generator: https://www.ssl.com/online-csr-and-key-generator/" -ForegroundColor Green
Write-Host ""

Write-Host "📄 Manual CSR generation info needed:" -ForegroundColor Yellow
Write-Host "Country: RS" -ForegroundColor White
Write-Host "State: Serbia" -ForegroundColor White
Write-Host "City: Belgrade" -ForegroundColor White
Write-Host "Organization: Gavra013" -ForegroundColor White
Write-Host "Organizational Unit: Development" -ForegroundColor White
Write-Host "Common Name: Gavra Android App" -ForegroundColor White
Write-Host "Email: your.email@example.com" -ForegroundColor White
Write-Host ""

Write-Host "📋 Next steps after CSR generation:" -ForegroundColor Cyan
Write-Host "1. Upload .csr file to Apple Developer Console" -ForegroundColor White
Write-Host "2. Download certificate (.cer file)" -ForegroundColor White
Write-Host "3. Convert to P12 and Base64 for GitHub" -ForegroundColor White
