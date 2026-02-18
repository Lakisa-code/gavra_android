#!/usr/bin/env bash

# iOS GitHub Secrets Setup Script
# Pokreni ovaj script da postaviš sve potrebne secrets za iOS deployment

echo "🔐 iOS GitHub Secrets Setup"
echo "================================"
echo ""

# Generate MATCH_PASSWORD
MATCH_PASSWORD=$(openssl rand -base64 32)
echo "✅ Generated MATCH_PASSWORD: $MATCH_PASSWORD"
echo ""

# Generate MATCH_KEYCHAIN_PASSWORD
MATCH_KEYCHAIN_PASSWORD=$(openssl rand -base64 16)
echo "✅ Generated MATCH_KEYCHAIN_PASSWORD: $MATCH_KEYCHAIN_PASSWORD"
echo ""

echo "📋 Potrebni GitHub Secrets:"
echo ""
echo "1. MATCH_GIT_URL"
echo "   https://github.com/Lakisa-code/gavra-ios-certificates.git"
echo ""
echo "2. MATCH_PASSWORD (copy paste from above)"
echo "   $MATCH_PASSWORD"
echo ""
echo "3. MATCH_GIT_BASIC_AUTHORIZATION (GitHub PAT)"
echo "   Kreiraj Personal Access Token sa 'repo' scope-om:"
echo "   https://github.com/settings/tokens/new"
echo "   Zatim encode-uj: echo -n 'YOUR_TOKEN' | base64"
echo ""
echo "4. FASTLANE_USER"
echo "   Tvoj Apple ID email (npr. email@example.com)"
echo ""
echo "5. FASTLANE_PASSWORD"
echo "   Tvoja Apple ID lozinka"
echo ""
echo "6. FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"
echo "   Generiši na: https://appleid.apple.com/account/manage"
echo "   Security > App-Specific Passwords > Generate Password"
echo ""
echo "7. APPLE_TEAM_ID"
echo "   Pronađi na: https://developer.apple.com/account"
echo "   Membership > Team ID"
echo ""
echo "8. MATCH_KEYCHAIN_NAME"
echo "   match_keychain"
echo ""
echo "9. MATCH_KEYCHAIN_PASSWORD (copy paste from above)"
echo "   $MATCH_KEYCHAIN_PASSWORD"
echo ""
echo "================================"
echo "Dodaj ove secrets u GitHub:"
echo "https://github.com/Lakisa-code/gavra_android/settings/secrets/actions"
echo ""
echo "Već postoje (može se preskočiti):"
echo "- APPSTORE_KEY_ID"
echo "- APPSTORE_ISSUER_ID"
echo "- APPSTORE_API_KEY_P8"
echo "- ENV_FILE_CONTENT"
echo ""
