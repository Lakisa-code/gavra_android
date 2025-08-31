# Create P12 certificate for iOS code signing
# This combines the certificate and private key into a single P12 file

Write-Host "🔐 Creating P12 certificate file..." -ForegroundColor Yellow

# Check if files exist
if (-not (Test-Path "ios_distribution.cer")) {
    Write-Host "❌ ios_distribution.cer not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "gavra_ios_private.key")) {
    Write-Host "❌ gavra_ios_private.key not found!" -ForegroundColor Red
    exit 1
}

try {
    # Read the certificate
    $certBytes = [System.IO.File]::ReadAllBytes("ios_distribution.cer")
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)
    
    # Read private key (PEM format)
    $keyContent = Get-Content "gavra_ios_private.key" -Raw
    
    # Remove PEM headers and decode
    $keyContent = $keyContent -replace "-----BEGIN PRIVATE KEY-----", ""
    $keyContent = $keyContent -replace "-----END PRIVATE KEY-----", ""
    $keyContent = $keyContent -replace "`r", "" -replace "`n", ""
    $keyBytes = [System.Convert]::FromBase64String($keyContent)
    
    # Create RSA key from bytes
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportPkcs8PrivateKey($keyBytes, $out $null)
    
    # Combine certificate and private key
    $certWithKey = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
    $certWithKey = $certWithKey.CopyWithPrivateKey($rsa)
    
    # Export as P12 with password
    $password = "GavraApp2025"
    $securePassword = ConvertTo-SecureString -String $password -Force -AsPlainText
    $p12Bytes = $certWithKey.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $securePassword)
    
    # Save P12 file
    [System.IO.File]::WriteAllBytes("ios_distribution.p12", $p12Bytes)
    
    # Convert to Base64 for GitHub Secret
    $p12Base64 = [System.Convert]::ToBase64String($p12Bytes)
    $p12Base64 | Out-File "certificate_p12_base64.txt" -Encoding ASCII
    
    Write-Host "✅ Created ios_distribution.p12" -ForegroundColor Green
    Write-Host "✅ Created certificate_p12_base64.txt" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Update GitHub Secret:" -ForegroundColor Yellow
    Write-Host "IOS_CERTIFICATE_BASE64: Use content from certificate_p12_base64.txt" -ForegroundColor Cyan
    
}
catch {
    Write-Host "❌ Failed to create P12 certificate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Alternative: Use online tool to convert:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://www.ssl.com/online-tools/ssl-converter/" -ForegroundColor Cyan
    Write-Host "2. Upload ios_distribution.cer and gavra_ios_private.key" -ForegroundColor Cyan
    Write-Host "3. Convert to P12 format with password: GavraApp2025" -ForegroundColor Cyan
    Write-Host "4. Download P12 file and convert to Base64" -ForegroundColor Cyan
}
