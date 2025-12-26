# Google Play Store Deploy - Checklist i Status

**Poslednje ažuriranje:** 26. decembar 2025.

---

## 🎯 CILJ

Automatski deploy APK/AAB na Google Play Store putem GitHub Actions nakon svakog push-a na `main` branch ili kreiranja taga.

---

## 📊 TRENUTNI STATUS

| Stavka | Status |
|--------|--------|
| GitHub Actions Android build | ✅ Postoji (`apk-release.yml`) |
| Signed APK kreiranje | ✅ Radi |
| GitHub Release kreiranje | ✅ Radi |
| Google Play Console pristup | ✅ **AKTIVAN** |
| Google Cloud Project | ✅ **POSTOJI** (`gavra-notif-20250920162521`) |
| Android Publisher API | ✅ **OMOGUĆEN** |
| Service Account kreiran | ✅ **POSTOJI** (`gavra-play-store@...`) |
| JSON Key kreiran | ✅ **KREIRAN** (26.12.2025) |
| GitHub Secrets dodati | ✅ **DODATO** |
| Workflow ažuriran | ✅ **DODATO** (production track) |
| Aplikacija na Play Console | ✅ **POSTOJI** (Gavra013) |
| Prvi ručni upload | ✅ **URAĐEN** (1. nov 2025.) |
| Service Account povezan sa Play Console | ❌ **POTREBNO** |

---

## 🔧 PREPORUČENA GITHUB ACTION

