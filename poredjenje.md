# Poređenje - Verzije i Buildovi

## 1️⃣ iOS App Store

**Verzija:** 6.0.50  
**Build:** 420  
**Bundle ID:** com.gavra013.gavra013ios  

---

## 2️⃣ Huawei AppGallery

**Verzija:** 6.0.50  
**Build:** 420  
**App ID:** 116046535  

---

## 3️⃣ Google Play

**Verzija:** 6.0.50+420  
**Build:** 420  
**Track:** Alpha (Internal Testing)  
**Screenshots:** 4 slike

---

## 📸 Upload Slika - Status

**Google Play:** ✅ DONE - 4 nove slike uploadovane i committed

**Huawei:** ✅ DONE - 4 nove slike uploadovane via OAuth2 API

**iOS:** ✅ Screenshots ready for upload (credentials configured)

## 🔄 Verzije Ažurirane na 6.0.50+420

**Completed Actions:**
- ✅ pubspec.yaml: version: 6.0.50+420 (iOS, Android, Huawei)
- ✅ Android (gradle): Koristi Flutter plugin - automatski preuzima iz pubspec.yaml
- ✅ iOS (Info.plist): Koristi $(FLUTTER_BUILD_NAME) i $(FLUTTER_BUILD_NUMBER) - automatski
- ✅ Huawei: Trebam novi build sa verzijom 6.0.50+420
- ⏳ Google Play: Update trenutnog edit-a sa novom verzijom
- ⏳ iOS: Build i submit sa novom verzijom 6.0.50+420

## 📱 Build Komande

```bash
# Flutter clean
flutter clean

# iOS Build
flutter build ios --release

# Android Build  
flutter build apk --release

# Huawei Build
flutter build apk --release

# Google Play Build
flutter build appbundle --release
```

Dostupne slike:
1. Screenshot_20260127_050102_com.gbox.android.jp.jpg (0.91 MB)
2. Screenshot_20260127_050113_com.gbox.android.jp.jpg (0.96 MB)
3. Screenshot_20260127_050120_com.gbox.android.jp.jpg (1.20 MB)
4. Screenshot_20260127_050132_com.gbox.android.jp.jpg (0.88 MB)

