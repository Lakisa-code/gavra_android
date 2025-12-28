# iOS Build na GitHub Actions - Checklist i Status

**Poslednje ažuriranje:** 28. decembar 2025.

---

## ⚠️ VAŽNA NAPOMENA

**Razvoj se vrši na WINDOWS računaru** - nema Mac-a!
- iOS folder se kreira sa `flutter create .`
- Podfile se mora ručno kreirati (ne generiše se na Windows-u)
- Build se vrši na GitHub Actions macOS runner-u

---

## 🎯 TRENUTNI STATUS: BUILD U TOKU

iOS folder i workflow su kreirani. Testira se build na GitHub Actions.

---

## ✅ Checklist - Kompletiran

### 1. Apple Developer Account ✅
- **Status:** AKTIVAN
- **Ime:** Bojan Gavrilovic
- **Apple Team ID:** `6CY9Q44KMQ`
- **Program:** Apple Developer Program (Individual)
- **Renewal date:** July 24, 2026

### 2. App Store Connect App ✅
- **App Name:** Gavra Bus (treba promeniti na Gavra 013)
- **App ID:** `6749899354`
- **Bundle ID (iOS):** `com.gavra013.gavraAndroid`
- **SKU:** gavra-bus-001
- **iOS verzija:** 1.0 (Prepare for Submission)

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
| 28.12.2025 | #3 | ⏳ | U toku... |

---

## 🚀 SLEDEĆI KORACI

1. ⏳ Sačekaj rezultat build-a #3
2. Ako uspe → TestFlight processing (~10-30 min)
3. Ako ne uspe → debug grešku

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
| iOS | `com.gavra013.gavraAndroid` (camelCase) |

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


