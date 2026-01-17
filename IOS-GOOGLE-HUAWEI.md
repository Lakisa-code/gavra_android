# Status Verzija

## iOS (App Store)
- **Produkcija:** 1.1 (Ready for Sale)
- **Datum objave:** 12. januar 2026.
- **Version ID:** f7bded3a-0055-40c8-9d90-2ac33b85c7a2
- **TestFlight Build:** 17 (Valid)

## Huawei (AppGallery)
- **Produkcija:** 6.0.22 (On Shelf)
- **Poslednji upload:** 6.0.23 (Draft)
- **Datum poslednje izmene:** 14. januar 2026.

## Google (Play Store)
- **Alpha (Closed Testing):** 6.0.24 (Testing in Serbia)
- **Datum upload-a:** 15. januar 2026.
- **Produkcija:** Još nije dostupna (potrebno 14 dana testiranja)
- **Najraniji datum za produkciju:** 29. januar 2026.

⚠️ **Google Play Constraint:** Aplikacija mora biti na Alpha/Beta track-u najmanje **14 dana** pre nego što može da se promovise na produkciju.

**Timeline za verziju 6.0.24:**
```
15. januar 2026. ──────────┐
                           │ 14 dana testiranje
                           │ (Alpha track)
                           │
29. januar 2026. ──────────┘ ← Najraniji datum za Production release
```

---

# GitHub Actions Workflows

## 🌍 all-platforms-release.yml (PREPORUČENO)

### Opis
Jedan workflow koji deployuje na **sve tri platforme odjednom**: iOS App Store, Google Play i Huawei AppGallery.

### Pokretanje
GitHub → Actions → "🌍 All Platforms Release" → Run workflow

**Parametri:**
- `submit_for_review`: Submituje za review nakon upload-a (iOS & Huawei) (default: true)
- `release_notes`: Release notes za Huawei (opciono)
- `force_replace_review`: Zameni postojeću submisiju u review-u (opasno, default: false)

### Verzionisanje
- Sve tri platforme koriste **istu verziju** iz `pubspec.yaml`
- Format: `version: X.Y.Z+BUILD`
- iOS koristi samo BUILD broj, Android koristi i VERSION_NAME i BUILD

### Proces
Workflow pokreće **3 paralelna job-a**:

#### 1. **Google Play** (ubuntu-latest)
- Build Android App Bundle (.aab)
- Upload na **Alpha track** (Closed Testing)
- Automatski publish-uje (status: completed)
- ⚠️ **Napomena:** Google Play zahteva 14 dana testiranja na Alpha/Beta pre promocije na produkciju

#### 2. **Huawei AppGallery** (ubuntu-latest)
- Build Android App Bundle (.aab)
- Upload na Huawei AppGallery
- Opciono submituje za review

#### 3. **iOS App Store** (macos-latest)
- Build iOS IPA
- Upload na App Store Connect
- Link build sa verzijom
- Opciono submituje za review

#### 4. **Summary** (finalni job)
- Prikazuje status svih platformi
- Izvršava se nakon sva tri job-a
- Prikazuje koji su uspeli a koji nisu

### Prednosti
✅ Deploy na sve tri platforme odjednom  
✅ Isti build number za sve platforme  
✅ Ušteda vremena - paralelno izvršavanje  
✅ Konzistentan summary svih platformi  
✅ Jedan klik za kompletan release  

### Napomene
- Svaki job se izvršava **paralelno** (istovremeno)
- Ako jedan job failuje, ostali nastavljaju
- Artifacts se čuvaju za sve tri platforme (30 dana)
- iOS job traje duže (~15-20 min) zbog macOS buildovanja

---

# iOS GitHub Actions Workflow

## 🍎 ios-production.yml

### Pokretanje
Workflow se pokreće ručno kroz GitHub Actions UI sa sledećim parametrima:

**Parametri:**
- `submit_for_review`: Da li da se automatski submituje za App Store review (default: true)
- `release_notes`: Release notes (opciono)
- `force_replace_review`: Automatski zameni postojeću submisiju koja je u review-u (koristiti sa oprezom, default: false)

### Verzionisanje
- Verzija se automatski čita iz `pubspec.yaml`
- Format: `version: X.Y.Z+BUILD` (npr. `version: 6.0.24+372`)
- `X.Y.Z` = Version Name (prikazuje se u App Store-u)
- `BUILD` = Build Number (interno za Apple)

### Proces
1. **Checkout & Setup**: Preuzima kod i podešava Flutter 3.35.6
2. **Dependencies**: Instalira Codemagic CLI tools i Flutter dependencies
3. **Code Signing**: Automatski fetch-uje signing files i certifikate sa App Store Connect
4. **Build**: Kompajlira iOS IPA fajl sa verzijom iz `pubspec.yaml`
5. **Upload**: Upload-uje build na App Store Connect
6. **Processing**: Čeka 3 minuta da Apple procesira build
7. **Link Build**: Pronalazi build i linkuje ga sa verzijom (VERSION_ID)
8. **Check Submission**: Proverava da li već postoji aktivna submisija
9. **Submit**: Submituje za review ako je `submit_for_review=true`
10. **Artifact**: Čuva IPA fajl kao GitHub artifact (30 dana)

