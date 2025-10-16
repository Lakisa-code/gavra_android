# 🔐 GAVRA ANDROID - KEYSTORE GENERATION GUIDE v6.0.0
# Production keystore creation for secure app signing

## 🚨 IMPORTANT SECURITY NOTICE
# Store these credentials SECURELY and create backups!
# Losing the keystore means you cannot update your app on Google Play!

Write-Host "🔐 GAVRA ANDROID KEYSTORE GENERATOR v6.0.0" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Yellow

# Generate secure production keystore
Write-Host "🔑 Creating production keystore..." -ForegroundColor Blue

# Navigate to android directory
Set-Location -Path "android"

# Generate keystore with keytool
# Replace placeholders with your actual information
$keystoreCommand = @"
keytool -genkey -v -keystore gavra-release-key-new.keystore -alias gavra-release-key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Gavra Android, OU=Development, O=Gavra, L=Belgrade, ST=Serbia, C=RS" -storepass YOUR_STORE_PASSWORD -keypass YOUR_KEY_PASSWORD
"@

Write-Host "📋 Keystore Command:" -ForegroundColor Cyan
Write-Host $keystoreCommand -ForegroundColor White

Write-Host "⚠️  MANUAL STEP REQUIRED:" -ForegroundColor Yellow
Write-Host "1. Replace YOUR_STORE_PASSWORD with a strong password (min 8 chars)" -ForegroundColor White
Write-Host "2. Replace YOUR_KEY_PASSWORD with a strong password (min 8 chars)" -ForegroundColor White
Write-Host "3. Update company information if needed in -dname parameter" -ForegroundColor White
Write-Host "4. Run the command above manually for security" -ForegroundColor White

Write-Host "📁 Expected output: gavra-release-key-new.keystore" -ForegroundColor Green

Write-Host "🔒 NEXT STEPS:" -ForegroundColor Magenta
Write-Host "1. Update gradle.properties with keystore credentials" -ForegroundColor White
Write-Host "2. Configure signing in android/app/build.gradle.kts" -ForegroundColor White
Write-Host "3. Test release build with new keystore" -ForegroundColor White

# Return to root
Set-Location -Path ".."

Write-Host "✅ Keystore generation guide completed!" -ForegroundColor Green