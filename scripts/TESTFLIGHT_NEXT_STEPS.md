# Next Steps for TestFlight Deployment

## 1. Add GitHub Secrets

Go to: https://github.com/bojanbc83/gavra_android/settings/secrets/actions

Add these secrets:

### Certificate Base64
Name: `IOS_CERTIFICATE_BASE64`
Value: Copy entire content from `ios_certificates/certificate_base64.txt`

### Certificate Password
Name: `IOS_CERTIFICATE_PASSWORD` 
Value: `GavraApp2025`

### Provisioning Profile Base64
Name: `IOS_PROVISIONING_PROFILE_BASE64`
Value: Copy entire content from `ios_certificates/provisioning_base64.txt`

### Apple Developer Account Info
Name: `APPLE_ID`
Value: Your Apple ID email address

Name: `APPLE_PASSWORD`
Value: App-specific password (generate at appleid.apple.com)

Name: `APPLE_TEAM_ID`
Value: `6CY9Q44KMQ`

## 2. Create App in App Store Connect

1. Go to: https://appstoreconnect.apple.com/apps
2. Click "+" to create new app
3. Fill in:
   - Platform: iOS
   - Name: Gavra Android
   - Primary Language: Serbian
   - Bundle ID: com.gavra013.gavra-android (select from dropdown)
   - SKU: gavra-android-2025

## 3. First TestFlight Deployment

After adding all secrets, run:
```bash
gh workflow run deploy-ios-testflight.yml
```

## 4. Monitor Deployment

Check workflow status:
```bash
gh run list --workflow=deploy-ios-testflight.yml
```

## Files Created
- ✅ ios_certificates/certificate_base64.txt
- ✅ ios_certificates/provisioning_base64.txt
- ✅ All certificate infrastructure ready

## Ready for Deployment! 🚀
