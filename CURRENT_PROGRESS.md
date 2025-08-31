# 📋 iOS TestFlight Setup - Quick Guide

## Current Step: Certificate & Provisioning Profile Setup

### ✅ Completed:
- [x] Apple Developer Account ✓
- [x] Bundle ID defined: `com.gavra013.gavra-android`

### 🔄 Next Steps:

#### 1. Create App ID (in Apple Developer Console)
- Bundle ID: `com.gavra013.gavra-android`
- Enable capabilities: App Groups, Push Notifications, Maps

#### 2. Generate Certificate Signing Request (CSR)
```bash
# From project root
cd scripts
bash generate_csr.sh
```

#### 3. Create Distribution Certificate
1. Apple Developer Console → Certificates → "+"
2. Choose "iOS Distribution (App Store and Ad Hoc)"
3. Upload `gavra_ios.csr` file
4. Download certificate as `ios_distribution.cer`

#### 4. Convert Certificate for GitHub
```bash
# Place ios_distribution.cer in scripts/ios_certificates/
bash convert_certificate.sh
```

#### 5. Create Provisioning Profile
1. Apple Developer Console → Profiles → "+"
2. Choose "App Store"
3. Select App ID: `com.gavra013.gavra-android`
4. Select Distribution Certificate
5. Download as `gavra_android_appstore.mobileprovision`

#### 6. Convert Provisioning Profile
```bash
base64 -i gavra_android_appstore.mobileprovision -o provisioning_base64.txt
```

#### 7. Setup GitHub Secrets
Go to: https://github.com/bojanbc83/gavra_android/settings/secrets/actions

Add these secrets:
- `IOS_CERTIFICATE_BASE64` = content of `certificate_base64.txt`
- `IOS_CERTIFICATE_PASSWORD` = `GavraApp2025`
- `IOS_PROVISIONING_PROFILE_BASE64` = content of `provisioning_base64.txt`
- `APPLE_ID` = your Apple ID email
- `APPLE_PASSWORD` = app-specific password (generate at appleid.apple.com)
- `APPLE_TEAM_ID` = 10-character team ID from Developer Console

#### 8. Create App in App Store Connect
1. https://appstoreconnect.apple.com/ → My Apps → "+"
2. Name: "Gavra Android"
3. Bundle ID: `com.gavra013.gavra-android`
4. SKU: `gavra-android-2025`

#### 9. First TestFlight Deploy
```bash
gh workflow run deploy-ios-testflight.yml
```

---

## 🆘 Need Help?

**Current focus:** Complete App ID creation, then generate CSR.

**Files ready:**
- `scripts/generate_csr.sh` - Generate certificate signing request
- `scripts/convert_certificate.sh` - Convert Apple certificate for GitHub

**Let me know when you:**
- ✅ Created App ID successfully
- ❓ Have questions about any step
- 🆘 Encounter any errors
