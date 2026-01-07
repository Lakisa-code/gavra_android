# 🚀 Unified Deploy Workflow Plan

## Trenutno stanje

```
.github/workflows/
├── google-play-production.yml    # Google Play deploy
├── huawei-review.yml             # Huawei AppGallery deploy
└── (ostali workflows...)
```

**Problem:** Dva odvojena workflow-a, ručno pokretanje, mogućnost nekonzistentnih verzija.

---

## Predloženo rešenje

### Nova struktura:

```
.github/workflows/
├── deploy-all-stores.yml         # 🆕 Master workflow - jedan klik za sve
├── google-play-production.yml    # (ostaje kao backup/standalone)
└── huawei-review.yml             # (ostaje kao backup/standalone)
```

---

## Flow dijagram

```
┌─────────────────────────────────────────────────────────────┐
│                    TRIGGER                                   │
│         (workflow_dispatch ili push tag v*)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    JOB 1: BUILD                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 1. Checkout koda                                     │    │
│  │ 2. Bump version (ako treba)                          │    │
│  │ 3. Setup Flutter + Java                              │    │
│  │ 4. Build AAB (jedan build za sve)                    │    │
│  │ 5. Upload artifact                                   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
          ┌───────────────────┴───────────────────┐
          │                                       │
          ▼                                       ▼
┌─────────────────────────┐       ┌─────────────────────────┐
│  JOB 2: GOOGLE PLAY     │       │  JOB 3: HUAWEI          │
│  (paralelno)            │       │  (paralelno)            │
│  ┌───────────────────┐  │       │  ┌───────────────────┐  │
│  │ Download artifact │  │       │  │ Download artifact │  │
│  │ Upload to Google  │  │       │  │ Upload to Huawei  │  │
│  │ (production/beta) │  │       │  │ Submit for review │  │
│  └───────────────────┘  │       │  └───────────────────┘  │
└─────────────────────────┘       └─────────────────────────┘
          │                                       │
          ▼                                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    JOB 4: NOTIFY                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Summary: koje verzije su deploy-ovane gde            │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Inputs (opcije pri pokretanju)

| Input | Tip | Default | Opis |
|-------|-----|---------|------|
| `deploy_google` | boolean | true | Deploy na Google Play? |
| `deploy_huawei` | boolean | true | Deploy na Huawei? |
| `google_track` | choice | production | internal/alpha/beta/production |
| `huawei_submit_review` | boolean | true | Submit za Huawei review? |
| `release_notes` | string | "Bug fixes" | What's new |
| `bump_version` | boolean | false | Auto-bump verzije? |

---

## Prednosti

| Prednost | Opis |
|----------|------|
| ✅ **Konzistentne verzije** | Isti versionCode na svim platformama |
| ✅ **Jedan klik** | Deploy svuda odjednom |
| ✅ **Brže** | Build samo jednom, upload paralelno |
| ✅ **Fleksibilno** | Možeš izabrati samo jednu platformu |
| ✅ **Manje grešaka** | Jedan izvor istine |

---

## Secrets potrebni

Već imaš sve:
- `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `KEYSTORE_PASSWORD`
- `PLAY_STORE_CREDENTIALS` (Google Play service account)
- `AGC_CLIENT_ID`, `AGC_CLIENT_SECRET`, `AGC_APP_ID` (Huawei)
- `AGC_BASE64` (agconnect-services.json)

---

## Koraci implementacije

1. [x] Kreirati `deploy-all-stores.yml` ✅
2. [ ] Testirati sa `deploy_google=true`, `deploy_huawei=false`
3. [ ] Testirati sa oba
4. [x] Preimenovati stare workflows (backup) ✅

### Završeno:
- `deploy-all-stores.yml` - novi unified workflow
- `google-play-testing.yml` - backup (ex google-closed.yml)
- `huawei-production.yml` - backup (ex huawei-review.yml)

---

## Primer pokretanja

```
GitHub → Actions → "Deploy to All Stores" → Run workflow
  ├── deploy_google: ✅
  ├── deploy_huawei: ✅
  ├── google_track: production
  ├── huawei_submit_review: ✅
  └── release_notes: "Nova verzija sa bug fix-evima"
```

---

## Pitanja za tebe

1. **Da li želiš auto-bump verzije?** (automatski povećava versionCode)
2. **Da li da obrišem stare workflows?** (ili ih ostavim kao backup)
3. **Da li treba iOS workflow takođe?** (za budućnost)

---

**Čekam tvoju potvrdu! 👍**
