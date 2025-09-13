# 🚀 Gavra Android - Automatski Build na GitHub

Ovaj repository koristi GitHub Actions za automatsko kreiranje APK fajlova.

## 📱 Build Process

### Automatski Build Triggers:
- ✅ Push na `main` branch
- ✅ Push na `develop` branch  
- ✅ Pull Request na `main`
- ✅ Manual trigger (workflow_dispatch)

### 🎯 Build Outputs:

#### 1. **Standardni APKs:**
- `gavra-android-debug.apk` - Debug verzija za testiranje
- `gavra-android-release.apk` - Production verzija

#### 2. **Split APKs (samo za main branch):**
- `gavra-android-arm64-v8a.apk` - Za moderne Android uređaje (64-bit ARM)
- `gavra-android-armeabi-v7a.apk` - Za starije Android uređaje (32-bit ARM)  
- `gavra-android-x86_64.apk` - Za emulatoare i x86 uređaje

## 🔧 Kako preuzeti APK:

### Opcija 1: GitHub Releases (Preporučeno)
1. Idi na [Releases](../../releases)
2. Klikni na najnoviji release
3. Preuzmi `gavra-android-release.apk`

### Opcija 2: GitHub Actions Artifacts
1. Idi na [Actions](../../actions)
2. Klikni na najnoviji successful build
3. Preuzmi `gavra-android-apk` artifact

## 🛠️ Build Environment:

- **Flutter:** 3.24.3 (stable)
- **Java:** JDK 17 (Temurin)
- **OS:** Ubuntu Latest
- **Maps:** OpenStreetMap (100% besplatno)

## 🔒 Bezbednost:

- ✅ Svi Google Maps API ključevi uklonjeni
- ✅ Nema hardcoded secrets
- ✅ Build u clean environment-u

## 📊 Build Status:

![Build Status](../../actions/workflows/build-android.yml/badge.svg)

---

*Automatski generirano od strane GitHub Actions* 🤖