# iOS Build na GitHub Actions - Checklist i Status

**Poslednje ažuriranje:** 11. decembar 2025. (18:45)

---

## 🚨 TRENUTNI PRIORITET - ANDROID TESTIRANJE

**CILJ:** GitHub Actions build sa verzijama za 2 vozača koji testiraju aplikaciju.

| Stavka | Status |
|--------|--------|
| GitHub Actions Android build | ✅ Već postoji (`android-release.yml`) |
| Verzionisanje (versionCode/versionName) | ⏳ Treba proveriti/podesiti |
| Distribucija APK-a za 2 vozača | 📱 **QR Code pristup** |
| Testiranje bagova | ⏳ U toku |
| Auto-update servis | ✅ **UKLONJEN** (nepotreban) |

### 📱 DISTRIBUCIJA PUTEM QR KODA:
1. Build APK (lokalno ili GitHub Actions)
2. Upload na GitHub Releases
3. Generiši QR kod (qr-code-generator.com)
4. Pošalji QR vozačima - skeniraju i instaliraju
5. Za update: novi Release → novi QR

### ⛔ ŠTA NE RADIMO SADA:
- ❌ **NE** objavljujemo na Play Store
- ❌ **NE** objavljujemo na App Store
- ❌ **NE** kreiramo iOS folder (dok Android nije stabilan)
- ❌ **NE** radimo TestFlight upload
- ❌ ~~Auto-update servis~~ **UKLONJEN** - nepotreban za test fazu

### ✅ ŠTA RADIMO SADA:
- ✅ GitHub Actions Android build
- ✅ APK sa brojevima verzija (versionCode se automatski inkrementira)
- ✅ **QR kod distribucija** - vozači skeniraju i preuzimaju APK
- ✅ Testiranje i prijava bagova

---

## ⚠️ VAŽNA NAPOMENA: Bundle ID

**Apple NE DOZVOLJAVA underscore (`_`) u Bundle ID!**

Dozvoljeni karakteri: A-Z, a-z, 0-9, crtica (`-`), tačka (`.`)

| Bundle ID | Platform | Status |
|-----------|----------|--------|
| `com.gavra013.gavra_android` | Android (package name) | ✅ OK za Android |
| `com.gavra013.gavraAndroid` | iOS (App Store Connect) | ✅ OK za iOS |

**Zaključak:** Android i iOS mogu imati različite identifikatore - to je normalno!
Kada se kreira iOS folder, koristićemo `com.gavra013.gavraAndroid`.

---

## 🔄 UPOREDNA ANALIZA: Xcode Cloud vs GitHub Actions

### Xcode Cloud (Apple-ov servis)

| Aspekt | Detalji |
|--------|---------|
| **Besplatno** | 25 compute sati/mesec (uključeno u Developer Program) |
| **Cena dodatnih sati** | $49.99/100h, $99.99/250h, $399.99/1000h |
| **Integracija** | Direktno u App Store Connect i Xcode |
| **TestFlight** | Automatski upload na TestFlight |
| **Code signing** | Apple automatski upravlja certifikatima! ✅ |
| **Flutter podrška** | Zahteva custom post-clone script |
| **Problemi sa Flutter-om** | ČESTI! (vidi dole) ⚠️ |

#### ⚠️ POZNATI PROBLEMI sa Xcode Cloud + Flutter:
Bazirano na Stack Overflow pitanjima:
- "Flutter Xcode Cloud error There is no XCFramework found"
- "Xcode Cloud build keeps failing despite local success"
- "Unable to find included file 'Generated.xcconfig'"
- "Flutter Project Not Building in Xcode Cloud"

**ZAKLJUČAK Xcode Cloud:** Ima problema sa Flutter projektima, zahteva dosta debugovanja.

---

### GitHub Actions + Codemagic CLI (preporučeno za vašu situaciju) ✅

| Aspekt | Detalji |
|--------|---------|
| **Besplatno** | 200 macOS minuta/mesec (~8-13 buildova) |
| **Cena dodatnih** | Uključeno u Pro/Team planove |
| **Flutter podrška** | Odlična - Codemagic je prvobitno pravljen za Flutter! |
| **Code signing** | Automatsko kreiranje cert/profile kroz CLI |
| **TestFlight upload** | Da, kroz `app-store-connect publish` |
| **Problemi** | Manje nego Xcode Cloud za Flutter |
| **Potreban Mac** | NE! CLI generiše sve na runner-u |

---

## 🏆 PREPORUKA ZA VAŠU SITUACIJU

### **GitHub Actions + Codemagic CLI Tools** je BOLJI izbor jer:

1. ✅ **Ne treba vam Mac** - Codemagic CLI automatski kreira certifikate
2. ✅ **Bolja Flutter podrška** - Codemagic je originalno pravljen za Flutter
3. ✅ **Manje problema** - Xcode Cloud ima poznate probleme sa Flutter projektima
4. ✅ **Već imate Android workflow** - Lakše je dodati iOS u isti sistem
5. ✅ **Besplatno 200 min/mesec** - Dovoljno za 8-13 buildova

### Xcode Cloud bi bio bolji ako:
- Radite native iOS (Swift/Objective-C) projekat
- Želite sve unutar Apple ekosistema
- Ne želite da podešavate GitHub Secrets

---

## 🎉 MOŽE BEZ MAC-a!

**Codemagic CLI Tools** mogu **AUTOMATSKI** kreirati iOS certifikate direktno na GitHub Actions macOS runner-u!

To znači:
- ❌ **NE TREBA** vam Mac računar
- ❌ **NE TREBA** ručno praviti certifikate
- ✅ Codemagic CLI automatski generiše certificate i provisioning profile
- ✅ Koristi se samo App Store Connect API Key

