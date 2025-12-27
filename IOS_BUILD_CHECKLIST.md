# iOS Build na GitHub Actions - Checklist i Status

**Poslednje ažuriranje:** 27. decembar 2025.

---

## 🎯 TRENUTNI STATUS: SPREMNO ZA iOS FOLDER

Sve pripreme su završene. Sledeći korak je kreiranje iOS foldera i workflow-a.

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

### 5. GitHub Secrets ✅
| Secret Name | Status | Vrednost |
|-------------|--------|----------|
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ | `d8b50e72-6330-401d-9aaf-4ead356495cb` |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | ✅ | `Q95YKW2L9S` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ | (sadržaj .p8 fajla) |
| `CERTIFICATE_PRIVATE_KEY` | ✅ | (sadržaj ios_cert_key) |
| `APP_STORE_APPLE_ID` | ⚠️ PROVERI | `6749899354` |

---

## ❌ ŠTA JOŠ TREBA

### 1. iOS Folder ❌
- **Status:** NE POSTOJI
- **Akcija:** Pokrenuti `flutter create .` sa Bundle ID `com.gavra013.gavraAndroid`

### 2. iOS Workflow ❌
- **Status:** NE POSTOJI
- **Akcija:** Kreirati `ios-release.yml`

### 3. Provera GitHub Secret ⚠️
- **APP_STORE_APPLE_ID** - možda fali, treba proveriti
- Vrednost: `6749899354`

---

## 🚀 SLEDEĆI KORACI (po redosledu)

### Korak 1: Proveri APP_STORE_APPLE_ID secret
Idi na: https://github.com/bojanbc83/gavra_android/settings/secrets/actions
- Ako NE postoji, dodaj: `APP_STORE_APPLE_ID` = `6749899354`

### Korak 2: Kreiraj iOS folder
```bash
cd c:\Users\Bojan\gavra_android
flutter create . --org com.gavra013 --project-name gavraAndroid
```
**NAPOMENA:** Ovo će kreirati iOS folder sa Bundle ID `com.gavra013.gavraAndroid`

### Korak 3: Kreiraj iOS workflow
AI će kreirati `ios-release.yml` workflow fajl

### Korak 4: Commit i push
```bash
git add .
git commit -m "feat: dodaj iOS podršku"
git push origin main
```

### Korak 5: Test - pokreni workflow ručno
Idi na GitHub Actions i pokreni `ios-release.yml` ručno

---

## 📊 GitHub Actions Minute - Podsećanje

| Plan | macOS minute/mesec | iOS buildova (~20min/build) |
|------|-------------------|----------------------------|
| **Free** | 200 | ~10 buildova |
| Pro | 300 | ~15 buildova |

---

## 🔧 Tehničke napomene

### Bundle ID razlika
| Platform | Bundle/Package ID |
|----------|-------------------|
| Android | `com.gavra013.gavra_android` (sa underscore) |
| iOS | `com.gavra013.gavraAndroid` (camelCase) |

**Ovo je normalno** - Apple ne dozvoljava underscore u Bundle ID.

### TestFlight distribucija
- **Internal Testing:** max 100 testera (bez review-a)
- **External Testing:** max 10,000 testera (zahteva Apple review 1-2 dana)
- Za ~154 korisnika: koristiti **External Testing**

---

## 📚 Korisni linkovi

- [GitHub Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Codemagic CLI Tools](https://github.com/codemagic-ci-cd/cli-tools)
- [Codemagic + GitHub Actions vodič](https://blog.codemagic.io/deploy-your-app-to-app-store-with-codemagic-cli-tools-and-github-actions/)