###環境 (Environment Variables)
```yaml
FLUTTER_VERSION: '3.35.6'
BUNDLE_ID: 'com.gavra013.gavra013ios'
APP_ID: '6757114361'
VERSION_ID: 'f7bded3a-0055-40c8-9d90-2ac33b85c7a2'  # ID za verziju 1.1
```

### Secrets (GitHub Repository Secrets)
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect API Issuer ID
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect API Key ID
- `APP_STORE_CONNECT_PRIVATE_KEY`: App Store Connect API Private Key
- `CERTIFICATE_PRIVATE_KEY`: iOS Distribution Certificate Private Key

### Napomene
- Workflow automatski briše prethodnu instancu ako je već pokrenuta (concurrency control)
- Build se automatski linkuje sa VERSION_ID (trenutno za verziju 1.1)
- Ako build nije pronađen, workflow ne pada nego ostavlja upozorenje
- IPA fajl se čuva kao artifact 30 dana za backup
- Može se pokrenuti build bez submisije za review (korisno za TestFlight)

### Kada kreirati novu verziju
Kada treba da kreirate novu verziju (npr. 1.2), potrebno je:
1. Kreirati novu App Store verziju u App Store Connect (može se koristiti MCP tool)
2. Ažurirati `VERSION_ID` u workflow fajlu sa novim version ID
3. Ažurirati dokumentaciju sa novim Version ID
4. Ažurirati `version` u `pubspec.yaml` (npr. `version: 1.2.0+373`)

### Korišćenje MCP za upravljanje iOS verzijama
```bash
# Kreiranje nove App Store verzije
mcp_app-store-con_ios_create_app_store_version --versionString "1.2" --platform "IOS"

# Provera statusa verzija
mcp_app-store-con_ios_get_app_store_versions

# Provera review statusa
mcp_app-store-con_ios_get_review_status
```

---

# Individualni Workflows

Pored all-platforms workflow-a, postoje i individualni workflow-ovi za svaku platformu:

## 📱 google-closed-testing.yml
- **Svrha**: Upload samo na Google Play Alpha track
- **Kada koristiti**: Testiranje samo na Android-u pre nego što ode na sve platforme
- **Brzo**: ~5-8 minuta

## 📱 huawei-production.yml
- **Svrha**: Upload samo na Huawei AppGallery
- **Kada koristiti**: Brzi hotfix samo za Huawei korisnike
- **Brzo**: ~5-8 minuta

## 🍎 ios-production.yml
- **Svrha**: Upload samo na iOS App Store
- **Kada koristiti**: Brzi hotfix samo za iOS korisnike, TestFlight testiranje
- **Sporije**: ~15-20 minuta (zbog macOS build-a)

---

# Kada koristiti koji workflow?

| Scenario | Workflow | Razlog |
|----------|----------|--------|
| **Pun release sa novom verzijom** | `all-platforms-release.yml` | Deployuje na sve tri platforme odjednom |
| **Samo Android testiranje (Alpha)** | `google-closed-testing.yml` | Brže nego sve platforme, samo za Alpha testiranje |
| **Hitna izmena samo za iOS** | `ios-production.yml` | Nema potrebe buildovati Android verzije |
| **TestFlight beta testiranje** | `ios-production.yml` | Submit for review = false |
| **Hitna izmena samo za Huawei** | `huawei-production.yml` | Samo Huawei korisnici pogođeni |

⚠️ **VAŽNO - Google Play Produkcija:**  
Google Play zahteva da aplikacija bude na Alpha ili Beta track-u najmanje **14 dana** pre nego što se može promovise na produkciju. To znači:
- Upload na Alpha → Čekaj 14 dana → Tek onda promovisi na Production
- Trenutna verzija 6.0.24 može na produkciju: **29. januar 2026.**

Za promociju na produkciju (nakon 14 dana):
1. Idi na Google Play Console
2. Release → Production
3. Create new release
4. Select release from testing → Izaberi Alpha release
5. Review & Roll out to Production

---

# Secrets potrebni za sve workflow-ove

### iOS (App Store Connect)
```
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_KEY_IDENTIFIER
APP_STORE_CONNECT_PRIVATE_KEY
CERTIFICATE_PRIVATE_KEY
```

### Android (Google Play & Huawei)
```
KEYSTORE_BASE64
KEYSTORE_PASSWORD
KEY_ALIAS
KEY_PASSWORD
AGC_BASE64  # Huawei agconnect-services.json
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
```

### Huawei AppGallery
```
HUAWEI_CLIENT_ID
HUAWEI_CLIENT_SECRET
HUAWEI_APP_ID
```

