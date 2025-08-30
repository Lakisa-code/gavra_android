# 📋 iOS App Setup Checklist

## Pre deployment-a

### ✅ Apple Developer Console Setup
- [ ] App ID kreiran: `com.gavra013.gavra_android`
- [ ] Push Notifications capability enabled
- [ ] Background Modes capability enabled
- [ ] Maps capability enabled (za Google Maps)
- [ ] Distribution Certificate kreiran i downloadovan
- [ ] Provisioning Profile kreiran za App Store distribution

### ✅ App Store Connect Setup
- [ ] Nova app kreirana: "Gavra Android"
- [ ] Bundle ID izabran: `com.gavra013.gavra_android`
- [ ] SKU postavljen: `gavra-android-2025`
- [ ] App Information popunjena
- [ ] Privacy Policy URL dodana (opciono)
- [ ] Category postavljena (Navigation/Travel)
- [ ] Pricing postavljen (Free ili paid)

### ✅ GitHub Secrets Setup
- [ ] `IOS_CERTIFICATE_BASE64` - Distribution certificate (base64)
- [ ] `IOS_CERTIFICATE_PASSWORD` - Certificate password
- [ ] `IOS_PROVISIONING_PROFILE_BASE64` - Provisioning profile (base64)
- [ ] `APPLE_ID` - Apple ID email
- [ ] `APPLE_PASSWORD` - App-specific password
- [ ] `APPLE_TEAM_ID` - Team ID (10 karaktera)

### ✅ Local Testing
- [ ] iOS test workflow prošao uspešno
- [ ] App kompajlira bez grešaka
- [ ] All dependencies resolved
- [ ] Deployment target set to 15.0

## Prvi Deploy

### 🚀 Commands
```bash
# Check workflow status
gh workflow list

# Trigger iOS TestFlight deployment
gh workflow run deploy-ios-testflight.yml

# Monitor deployment
gh run watch --interval 30
```

### 📱 Post-Deploy
- [ ] Build pojavljen u App Store Connect
- [ ] TestFlight build processed uspešno
- [ ] Internal testers dodani
- [ ] External testing setup (opciono)
- [ ] Release notes dodane

## Troubleshooting

### Česti problemi:
- **Bundle ID mismatch**: Check App ID u Developer Console
- **Certificate invalid**: Regenerate certificate i provisioning profile
- **Upload failed**: Check Team ID i Apple ID credentials
- **Build processing failed**: Check app capabilities i entitlements

### Debug info lokacije:
- Developer Console: https://developer.apple.com/account/
- App Store Connect: https://appstoreconnect.apple.com/
- GitHub Secrets: https://github.com/bojanbc83/gavra_android/settings/secrets/actions