**Action:** [`r0adkll/upload-google-play@v1`](https://github.com/r0adkll/upload-google-play)
- ⭐ 936 zvezdica
- 👥 Koristi 3,700+ projekata
- ✅ Aktivno održavan

### Podržane opcije:
| Parametar | Opis |
|-----------|------|
| `releaseFiles` | Putanja do APK/AAB fajla |
| `track` | `internal`, `alpha`, `beta`, `production` |
| `status` | `completed`, `inProgress`, `halted`, `draft` |
| `userFraction` | Procenat korisnika za staged rollout (0.0-1.0) |
| `whatsNewDirectory` | Folder sa changelog fajlovima |
| `mappingFile` | ProGuard mapping fajl |

---

## ✅ Checklist - Potrebni koraci

### 1. Google Play Console - Pristup
- [x] **STATUS:** ✅ AKTIVAN
- **URL:** https://play.google.com/console/
- **Nalog:** Aktivan Google Play Developer nalog
- **Cena:** $25 jednokratno (lifetime)

### 2. Aplikacija registrovana na Play Console
- [x] **STATUS:** ✅ POSTOJI I AKTIVNA
- **Package name:** `com.gavra013.gavra_android`
- **App Name:** Gavra013
- **Track:** Интерно тестирање (Internal) - već uploadovan APK 1. nov 2025.
- **Broj korisnika u sistemu:** ~150 (149 putnika + 5 vozača)
- **Preporučeni track za automatizaciju:** `alpha` (Zatvoreno testiranje) - do 100,000 testera

### 3. Google Cloud Service Account
- [x] **STATUS:** ✅ POSTOJI I AKTIVAN
- **Google Cloud Project:** `gavra-notif-20250920162521`
- **Project Name:** Gavra Android Notifications
- **Service Account Email:** `gavra-play-store@gavra-notif-20250920162521.iam.gserviceaccount.com`
- **Android Publisher API:** ✅ OMOGUĆEN
- **JSON Key:** ✅ KREIRAN (26.12.2025) - `play-store-key.json`

**Koraci (ZAVRŠENI):**
  1. ~~Ići na https://console.cloud.google.com/~~ ✅
  2. ~~Kreirati novi projekat ili koristiti postojeći~~ ✅ (`gavra-notif-20250920162521`)
  3. ~~Omogućiti **Google Play Android Developer API**~~ ✅
  4. ~~Kreirati Service Account~~ ✅ (`gavra-play-store@...`)
  5. ~~Kreirati JSON ključ~~ ✅ (`play-store-key.json`)

### 4. Dodati Service Account u Play Console
- [ ] **STATUS:** ❌ POTREBNO
- **Koraci:**
  1. Ići na https://play.google.com/console/
  2. Settings → API access (ili Users and permissions)
  3. Link postojeći Google Cloud projekat
  4. Kliknuti "Invite new user"
  5. Uneti **email adresu Service Account-a** (format: `ime@projekat.iam.gserviceaccount.com`)
  6. Dodeliti permisije:
     - ✅ **Release apps to testing tracks**
     - ✅ **Release to production, exclude devices, and use Play App Signing**
     - ✅ **Manage store presence**
  7. Za specifičnu aplikaciju: App permissions → dodati `com.gavra013.gavra_android`

### 5. GitHub Secrets
- [x] **STATUS:** ✅ DODATO

| Secret Name | Opis | Status |
|-------------|------|--------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Ceo sadržaj JSON ključa | ✅ Dodato 26.12.2025 |

**GitHub Secrets URL:** https://github.com/bojanbc83/gavra_android/settings/secrets/actions

### 6. Prvi ručni upload (OBAVEZNO!)
- [x] **STATUS:** ✅ URAĐENO (1. nov 2025.)
- **⚠️ VAŽNO:** Google Play API **NE MOŽE** kreirati novu aplikaciju!
- **Akcija:** ~~Uploadovati prvi APK/AAB ručno kroz Play Console~~ ✅
- **Track:** Internal testing - APK već uploadovan

---

## 🔐 GitHub Secrets - Potrebni

| Secret Name | Opis | Odakle |
|-------------|------|--------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON ključ service account-a | Google Cloud Console |

**Postojeći secrets (za build):**
| Secret Name | Status |
|-------------|--------|
| `KEYSTORE_BASE64` | ✅ Postoji |
| `KEY_ALIAS` | ✅ Postoji |
| `KEY_PASSWORD` | ✅ Postoji |
| `KEYSTORE_PASSWORD` | ✅ Postoji |

---

## 📝 Primer Workflow koda

```yaml
# ✅ DODATO u apk-release.yml (26.12.2025)
# Pokreće se samo na tag push (v*)

- name: Upload to Google Play (Production)
  if: startsWith(github.ref, 'refs/tags/v')
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
    packageName: com.gavra013.gavra_android
    releaseFiles: build/app/outputs/flutter-apk/app-release.apk
    track: production
    status: completed
    releaseName: ${{ github.ref_name }}
```

### Opcije za track:
| Track | Opis | Max testera | Za Gavra? |
|-------|------|-------------|------------|
| `internal` | Interni testeri | 100 | ❌ Premalo (imate ~150 korisnika) |
| `alpha` | Zatvoreno testiranje | 100,000 | - |
| `production` | Svi korisnici | Svi | ✅ **IZABRANO** |
| `beta` | Otvoreno testiranje | Neograničeno | Za javno testiranje |
| `production` | Svi korisnici | Svi | Kada je stabilno |

---

## 📚 Korisni linkovi

- [Google Play Console](https://play.google.com/console/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Enable Android Publisher API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com)
- [r0adkll/upload-google-play](https://github.com/r0adkll/upload-google-play)
- [GitHub Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)

---

## 📝 Poznate informacije

```
Package Name: com.gavra013.gavra_android
App Name: Gavra 013
GitHub Repo: bojanbc83/gavra_android
Workflow: .github/workflows/apk-release.yml

Google Cloud Project: gavra-notif-20250920162521
Google Cloud Project Name: Gavra Android Notifications
Service Account: gavra-play-store@gavra-notif-20250920162521.iam.gserviceaccount.com
JSON Key File: play-store-key.json (u root folderu projekta)
Android Publisher API: ENABLED
```

---

## 🚀 Sledeći koraci

1. ✅ ~~Proveriti da li postoji Google Play Developer nalog~~
2. ✅ ~~Registrovati aplikaciju na Play Console~~ (Gavra013 postoji)
3. ✅ ~~Uploadovati prvi APK ručno~~ (1. nov 2025.)
4. ✅ ~~Kreirati Google Cloud projekat~~
5. ✅ ~~Omogućiti Google Play Android Developer API~~
6. ✅ ~~Kreirati Service Account~~
7. ❌ **POTREBNO:** Dodati Service Account u Play Console sa permisijama
8. ✅ ~~Dodati JSON ključ kao GitHub Secret~~ (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`)
9. ✅ ~~Ažurirati `apk-release.yml` workflow~~ (alpha track)
10. ❌ Test push i verifikacija (nakon koraka 7)

---

## ⚠️ ČESTI PROBLEMI

### "Package not found"
- **Uzrok:** Aplikacija nije registrovana ili nema ručno uploadovanog APK-a
- **Rešenje:** Ručno uploadovati bar jedan APK kroz Play Console

### "Precondition check failed"
- **Uzrok:** Nedostaju store listing elementi ili prvi release nije prošao kroz testing track
- **Rešenje:** Prvo uraditi release na `internal` track, pa tek onda `production`

### "Permission denied"
- **Uzrok:** Service Account nema potrebne permisije
- **Rešenje:** Proveriti permisije u Play Console → API access

---

*Ovaj dokument se ažurira kako napredujemo sa integracijom.*
