# iOS Build na GitHub Actions - Checklist i Status

**Poslednje ažuriranje:** 28. decembar 2025. 09:49 AM

---

## ⚠️ VAŽNA NAPOMENA

**Razvoj se vrši na WINDOWS računaru** - nema Mac-a!
- iOS folder se kreira sa `flutter create .`
- Podfile se mora ručno kreirati (ne generiše se na Windows-u)
- Build se vrši na GitHub Actions macOS runner-u

---

## 🎯 TRENUTNI STATUS: ✅ SUBMITTED FOR APP STORE REVIEW

**iOS aplikacija je submitovana za App Store review!**

| Detalj | Vrednost |
|--------|----------|
| **App Name** | Gavra 013 |
| **Version** | 1.0 |
| **Build** | 6.0.3 (1) |
| **Status** | ⏳ Waiting for Review |
| **Date Submitted** | Dec 28, 2025 at 9:49 AM |
| **Submission ID** | dd3aca6d-cb49-4674-a196-6ee3ad1b0df0 |

**Očekivano vreme review-a:** 1-3 dana

---

## ✅ Checklist - Kompletiran

### 1. Apple Developer Account ✅
- **Status:** AKTIVAN
- **Ime:** Bojan Gavrilovic
- **Apple Team ID:** `6CY9Q44KMQ`
- **Program:** Apple Developer Program (Individual)
- **Renewal date:** July 24, 2026

### 2. App Store Connect App ✅
- **App Name:** Gavra 013
- **App ID:** `6757114361`
- **Bundle ID (iOS):** `com.gavra013.gavra013ios`
- **SKU:** gavra-bus-001
- **iOS verzija:** 1.0 (Waiting for Review)

### 3. App Store Connect API Key ✅
- **Key Name:** GitHub Actions iOS
- **Key ID:** `Q95YKW2L9S`
- **Issuer ID:** `d8b50e72-6330-401d-9aaf-4ead356495cb`
- **.p8 fajl:** Preuzet (AuthKey_Q95YKW2L9S.p8)

### 4. Certificate Private Key ✅
- **Status:** Generisan
- **Lokacija:** `C:\Users\Bojan\Downloads\ios_cert_key`

### 5. GitHub Secrets ✅ (SVI DODATI)
| Secret Name | Status |
|-------------|--------|
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | ✅ |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ |
| `CERTIFICATE_PRIVATE_KEY` | ✅ |
| `APP_STORE_APPLE_ID` | ✅ |

### 6. Apple Agreements ✅
- **Free Apps Agreement:** Active ✅
- **Paid Apps Agreement:** Pending (nije potrebno za besplatnu app)
- **DSA Compliance:** Completed ✅

### 7. iOS Folder ✅
- **Status:** KREIRAN (28. dec 2025.)
- **Komanda:** `flutter create . --org com.gavra013`
- **Bundle ID:** `com.gavra013.gavraAndroid`

### 8. iOS Podfile ✅
- **Status:** KREIRAN RUČNO (28. dec 2025.)
- **Lokacija:** `ios/Podfile`
- **Fix:** Dodat `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` za Firebase

### 9. iOS Workflow ✅
- **Status:** KREIRAN (28. dec 2025.)
- **Fajl:** `.github/workflows/ios-release.yml`
- **Trigger:** Ručni (workflow_dispatch)

---

## 🔄 BUILD ISTORIJA

| Datum | Build # | Status | Greška |
|-------|---------|--------|--------|
| 28.12.2025 | #1 | ❌ | Agreement missing (rešeno) |
| 28.12.2025 | #2 | ❌ | Firebase non-modular header (rešeno - dodat Podfile) |
| 28.12.2025 | #3+ | ✅ | **BUILD USPEŠAN - TestFlight** |

---

## 🎉 TRENUTNI STATUS: APP STORE - WAITING FOR REVIEW

**Verzija 6.0.0 je submitovana za App Store review!** (28. Dec 2025)

- **Review Type:** APP_STORE (puna distribucija)
- **Release Type:** AFTER_APPROVAL (automatski publish nakon odobrenja)
- **Status:** Waiting for Review
- **Očekivano vreme review-a:** 1-3 dana

### Prethodne verzije:
- TestFlight: ✅ Testiran i funkcionalan

---

## 📊 GitHub Actions Minute - Podsećanje

| Plan | macOS minute/mesec | iOS buildova (~20min/build) |
|------|-------------------|----------------------------|
| **Free** | 200 | ~10 buildova |
| Pro | 300 | ~15 buildova |

---

## 🔧 Tehničke napomene

### Razvoj na Windows-u
- **Nema Mac-a** - sve se radi remote na GitHub Actions
- **Podfile** se ne generiše automatski - mora ručno
- **Pod install** se vrši na macOS runner-u

### Bundle ID razlika
| Platform | Bundle/Package ID |
|----------|-------------------|
| Android | `com.gavra013.gavra_android` (sa underscore) |
| iOS | `com.gavra013.gavra013ios` |

### Workflow struktura
- **apk-release.yml:** Kombinovani workflow za Android + iOS
  - Android build: ~7 minuta (ubuntu runner)
  - iOS build: ~20 minuta (macos runner)
  - Upload na App Store Connect automatski

### TestFlight distribucija
- **Internal Testing:** max 100 testera (bez review-a)
- **External Testing:** max 10,000 testera (zahteva Apple review 1-2 dana)
- Za ~154 korisnika: koristiti **External Testing**

---

## 🐛 Poznati problemi i rešenja

### 1. Firebase non-modular header
**Greška:** `Include of non-modular header inside framework module`
**Rešenje:** Dodati u Podfile post_install:
```ruby
config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
```

### 2. Agreement missing
**Greška:** `A required agreement is missing or has expired`
**Rešenje:** Potpisati ugovore na App Store Connect → Business → Agreements

---

## 📚 Korisni linkovi

- [GitHub Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)
- [GitHub Actions](https://github.com/bojanbc83/gavra_android/actions)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [App Store Connect Agreements](https://appstoreconnect.apple.com/agreements/#/)
- [Codemagic CLI Tools](https://github.com/codemagic-ci-cd/cli-tools)


