# AGC Setup Script - Automated certificate and configuration setup
# This script helps configure AGC settings that are commonly missed

Write-Host "=== AGC Setup Assistant ===" -ForegroundColor Green
Write-Host ""

# Certificate fingerprint from our APK
$debugFingerprint = "9A9285455BB0B30A64BD9D6FB37DDA6C2A32756573C511C6ACBEB438931E261D"
$appId = "116046535"
$packageName = "com.gavra013.gavra_android"

Write-Host "App Information:" -ForegroundColor Yellow
Write-Host "  App ID: $appId"
Write-Host "  Package: $packageName"
Write-Host "  Debug Certificate SHA-256: $debugFingerprint"
Write-Host ""

Write-Host "=== Steps to complete in AGC Console ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Click on 'App information' in the left sidebar" -ForegroundColor White
Write-Host "2. Find 'Signing Certificate Fingerprint' section" -ForegroundColor White
Write-Host "3. Click 'Add fingerprint' or '+' button" -ForegroundColor White
Write-Host "4. Paste this SHA-256 fingerprint:" -ForegroundColor White
Write-Host "   $debugFingerprint" -ForegroundColor Green
Write-Host "5. Click 'Save' or 'OK'" -ForegroundColor White
Write-Host ""

Write-Host "=== Optional: Enable Push Kit ===" -ForegroundColor Cyan
Write-Host "1. Go to 'Operate' tab" -ForegroundColor White
Write-Host "2. Find 'Push Kit' service" -ForegroundColor White
Write-Host "3. Click 'Enable' if not already enabled" -ForegroundColor White
Write-Host ""

Write-Host "=== After adding fingerprint ===" -ForegroundColor Cyan
Write-Host "1. Download new agconnect-services.json" -ForegroundColor White
Write-Host "2. Replace file in android/app/ folder" -ForegroundColor White
Write-Host "3. Rebuild and test app" -ForegroundColor White
Write-Host ""

# Copy fingerprint to clipboard for easy pasting
Write-Host "Copying debug certificate fingerprint to clipboard..." -ForegroundColor Yellow
Set-Clipboard -Value $debugFingerprint
Write-Host "✓ Certificate fingerprint copied to clipboard!" -ForegroundColor Green
Write-Host ""

Write-Host "You can now paste it directly in AGC Console" -ForegroundColor Green
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Open AGC console in browser
Write-Host "Opening AGC Console..." -ForegroundColor Yellow
$agcUrl = "https://developer.huawei.com/consumer/en/service/josp/agc/index.html#/myApp/$appId/v1825193948692350912"
Start-Process $agcUrl

Write-Host "Script completed! Follow the steps above in the browser." -ForegroundColor Green