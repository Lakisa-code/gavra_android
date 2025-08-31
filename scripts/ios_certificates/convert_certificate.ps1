# Certificate Conversion Script for GitHub Secrets
# Converts Apple certificate to P12 and Base64 format

Write-Host "🔄 Converting iOS certificate for GitHub Secrets..." -ForegroundColor Yellow

# Check if certificate files exist
$privateKey = "gavra_ios_private.key"
$certFiles = Get-ChildItem *.cer -ErrorAction SilentlyContinue

if (-not (Test-Path $privateKey)) {
    Write-Host "❌ Error: gavra_ios_private.key not found!" -ForegroundColor Red
    exit 1
}

if ($certFiles.Count -eq 0) {
    Write-Host "❌ Error: No .cer certificate file found!" -ForegroundColor Red
    Write-Host "Please make sure you downloaded the certificate from Apple Developer Console" -ForegroundColor Yellow
    exit 1
}

$certFile = $certFiles[0].Name
Write-Host "✅ Found certificate: $certFile" -ForegroundColor Green
Write-Host "✅ Found private key: $privateKey" -ForegroundColor Green

# Check if OpenSSL is available
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    Write-Host ""
    Write-Host "❌ OpenSSL not found!" -ForegroundColor Red
    Write-Host "📥 Installation options:" -ForegroundColor Yellow
    Write-Host "1. Install Git for Windows (includes OpenSSL): https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "2. Install OpenSSL directly: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Cyan
    Write-Host "3. Use WSL (Windows Subsystem for Linux)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Manual conversion steps:" -ForegroundColor Yellow
    Write-Host "1. Convert .cer to .pem: openssl x509 -in $certFile -inform DER -out ios_distribution.pem -outform PEM" -ForegroundColor White
    Write-Host "2. Create .p12: openssl pkcs12 -export -out ios_distribution.p12 -inkey $privateKey -in ios_distribution.pem -password pass:GavraApp2025" -ForegroundColor White
    Write-Host "3. Convert to base64: certutil -encode ios_distribution.p12 certificate_base64.txt" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "🔧 Converting certificate..." -ForegroundColor Cyan

# Convert certificate to PEM format
& openssl x509 -in $certFile -inform DER -out ios_distribution.pem -outform PEM
Write-Host "✅ Converted to PEM format" -ForegroundColor Green

# Create P12 certificate
& openssl pkcs12 -export -out ios_distribution.p12 -inkey $privateKey -in ios_distribution.pem -password pass:GavraApp2025
Write-Host "✅ Created P12 certificate with password: GavraApp2025" -ForegroundColor Green

# Convert to Base64 for GitHub Secrets
if (Get-Command certutil -ErrorAction SilentlyContinue) {
    certutil -encode ios_distribution.p12 certificate_base64_raw.txt | Out-Null
    # Remove certutil headers and create clean base64
    $base64Content = Get-Content certificate_base64_raw.txt | Where-Object { $_ -notmatch "-----" } | Out-String
    $base64Content.Trim() | Out-File certificate_base64.txt -Encoding ASCII
    Remove-Item certificate_base64_raw.txt
    Write-Host "✅ Created Base64 file: certificate_base64.txt" -ForegroundColor Green
} else {
    Write-Host "⚠️  certutil not found, using PowerShell method..." -ForegroundColor Yellow
    $bytes = [System.IO.File]::ReadAllBytes("ios_distribution.p12")
    $base64 = [System.Convert]::ToBase64String($bytes)
    $base64 | Out-File certificate_base64.txt -Encoding ASCII
    Write-Host "✅ Created Base64 file: certificate_base64.txt" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Certificate conversion completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 GitHub Secrets to add:" -ForegroundColor Yellow
Write-Host "IOS_CERTIFICATE_BASE64 = " -NoNewline -ForegroundColor White
$base64Value = Get-Content certificate_base64.txt -Raw
Write-Host $base64Value.Substring(0, [Math]::Min(50, $base64Value.Length)) -NoNewline -ForegroundColor Cyan
Write-Host "..." -ForegroundColor Cyan
Write-Host "IOS_CERTIFICATE_PASSWORD = GavraApp2025" -ForegroundColor White
Write-Host ""
Write-Host "📁 Files created:" -ForegroundColor Yellow
Write-Host "- ios_distribution.p12 (certificate file)" -ForegroundColor White
Write-Host "- certificate_base64.txt (for GitHub Secret)" -ForegroundColor White
Write-Host ""
Write-Host "📋 Next step: Create Provisioning Profile in Apple Developer Console" -ForegroundColor Cyan
