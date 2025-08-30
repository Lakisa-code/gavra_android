# 🍎 iOS TestFlight Deployment Setup

## Korak 1: Apple Developer Account
1. **Registruj se za Apple Developer Program** ($99/godišnje)
   - Idi na https://developer.apple.com/programs/
   - Završi registraciju sa Apple ID

2. **Kreiraj App ID**
   - Idi u Apple Developer Console → Certificates, Identifiers & Profiles
   - Klikni na "Identifiers" → "+" 
   - Izaberi "App IDs" → "App"
   - Description: "Gavra Android App"
   - Bundle ID: `com.gavra013.gavra_android` (Explicit)
   - Omogući potrebne capabilities:
     - ✅ Push Notifications (za notification servise)
     - ✅ Background Modes (za background tasks)
     - ✅ Associated Domains (ako imaš deep linking)
     - ✅ App Groups (ako koristiš widgets)
     - ✅ Maps (za Google Maps integration)

## Korak 2: Certificates & Provisioning Profiles

### 2.1 Distribution Certificate
```bash
# Generiraj CSR (Certificate Signing Request)
openssl req -new -newkey rsa:2048 -nodes -keyout gavra_ios.key -out gavra_ios.csr
```

1. Upload CSR u Apple Developer Console
2. Download certificate (.cer file)
3. Konvertuj u .p12:
```bash
# Import certificate u Keychain
# Export kao .p12 sa password-om
# Konvertuj u base64:
base64 -i certificate.p12 -o certificate_base64.txt
```

### 2.2 Distribution Provisioning Profile
1. U Apple Developer Console → Profiles → "+"
2. Izaberi "App Store" distribution
3. Izaberi tvoj App ID
4. Izaberi distribution certificate
5. Download .mobileprovision file
6. Konvertuj u base64:
```bash
base64 -i profile.mobileprovision -o profile_base64.txt
```

## Korak 3: App-Specific Password
1. Idi na https://appleid.apple.com/
2. Sign In & Security → App-Specific Passwords
3. Generiraj novi password za "GitHub Actions"

## Korak 4: GitHub Secrets Setup

Dodaj ove secrets u GitHub repo (Settings → Secrets and variables → Actions):

| Secret Name | Vrednost | Opis |
|-------------|----------|------|
| `IOS_CERTIFICATE_BASE64` | Content of certificate_base64.txt | Distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | Password koji si koristio za .p12 | Certificate password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Content of profile_base64.txt | Provisioning profile |
| `APPLE_ID` | your.email@example.com | Apple ID email |
| `APPLE_PASSWORD` | xxxx-xxxx-xxxx-xxxx | App-specific password |
| `APPLE_TEAM_ID` | XXXXXXXXXX | Team ID iz Developer Console |

## Korak 5: App Store Connect Setup
1. Idi na https://appstoreconnect.apple.com/
2. My Apps → "+" → New App
3. Popuni app informacije:
   - **Platform**: iOS
   - **Name**: "Gavra Android" 
   - **Primary Language**: Serbian (or English)
   - **Bundle ID**: `com.gavra013.gavra_android` (iz dropdown-a)
   - **SKU**: `gavra-android-2025` (unique identifier)
   - **User Access**: Full Access
4. App Information:
   - **Subtitle**: "Transport app for Gavra bus line"
   - **Privacy Policy URL**: (ako imaš)
   - **Category**: Navigation ili Travel
5. Pricing and Availability:
   - **Price**: Free (ili postavai cenu)
   - **Availability**: All countries ili specific regions

## Korak 6: Prvi Deployment
```bash
# Manual trigger workflow-a
gh workflow run deploy-ios-testflight.yml
```

## Korak 7: TestFlight Testing
1. U App Store Connect → TestFlight
2. Dodaj internal/external testers
3. Upload release notes
4. Poša test invitation

## Troubleshooting

### Česti problemi:
- **Certificate expired**: Renew certificate u Developer Console
- **Profile invalid**: Update provisioning profile
- **Upload failed**: Check App Store Connect app setup
- **Code signing error**: Verify Team ID i bundle ID match

### Debug komande:
```bash
# Check certificates
security find-identity -v -p codesigning

# Check provisioning profiles  
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Verify archive
xcodebuild -archivePath archive.xcarchive -showBuildSettings
```

## Napomene
- Prvi upload može da traje 30-60 minuta
- TestFlight builds se automatski testiraju od Apple-a
- External testing zahteva App Review process
- Internal testing je limitiran na 100 testera
