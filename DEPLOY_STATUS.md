# 📱 Deploy Status - Gavra 013

**Poslednje ažuriranje:** 28. decembar 2025.

---

## 🎯 TRENUTNI STATUS

| Platforma | Status | Javno? | Link za proveru |
|-----------|--------|--------|-----------------|
| **Google Play** | ⏳ Closed Testing (Beta) | ❌ Ne | [Play Console](https://play.google.com/console) |
| **Huawei AppGallery** | ⏳ In Review | ❌ Ne | [AppGallery Connect](https://developer.huawei.com/consumer/en/service/josp/agc/index.html) |
| **iOS App Store** | ⏳ TestFlight | ❌ Ne | [App Store Connect](https://appstoreconnect.apple.com) |

---

## 📊 GDE SE DEPLOY-UJE

### Google Play
```
Workflow šalje na: BETA TRACK (Closed Testing)
                         ↓
              Samo pozvani testeri vide
                         ↓
         Za produkciju: Ručno promote u Play Console
```

### Huawei AppGallery
```
Workflow šalje na: REVIEW
                         ↓
              Huawei pregleda (1-5 dana)
                         ↓
         Kad odobre: Automatski PRODUCTION (javno)
```

### iOS
```
Workflow šalje na: TESTFLIGHT
                         ↓
              Samo pozvani testeri vide
                         ↓
         Za App Store: Ručno submit u App Store Connect
```

---

## 🔧 WORKFLOWS

| Workflow | Fajl | Trigger | Destinacija |
|----------|------|---------|-------------|
| **Release All** | `release-all-platforms.yml` | Tag `v*` | Sve 3 platforme |
| **APK Release** | `apk-release.yml` | Push main / Tag | GitHub + Google + Huawei |
| **Google Play** | `google-play-release.yml` | Ručno | Google Play (biraš track) |
| **Huawei** | `huawei-release.yml` | Ručno | Huawei AppGallery |
| **iOS** | `ios-release.yml` | Ručno | TestFlight |

---

## 🚀 KAKO NAPRAVITI NOVU VERZIJU

### Opcija 1: Sve platforme odjednom (PREPORUČENO)
```bash
# 1. Promeni verziju u pubspec.yaml
# 2. Commit i push
git add .
git commit -m "v6.1.0"
git push

# 3. Kreiraj tag
git tag v6.1.0
git push origin v6.1.0

# → Automatski: Google (beta) + Huawei + iOS TestFlight
```

### Opcija 2: Pojedinačno (za testiranje)
```
GitHub → Actions → Izaberi workflow → Run workflow
```

---

## 📋 CHECKLIST ZA PRODUKCIJU

### Google Play → Production
- [ ] Testiraj na Closed Testing
- [ ] Play Console → Release → Production → Create release
- [ ] Promote from Beta
- [ ] Submit for review

### Huawei → Production
- [x] ~~Upload~~ (automatski)
- [ ] Čekaj review (1-5 dana)
- [ ] Automatski production kad odobre

### iOS → App Store
- [ ] Testiraj na TestFlight
- [ ] App Store Connect → App Store → Submit for Review
- [ ] Čekaj Apple review (24-48h)

---

## 🔐 CREDENTIALS (GitHub Secrets)

### Google Play
| Secret | Opis |
|--------|------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Service account za upload |

### Huawei
| Secret | Opis |
|--------|------|
| `AGC_CLIENT_ID` | `1850740994484473152` (Team-level) |
| `AGC_CLIENT_SECRET` | API secret |
| `AGC_APP_ID` | `116046535` |

### iOS
| Secret | Opis |
|--------|------|
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | API key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 key content |
| `CERTIFICATE_PRIVATE_KEY` | Signing certificate |
| `APP_STORE_APPLE_ID` | App ID u App Store |

### Android Signing
| Secret | Opis |
|--------|------|
| `KEYSTORE_BASE64` | Release keystore |
| `KEY_ALIAS` | Key alias |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |

---

## 📱 APP INFO

| Platforma | Package/Bundle ID | App ID |
|-----------|-------------------|--------|
| **Android** | `com.gavra013.gavra_android` | - |
| **Huawei** | `com.gavra013.gavra_android` | `116046535` |
| **iOS** | `com.gavra013.gavra013ios` | `6749899354` |

---

## ⏱️ REVIEW VREMENA

| Platforma | Tipično vreme |
|-----------|---------------|
| Google Play | 1-3 dana (prvi put do 7) |
| Huawei | 1-5 radnih dana |
| Apple | 24-48 sati |

---

## 📝 NAPOMENE

1. **Google & iOS** su trenutno na zatvorenom testiranju - korisnici ih NE vide
2. **Huawei** kad odobri review, automatski postaje javno
3. Za prelazak na production na Google/iOS, treba ručna akcija u konzoli
4. Novi `release-all-platforms.yml` radi paralelni build (brže)

---

*Ažurirano: 28. decembar 2025.*