---

## 📊 GitHub Actions Besplatne Minute

| Plan | Linux minute | macOS minute | Napomena |
|------|-------------|--------------|----------|
| **Free** | 2,000/mesec | **200/mesec** | macOS troši 10x više |
| Pro | 3,000/mesec | 300/mesec | |
| Team | 3,000/mesec | 300/mesec | |
| Enterprise | 50,000/mesec | 5,000/mesec | |

**⚠️ VAŽNO:** Jedan iOS build tipično traje **15-25 minuta** na macOS runner-u.
Sa 200 besplatnih minuta mesečno, imate otprilike **8-13 iOS buildova mesečno**.

---

## ✅ Checklist - Vaš trenutni status

### 1. iOS Folder u Projektu
- [ ] **STATUS:** ❌ NE POSTOJI
- **Potrebna akcija:** Pokrenuti `flutter create .` 
- **Pitanje:** Da li da kreiram iOS folder sada?

### 2. Apple Developer Account ✅ POTVRĐENO
- [x] **STATUS:** ✅ AKTIVAN
- **Ime:** Bojan Gavrilovic
- **Apple Team ID:** `6CY9Q44KMQ`
- **Program:** Apple Developer Program (Individual)
- **Renewal date:** July 24, 2026

### 3. App registrovan na App Store Connect ✅ POTVRĐENO
- [x] **STATUS:** ✅ REGISTROVAN
- **App Name:** ~~Gavra Bus~~ → **Gavra 013** (promenjeno)
- **App ID:** 6749899354
- **iOS verzija:** 1.0 (Prepare for Submission)
- **Bundle ID:** ✅ `com.gavra013.gavraAndroid`
- **SKU:** gavra-bus-001

### 4. App Store Connect API Key ✅ KREIRAN
- [x] **STATUS:** ✅ KREIRAN
- **Ime ključa:** `GitHub Actions iOS`
- **Access:** App Manager
- **Issuer ID:** `d8b50e72-6330-401d-9aaf-4ead356495cb`
- **Key ID:** `Q95YKW2L9S`
- **.p8 fajl:** ✅ PREUZET (AuthKey_Q95YKW2L9S.p8)
- **Napomena:** Postoji i stariji ključ "Codemagic iOS Build" (F4P38UR78G) ali nema .p8 fajl

### 5. Certificate Private Key ✅ GENERISAN
- [x] **STATUS:** ✅ GENERISAN
- **Lokacija:** `C:\Users\Bojan\Downloads\ios_cert_key`
- **Public key:** `C:\Users\Bojan\Downloads\ios_cert_key.pub` (nije potreban)
- **Napomena:** Sadržaj private key-a ide u GitHub Secret `CERTIFICATE_PRIVATE_KEY`

---

## 🔐 GitHub Secrets - AUTOMATSKI PRISTUP

Za **automatsko** kreiranje certifikata, potrebni su ovi secrets:

| Secret Name | Opis | Status | Vrednost |
|-------------|------|--------|----------|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID sa API stranice | ✅ DODATO | `d8b50e72-6330-401d-9aaf-4ead356495cb` |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID (10 karaktera) | ✅ DODATO | `Q95YKW2L9S` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Sadržaj .p8 fajla | ✅ DODATO | (AuthKey_Q95YKW2L9S.p8) |
| `CERTIFICATE_PRIVATE_KEY` | RSA private key | ✅ DODATO | (ios_cert_key) |

**GitHub Secrets URL:** https://github.com/bojanbc83/gavra_android/settings/secrets/actions

---

## 📝 Poznate informacije

```
Apple Developer Account: Bojan Gavrilovic
Team ID: 6CY9Q44KMQ
App Name: Gavra 013 (prethodno: Gavra Bus)
App Store Connect ID: 6749899354
iOS verzija: 1.0 (Prepare for Submission)
Bundle ID (iOS): com.gavra013.gavraAndroid
Bundle ID (Android): com.gavra013.gavra_android
SKU: gavra-bus-001
API Key Name: GitHub Actions iOS
API Key ID: Q95YKW2L9S
API Issuer ID: d8b50e72-6330-401d-9aaf-4ead356495cb
.p8 lokacija: C:\Users\Bojan\Desktop\GAVRA013\AuthKey_Q95YKW2L9S.p8
Cert key lokacija: C:\Users\Bojan\Downloads\ios_cert_key
```

---

## 🚀 Sledeći koraci

1. ~~Kreirati App Store Connect API Key (.p8 fajl)~~ ✅ ZAVRŠENO
2. ~~Generisati certificate key (ssh-keygen)~~ ✅ ZAVRŠENO
3. ~~Dodati GitHub Secrets~~ ✅ ZAVRŠENO (4 secreta)
4. ~~Promeniti ime aplikacije u App Store Connect~~ ✅ ZAVRŠENO (Gavra 013)
5. **SLEDEĆE:** Kreirati iOS folder (`flutter create .` - koristiti Bundle ID `com.gavra013.gavraAndroid`)
6. **SLEDEĆE:** Kreirati `ios-release.yml` workflow
7. **Test:** Push i provera builda

---

## 📚 Korisni linkovi

- [App Store Connect - API Keys](https://appstoreconnect.apple.com/access/integrations/api)
- [Codemagic CLI Tools](https://github.com/codemagic-ci-cd/cli-tools)
- [Codemagic CLI + GitHub Actions vodič](https://blog.codemagic.io/deploy-your-app-to-app-store-with-codemagic-cli-tools-and-github-actions/)
- [Flutter iOS CD dokumentacija](https://docs.flutter.dev/deployment/cd)
- [GitHub Actions Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)


