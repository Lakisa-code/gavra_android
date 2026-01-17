# 🚀 GitHub Actions Workflows

Quick reference za deployment workflow-ove.

## Dostupni Workflow-ovi

### 🌍 All Platforms Release (PREPORUČENO)
**Fajl:** `all-platforms-release.yml`  
**Deploy:** iOS + Google Play + Huawei (sve odjednom)  
**Trajanje:** ~15-20 minuta  
**Kada koristiti:** Pun release sa novom verzijom

```
GitHub → Actions → "🌍 All Platforms Release" → Run workflow
```

---

### 🍎 iOS Production
**Fajl:** `ios-production.yml`  
**Deploy:** Samo iOS App Store  
**Trajanje:** ~15-20 minuta  
**Kada koristiti:** iOS hotfix, TestFlight beta

```
GitHub → Actions → "🍎 iOS Production Release" → Run workflow
```

---

### 📱 Google Closed Testing
**Fajl:** `google-closed-testing.yml`  
**Deploy:** Samo Google Play Alpha track  
**Trajanje:** ~5-8 minuta  
**Kada koristiti:** Android testiranje

⚠️ **Važno:** Google Play zahteva **14 dana testiranja** na Alpha/Beta pre promocije na produkciju.

```
GitHub → Actions → "🔒 Google Play Closed Testing" → Run workflow
```

---

### 📱 Huawei Production
**Fajl:** `huawei-production.yml`  
**Deploy:** Samo Huawei AppGallery  
**Trajanje:** ~5-8 minuta  
**Kada koristiti:** Huawei hotfix

```
GitHub → Actions → "📱 Huawei AppGallery Upload" → Run workflow
```

---

## 📋 Pre Pokretanja Workflow-a

1. **Ažuriraj verziju** u `pubspec.yaml`:
   ```yaml
   version: 6.0.25+373  # X.Y.Z+BUILD
   ```

2. **Commit i push** promene

3. **Pokreni workflow** sa GitHub Actions UI

---

## ⚙️ Parametri

### All Platforms & iOS & Huawei
- `submit_for_review`: true/false - Submituje za review nakon upload-a
- `force_replace_review`: false - Zameni postojeću submisiju (opasno!)
- `release_notes`: Opciono za Huawei

### Google Play
- Automatski deploy-uje na Alpha track bez dodatnih parametara

---

## 📊 Verzionisanje

**Format:** `version: X.Y.Z+BUILD`

- **X.Y.Z** - Version Name (prikazuje se u store-ovima)
- **BUILD** - Build Number (interni broj)

**Primer:**
```yaml
version: 6.0.24+372
```
- iOS prikazuje: **6.0.24** (Build 372)
- Android prikazuje: **6.0.24** (Version Code 372)

---

## 🔐 Required Secrets

Proveri da su podešeni u: `Settings → Secrets and variables → Actions`

### iOS
- APP_STORE_CONNECT_ISSUER_ID
- APP_STORE_CONNECT_KEY_IDENTIFIER
- APP_STORE_CONNECT_PRIVATE_KEY
- CERTIFICATE_PRIVATE_KEY

### Android (oba)
- KEYSTORE_BASE64
- KEYSTORE_PASSWORD
- KEY_ALIAS
- KEY_PASSWORD
- AGC_BASE64

### Google Play
- GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

### Huawei
- HUAWEI_CLIENT_ID
- HUAWEI_CLIENT_SECRET
- HUAWEI_APP_ID

---

## 📝 Napomene

- **All Platforms workflow pokreće sve tri platforme paralelno**
- **iOS build traje najduže** (~15-20 min) zbog macOS runner-a
- **Android build-ovi su brži** (~5-8 min)
- **Artifacts se čuvaju 30 dana** (IPA i AAB fajlovi)
- **Concurrency control** - automatski otkazuje prethodni running workflow

### ⚠️ Google Play Produkcija - 14 Dana Pravilo

Google Play ima **obavezno 14-dnevno testiranje** pre promocije na produkciju:

1. **Upload na Alpha** → Workflow automatski postavlja na Alpha track
2. **Čekaj 14 dana** → Obavezno testiranje periode
3. **Promovisi na Production** → Ručno u Google Play Console

**Primer:**
- Upload: 15. januar 2026. → Alpha track
- Najraniji Production release: **29. januar 2026.**

**Kako promovise na Production (nakon 14 dana):**
1. Google Play Console → Release → Production
2. Create new release → Select release from testing
3. Izaberi Alpha release → Review & Roll out to Production

---

## 🆘 Troubleshooting

### Build failuje sa "Keystore error"
- Proveri da su KEYSTORE_BASE64 i svi keystore secrets tačni

### iOS build failuje sa "Signing error"
- Proveri APP_STORE_CONNECT_* secrets
- Proveri da je CERTIFICATE_PRIVATE_KEY tačan

### Google Play upload failuje
- Proveri da je GOOGLE_PLAY_SERVICE_ACCOUNT_JSON validan JSON
- Proveri da Service Account ima potrebne permisije

### Huawei upload failuje
- Proveri HUAWEI_CLIENT_ID i HUAWEI_CLIENT_SECRET
- Proveri da je AGC_BASE64 tačan

---

## 📖 Detaljna Dokumentacija

Za detaljnu dokumentaciju pogledaj: `IOS-GOOGLE-HUAWEI.md`
