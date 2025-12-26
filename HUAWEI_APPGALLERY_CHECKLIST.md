# Huawei AppGallery Deploy - Checklist i Status

**Poslednje ažuriranje:** 26. decembar 2025.

---

## 🎉 STATUS: SUBMITTED FOR REVIEW!

Aplikacija je uspešno upload-ovana na Huawei AppGallery i čeka odobrenje (1-5 radnih dana).

---

## 🎯 CILJ

Automatski deploy APK na Huawei AppGallery putem GitHub Actions nakon kreiranja taga `v*`.

---

## 📊 TRENUTNI STATUS

| Stavka | Status |
|--------|--------|
| GitHub Actions Android build | ✅ Radi |
| Signed APK kreiranje | ✅ Radi |
| GitHub Release kreiranje | ✅ Radi |
| Google Play deploy | ✅ Radi (na tag `v*`) |
| AppGallery Connect pristup | ✅ **AKTIVAN** |
| API Client kreiran | ✅ **KREIRAN** |
| GitHub Secrets dodati | ✅ **DODATI** |
| Workflow ažuriran | ✅ **HUAWEI DODATO** |
| Prvi ručni upload na AppGallery | ✅ **ZAVRŠENO** (26.12.2025) |
| Huawei Review | ⏳ **ČEKA SE** (1-5 dana) |
| agconnect-services.json | ✅ Postoji |
| Privacy Policy URL | ✅ `https://bojanbc83.github.io/gavra_android/privacy-policy.html` |

---

## 🔧 OPCIJE ZA DEPLOY

### Opcija A: Custom Script sa Huawei Publishing API (PREPORUČENO)
- ✅ Direktna integracija sa Huawei API
- ✅ Potpuna kontrola nad procesom
- ✅ Već imaš MCP server kao referencu (`huawei-appgallery-mcp/`)
- ⚠️ Zahteva pisanje shell/curl komandi

### Opcija B: Huawei AppGallery Gradle Plugin
- ✅ Integrisano u Gradle build
- ⚠️ Komplikovanije podešavanje
- ⚠️ Manje fleksibilno

**PREPORUKA:** Opcija A - Custom script je jednostavnija i daje više kontrole.

---

## ✅ Checklist - Svi koraci ZAVRŠENI

### 1. AppGallery Connect - Pristup
- [x] ✅ AKTIVAN

### 2. Aplikacija registrovana
- [x] ✅ Package: `com.gavra013.gavra_android`
- [x] ✅ App ID: `116046535`

### 3. API Client
- [x] ✅ Client ID: `1825559368939142080`

### 4. GitHub Secrets
- [x] ✅ `AGC_CLIENT_ID`
- [x] ✅ `AGC_CLIENT_SECRET`
- [x] ✅ `AGC_APP_ID`

### 5. Prvi ručni upload
- [x] ✅ **ZAVRŠENO 26.12.2025**
- [x] ✅ App ikona uploadovana
- [x] ✅ 6 screenshot-ova uploadovano
- [x] ✅ Opis aplikacije popunjen
- [x] ✅ Kategorija: Transport & tickets
- [x] ✅ Privacy policy: GitHub Pages
- [x] ✅ Age rating: 3+
- [x] ✅ GPS location data declared
- [x] ✅ Integration check: ALL PASSED

### 6. GitHub Workflow
- [x] ✅ Huawei upload dodat u `apk-release.yml`
- [x] ✅ Trigger: tag `v*`

---

## 🚀 Kako radi automatski deploy

```
Kreiraj tag v6.0.1
       ↓
   GitHub Actions
       ↓
   Build + Sign APK
       ↓
  ┌────┴────┐
  ↓         ↓
Google    Huawei
Play      AppGallery
```

**Jedan tag = Deploy na oba store-a!**

---

## 📝 Poznate informacije

```
Package Name: com.gavra013.gavra_android
App Name: Gavra 013
App ID: 116046535
Client ID: 1825559368939142080
GitHub Repo: bojanbc83/gavra_android
Workflow: .github/workflows/apk-release.yml
Privacy Policy: https://bojanbc83.github.io/gavra_android/privacy-policy.html
```

---

## 🎯 Sledeći koraci

1. ✅ ~~Huawei Developer nalog~~ AKTIVAN
2. ✅ ~~Registracija aplikacije~~ App ID: 116046535
3. ✅ ~~API Client kreiran~~ DONE
4. ✅ ~~GitHub Secrets dodati~~ DONE
5. ✅ ~~Prvi ručni upload~~ SUBMITTED 26.12.2025
6. ⏳ **Čekanje Huawei review-a** (1-5 radnih dana)
7. ❌ Test automatskog deploya (nakon odobrenja)

---

## 📚 Korisni linkovi

- [AppGallery Connect Console](https://developer.huawei.com/consumer/en/service/josp/agc/index.html)
- [GitHub Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)
- [Privacy Policy](https://bojanbc83.github.io/gavra_android/privacy-policy.html)

---

*Ažurirano: 26. decembar 2025.*
