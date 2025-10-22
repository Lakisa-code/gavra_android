# 🎯 Google Play Store Publication Guide

## Phase 1: Google Play Console Setup

### 1.1 Create Developer Account
- Go to: https://play.google.com/console
- Sign in with: `gavriconi19@gmail.com`
- Pay registration fee: **$25 USD** (one-time)
- Complete identity verification

### 1.2 Account Verification
- Phone number verification
- Identity document upload
- Business information (if applicable)

## Phase 2: App Preparation

### 2.1 Privacy Policy Hosting
You need to host `privacy-policy.md` publicly. Options:
1. **GitHub Pages** (Free):
   - Enable GitHub Pages in repo settings
   - URL will be: `https://bojanbc83.github.io/gavra_android/privacy-policy.html`

2. **Google Sites** (Free):
   - Create simple site with privacy policy content

3. **Your website** (if you have one)

### 2.2 App Store Assets
Create these assets:

#### App Icon
- **Size:** 512 x 512 pixels
- **Format:** PNG (no transparency)
- **Content:** Your app logo/brand

#### Screenshots (Required)
- **Phone screenshots:** Minimum 2, up to 8
- **Tablet screenshots:** Optional but recommended
- **Sizes:** Various (Play Console will specify)

#### Store Listing Content
- **App title:** "Gavra 013 - Taxi Organization"
- **Short description:** 80 characters max
- **Full description:** Up to 4000 characters
- **Category:** Transportation or Travel & Local

## Phase 3: Build Process

### 3.1 Using GitHub Actions (Recommended)
1. Follow instructions in `GITHUB_BUILD_SETUP.md`
2. Set up keystore secret
3. Trigger workflow
4. Download `.aab` file from artifacts

### 3.2 Local Build (Alternative)
```powershell
flutter build appbundle --release
```
File location: `build\app\outputs\bundle\release\app-release.aab`

## Phase 4: Play Console Submission

### 4.1 Create New App
1. Go to Play Console
2. Click "Create app"
3. Fill in basic details:
   - App name: "Gavra 013"
   - Default language: Serbian (or English)
   - App or game: App
   - Free or paid: Free (or paid)

### 4.2 Upload App Bundle
1. Go to **Production** → **Releases**
2. Click **Create new release**
3. Upload your `.aab` file
4. Add release notes

### 4.3 Complete Store Listing
1. **Main store listing:**
   - Upload app icon
   - Add screenshots
   - Write descriptions
   - Set category

2. **Privacy Policy:**
   - Add your privacy policy URL
   - Complete data safety form

### 4.4 Background Location Declaration
⚠️ **CRITICAL STEP** - Since your app uses background location:

1. Go to **Policy** → **App content**
2. Find **Location** section
3. Declare background location usage:
   - ✅ "This app collects location data"
   - ✅ "This app collects location in the background"
   - **Purpose:** Transportation/ride-sharing
   - **Data handling:** Explain GPS tracking for vehicle coordination

4. **Sensitive permissions review:**
   - Google will review your background location usage
   - Provide detailed explanation of why you need it
   - May require additional documentation

## Phase 5: Review & Publication

### 5.1 Testing (Recommended)
1. **Internal testing:** Upload and test with small group
2. **Closed testing:** Beta testing with larger group
3. **Open testing:** Public beta (optional)

### 5.2 Production Release
1. Complete all required sections (green checkmarks)
2. Click **Review release**
3. Submit for review

### 5.3 Review Process
- **Timeline:** 1-3 days (sometimes longer for sensitive permissions)
- **Background location apps:** May take 7+ days for additional review
- **Possible outcomes:** Approved, Rejected (with feedback), or Needs more info

## Phase 6: Post-Publication

### 6.1 Monitor Performance
- Check crash reports
- Monitor user reviews
- Track download statistics

### 6.2 Updates
- Use same GitHub Actions workflow
- Increment version number in `pubspec.yaml`
- Upload new `.aab` files for updates

## 🚨 Common Issues & Solutions

### Background Location Rejection
If rejected for background location:
1. Provide more detailed explanation
2. Create video demonstration
3. Submit policy compliance form
4. Consider removing background location if not essential

### Build Failures
1. Check GitHub Actions logs
2. Verify keystore secrets are set
3. Ensure all dependencies are compatible

### Signing Issues
1. Verify keystore file integrity
2. Check passwords in `key.properties`
3. Ensure keystore is properly encoded in GitHub secrets

## 📞 Need Help?
- Google Play Console Help: https://support.google.com/googleplay/android-developer
- Flutter Build Issues: https://docs.flutter.dev/deployment/android
- GitHub Actions: Check workflow logs for specific errors