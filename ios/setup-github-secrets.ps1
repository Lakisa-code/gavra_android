# iOS GitHub Secrets Setup Script (PowerShell)
# Pokreni ovaj script da postaviš sve potrebne secrets za iOS deployment

Write-Host "🔐 iOS GitHub Secrets Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Generate MATCH_PASSWORD
$MATCH_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
Write-Host "✅ Generated MATCH_PASSWORD: $MATCH_PASSWORD" -ForegroundColor Green
Write-Host ""

# Generate MATCH_KEYCHAIN_PASSWORD
$MATCH_KEYCHAIN_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})
Write-Host "✅ Generated MATCH_KEYCHAIN_PASSWORD: $MATCH_KEYCHAIN_PASSWORD" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Potrebni GitHub Secrets:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. MATCH_GIT_URL"
Write-Host "   https://github.com/Lakisa-code/gavra-ios-certificates.git" -ForegroundColor White
Write-Host ""
Write-Host "2. MATCH_PASSWORD (copy paste from above)"
Write-Host "   $MATCH_PASSWORD" -ForegroundColor White
Write-Host ""
Write-Host "3. MATCH_GIT_BASIC_AUTHORIZATION (GitHub PAT)"
Write-Host "   Kreiraj Personal Access Token sa 'repo' scope-om:"
Write-Host "   https://github.com/settings/tokens/new" -ForegroundColor White
Write-Host "   Base64 encode format 'anyuser:TOKEN':"
Write-Host "   [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('anyuser:ghp_TOKEN_OVDE'))" -ForegroundColor White
Write-Host ""
Write-Host "4. FASTLANE_USER"
Write-Host "   Tvoj Apple ID email (npr. email@example.com)"
Write-Host ""
Write-Host "5. FASTLANE_PASSWORD"
Write-Host "   Tvoja Apple ID lozinka"
Write-Host ""
Write-Host "6. FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"
Write-Host "   Generiši na: https://appleid.apple.com/account/manage" -ForegroundColor White
Write-Host "   Security > App-Specific Passwords > Generate Password"
Write-Host ""
Write-Host "7. APPLE_TEAM_ID"
Write-Host "   Pronađi na: https://developer.apple.com/account" -ForegroundColor White
Write-Host "   Membership > Team ID"
Write-Host ""
Write-Host "8. MATCH_KEYCHAIN_NAME"
Write-Host "   match_keychain" -ForegroundColor White
Write-Host ""
Write-Host "9. MATCH_KEYCHAIN_PASSWORD (copy paste from above)"
Write-Host "   $MATCH_KEYCHAIN_PASSWORD" -ForegroundColor White
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Dodaj ove secrets u GitHub:" -ForegroundColor Yellow
Write-Host "https://github.com/Lakisa-code/gavra_android/settings/secrets/actions" -ForegroundColor White
Write-Host ""
Write-Host "Već postoje (može se preskočiti):" -ForegroundColor Green
Write-Host "- APPSTORE_KEY_ID"
Write-Host "- APPSTORE_ISSUER_ID"
Write-Host "- APPSTORE_API_KEY_P8"
Write-Host "- ENV_FILE_CONTENT"
Write-Host ""

# Save to file for easy reference
$output = @"
MATCH_PASSWORD=$MATCH_PASSWORD
MATCH_KEYCHAIN_PASSWORD=$MATCH_KEYCHAIN_PASSWORD
MATCH_GIT_URL=https://github.com/Lakisa-code/gavra-ios-certificates.git
MATCH_KEYCHAIN_NAME=match_keychain
"@

$output | Out-File -FilePath "github-secrets.txt" -Encoding UTF8
Write-Host "💾 Lozinke sačuvane u: github-secrets.txt" -ForegroundColor Green
