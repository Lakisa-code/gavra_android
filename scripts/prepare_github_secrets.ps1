# Base64 Converter for GitHub Secrets
# Converts certificate and provisioning profile to base64

Write-Host "🔄 Converting files to Base64 for GitHub Secrets..." -ForegroundColor Yellow

$certDir = "ios_certificates"
if (-not (Test-Path $certDir)) {
    Write-Host "❌ ios_certificates folder not found!" -ForegroundColor Red
    exit 1
}

Set-Location $certDir

# Find certificate file (.cer)
$certFile = Get-ChildItem *.cer | Select-Object -First 1
if ($certFile) {
    Write-Host "✅ Found certificate: $($certFile.Name)" -ForegroundColor Green
    
    # Convert certificate to base64
    $certBytes = [System.IO.File]::ReadAllBytes($certFile.FullName)
    $certBase64 = [System.Convert]::ToBase64String($certBytes)
    $certBase64 | Out-File "certificate_base64.txt" -Encoding ASCII
    
    Write-Host "✅ Created certificate_base64.txt" -ForegroundColor Green
} else {
    Write-Host "❌ Certificate .cer file not found!" -ForegroundColor Red
}

# Find provisioning profile (.mobileprovision)
$provisionFile = Get-ChildItem *.mobileprovision | Select-Object -First 1
if ($provisionFile) {
    Write-Host "✅ Found provisioning profile: $($provisionFile.Name)" -ForegroundColor Green
    
    # Convert provisioning profile to base64
    $provisionBytes = [System.IO.File]::ReadAllBytes($provisionFile.FullName)
    $provisionBase64 = [System.Convert]::ToBase64String($provisionBytes)
    $provisionBase64 | Out-File "provisioning_base64.txt" -Encoding ASCII
    
    Write-Host "✅ Created provisioning_base64.txt" -ForegroundColor Green
} else {
    Write-Host "❌ Provisioning profile .mobileprovision file not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Base64 conversion completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 GitHub Secrets to add:" -ForegroundColor Yellow
Write-Host "Repository: https://github.com/bojanbc83/gavra_android/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""

if (Test-Path "certificate_base64.txt") {
    $certB64 = Get-Content "certificate_base64.txt" -Raw
    Write-Host "IOS_CERTIFICATE_BASE64:" -ForegroundColor White
    Write-Host $certB64.Substring(0, [Math]::Min(100, $certB64.Length)) -ForegroundColor Gray
    Write-Host "...(copy full content from certificate_base64.txt)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "IOS_CERTIFICATE_PASSWORD: GavraApp2025" -ForegroundColor White
Write-Host ""

if (Test-Path "provisioning_base64.txt") {
    $provB64 = Get-Content "provisioning_base64.txt" -Raw
    Write-Host "IOS_PROVISIONING_PROFILE_BASE64:" -ForegroundColor White
    Write-Host $provB64.Substring(0, [Math]::Min(100, $provB64.Length)) -ForegroundColor Gray
    Write-Host "...(copy full content from provisioning_base64.txt)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "🔑 Still needed:" -ForegroundColor Yellow
Write-Host "APPLE_ID: your Apple ID email" -ForegroundColor White
Write-Host "APPLE_PASSWORD: app-specific password (generate at appleid.apple.com)" -ForegroundColor White
Write-Host "APPLE_TEAM_ID: 6CY9Q44KMQ" -ForegroundColor White
Write-Host ""
Write-Host "Next step: Create app in App Store Connect" -ForegroundColor Cyan
