# 🍎 TestFlight Deployment Guide

## 🚀 Automatski Upload na TestFlight

### Način 1: Automatski (Push na main)
```bash
git add .
git commit -m "Nova verzija"
git push
```
→ Automatski se pokreće TestFlight deployment

### Način 2: Ručno (GitHub Actions)
1. Idi na: https://github.com/bojanbc83/gavra_android/actions/workflows/deploy-ios-testflight.yml
2. Klikni **"Run workflow"** (zeleno dugme)
3. Unesi verziju (npr. 5.0.1)
4. Klikni **"Run workflow"**

## 📱 Posle Upload-a

### 1. App Store Connect
- Idi na: https://appstoreconnect.apple.com
- **My Apps** → **Gavra Android** → **TestFlight**
- Čekaj 5-10 min da se build obradi

### 2. Dodaj Testere
**Internal Testing:**
- Dodaj sebe i tim članove
- Mogu odmah da testiraju

**External Testing:**
- Kreira test grupu
- Dodaj eksterne testere  
- Apple review (1-3 dana)

### 3. TestFlight App
Testeri download-uju **TestFlight** app sa App Store i koriste invite link.

## 🔧 Workflow Status
- **Workflow file**: `.github/workflows/deploy-ios-testflight.yml`
- **Build target**: iOS 15.0+
- **Bundle ID**: com.gavra013.gavra-android
- **Signing**: Manual (Distribution Certificate)

## 📋 GitHub Secrets (već konfigurisano)
- `IOS_CERTIFICATE_BASE64`
- `IOS_PRIVATE_KEY_BASE64` 
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_PASSWORD`

## 🎯 Sve je spremo - samo pokreni workflow! 🚀
