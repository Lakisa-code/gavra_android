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
- ✅ Screenshots: 4 slike uploadovane na Google Play i Huawei
- ✅ GitHub Actions: Unified deployment workflow konfigurisan

## 🚀 PRODUCTION DEPLOYMENT - GitHub Actions

**PREPORUKA: Koristi GitHub Actions - NE trebam lokalne skripte!**

### Dostupni Workflows:
1. **unified-deploy-all.yml** ⭐ PREPORUČENO
   - Deploy na sve 3 platforme paralelno
   - Automatski bump verzije (opciono)
   - Dry-run podrška
   - Fleksibilna kontrola koja platforma se pokreće

2. ios-production.yml - Samo iOS
3. huawei-production.yml - Samo Huawei
4. google-closed-testing.yml - Google Play

### Kako Pokrenuti za 6.0.50+420:

**OPCIJA 1: Bez bump-a (6.0.50+420 kako je)**
```
1. Idi na: https://github.com/kadpitamkurac-hash/gavra_android/actions
2. Workflow: "UNIFIED DEPLOY ALL"
3. "Run workflow" sa:
   - Auto-bump version: FALSE
   - Release notes: "Version 6.0.50+420 Production Release"
   - All platforms: true
   - Dry run: false
4. Klikni "Run workflow"
```

**OPCIJA 2: Sa bump-om (6.0.50+420 → 6.0.51+421)**
```
1. Isti proces
2. Ali: Auto-bump version: TRUE
3. Rezultat: Verzija 6.0.51+421 će biti deployovana
```

**OPCIJA 3: Dry Run (samo test, bez upload-a)**
```
- Dry run: true
- Sve će biti buildirano ali NE uploadovano
```

### Potrebni GitHub Secrets:
- ✅ GOOGLE_SERVICE_ACCOUNT_JSON
- ✅ HUAWEI_CLIENT_ID, HUAWEI_CLIENT_SECRET, HUAWEI_APP_ID
- ✅ APP_STORE_CONNECT_ISSUER_ID, KEY_IDENTIFIER, PRIVATE_KEY
- ✅ CERTIFICATE_PRIVATE_KEY

### Vrijeme Build-a i Deployment-a:
- Build: ~20-30 minuta (paralelno)
- Upload: ~1-4 sata
- Review: Google 1-4h, Huawei 2-6h, iOS 24-48h

**Dostupne slike:**
1. Screenshot_20260127_050102_com.gbox.android.jp.jpg (0.91 MB)
2. Screenshot_20260127_050113_com.gbox.android.jp.jpg (0.96 MB)
3. Screenshot_20260127_050120_com.gbox.android.jp.jpg (1.20 MB)
4. Screenshot_20260127_050132_com.gbox.android.jp.jpg (0.88 MB)

