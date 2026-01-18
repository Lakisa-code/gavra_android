# 🔐 GitHub Actions Secrets Checklist

## Pre-pokretanja workflow-a

### ✅ Obavezni Secrets za SVE platforme

Proveri da su sledeći secrets podešeni u: **GitHub → Settings → Secrets and variables → Actions**

---

## 📱 Android Secrets (Google Play & Huawei)

### Keystore Secrets (OBAVEZNO)
- [ ] `KEYSTORE_BASE64` - Base64 enkodovan keystore fajl
  ```bash
  # Kako napraviti:
  base64 -i gavra-release-key-production.keystore | pbcopy  # macOS
  base64 -w 0 gavra-release-key-production.keystore         # Linux
  certutil -encode gavra-release-key-production.keystore keystore.txt  # Windows
  ```
- [ ] `KEYSTORE_PASSWORD` - Password za keystore
- [ ] `KEY_ALIAS` - Alias key-a u keystore-u
- [ ] `KEY_PASSWORD` - Password za key

### Huawei AGConnect (OBAVEZNO za Huawei)
- [ ] `AGC_BASE64` - Base64 enkodovan agconnect-services.json
  ```bash
  # Kako napraviti:
  base64 -i agconnect-services.json | pbcopy  # macOS
  base64 -w 0 agconnect-services.json         # Linux
  certutil -encode agconnect-services.json agc.txt  # Windows
  ```
  
### Google Play Secrets (OBAVEZNO za Google Play)
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Service Account JSON (plain text, NE base64)
  - Preuzmi sa: Google Cloud Console → IAM & Admin → Service Accounts
  - Mora imati **Release Manager** permisiju
  - Format: `{"type": "service_account", "project_id": "...", ...}`

### Huawei AppGallery Secrets (OBAVEZNO za Huawei)
- [ ] `AGC_CLIENT_ID` - Huawei API Client ID
- [ ] `AGC_CLIENT_SECRET` - Huawei API Client Secret
- [ ] `AGC_APP_ID` - Huawei App ID
  - Preuzmi sa: AppGallery Connect → My Apps → API Client

---

## 🍎 iOS Secrets (App Store)

### App Store Connect API (OBAVEZNO)
- [ ] `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID
- [ ] `APP_STORE_CONNECT_KEY_IDENTIFIER` - Key ID
- [ ] `APP_STORE_CONNECT_PRIVATE_KEY` - Private Key (p8 fajl sadržaj)
  - Preuzmi sa: App Store Connect → Users and Access → Keys → App Store Connect API

### iOS Certificate (OBAVEZNO)
- [ ] `CERTIFICATE_PRIVATE_KEY` - iOS Distribution Certificate Private Key
  - Export iz Keychain Access (bez passworda)

---

## 🔍 Kako proveriti secrets

### 1. Lista svih secrets
```bash
gh secret list
```

### 2. Provera da li secret postoji
```bash
gh secret list | grep KEYSTORE_BASE64
gh secret list | grep GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
gh secret list | grep APP_STORE_CONNECT_ISSUER_ID
gh secret list | grep AGC_CLIENT_ID
```

### 3. Dodavanje secret-a
```bash
gh secret set KEYSTORE_PASSWORD
# Paste vrednost i pritisni Enter
```

---

## ⚠️ Česte greške i rešenja

### Google Play Upload Error
**Greška:** `Upload failed: Invalid credentials`
**Rešenje:** 
- Proveri da `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` sadrži validan JSON (ne base64!)
- Proveri da Service Account ima **Release Manager** permisiju
- Proveri da je Service Account aktivan

### Keystore Error
**Greška:** `Keystore was tampered with, or password was incorrect`
**Rešenje:**
- Proveri da je `KEYSTORE_BASE64` tačno enkodovan
- Proveri da su `KEYSTORE_PASSWORD`, `KEY_ALIAS` i `KEY_PASSWORD` tačni
- Proveri da li ima razmaka ili newline karaktera u secret-ima

### iOS Signing Error
**Greška:** `Code signing failed`
**Rešenje:**
- Proveri da su svi App Store Connect API kredencijali tačni
- Proveri da `CERTIFICATE_PRIVATE_KEY` ne sadrži password (mora biti bez passworda)
- Proveri da certificate nije istekao u App Store Connect

### Huawei Upload Error
**Greška:** `Failed to get Huawei access token`
**Rešenje:**
- Proveri da su `AGC_CLIENT_ID` i `AGC_CLIENT_SECRET` tačni
- Proveri da je API pristup omogućen u AppGallery Connect
- Proveri da je `AGC_APP_ID` tačan App ID

### AGConnect Services Error
**Greška:** `agconnect-services.json not found`
**Rešenje:**
- Proveri da je `AGC_BASE64` tačno enkodovan
- Proveri da fajl sadrži validan JSON pre enkodovanja

---

## 🧪 Testiranje pre Production Release-a

### Pre nego što pokreneš All Platforms workflow:

1. **Testiraj Android build lokalno:**
   ```bash
   flutter build appbundle --release
   flutter build apk --release
   ```

2. **Testiraj iOS build (samo na macOS):**
   ```bash
   flutter build ipa --release
   ```

3. **Proveri verziju:**
   ```bash
   grep "^version:" pubspec.yaml
   ```

4. **Testiraj individualne workflow-e prvo:**
   - Pokreni `google-closed-testing.yml` prvo
   - Ako uspe, onda pokreni `huawei-production.yml`
   - Ako uspe, onda pokreni `ios-production.yml`
   - Ako svi uspeju, pokreni `all-platforms-release.yml`

---

## 📋 Pre-Flight Checklist

Pre pokretanja bilo kog workflow-a:

- [ ] Verzija u `pubspec.yaml` je ažurirana
- [ ] Commit je push-ovan na GitHub
- [ ] Svi secrets su podešeni i tačni
- [ ] Testirao sam build lokalno
- [ ] Provero sam da nema pending review-a na platformama
- [ ] Backup keystore fajla postoji
- [ ] Release notes su spremni (za Huawei)

---

## 🚨 Emergency - Workflow Failuje

### Ako Google Play failuje:
1. Proveri logs u GitHub Actions
2. Proveri Service Account permisije
3. Ako je build uspeo, ručno upload-uj AAB na Google Play Console

### Ako Huawei failuje:
1. Proveri API credentials
2. Proveri da nije pending review
3. Ako je build uspeo, ručno upload-uj APK na AppGallery Connect

### Ako iOS failuje:
1. Proveri Codemagic CLI logs
2. Proveri App Store Connect API credentials
3. Ako je build uspeo, ručno upload-uj IPA kroz Xcode ili Transporter

---

## 📞 Kontakt za Credentials

- **Android Keystore:** Čuvan u secure location + backup
- **Google Play Service Account:** Google Cloud Console
- **Huawei Credentials:** AppGallery Connect → API Client
- **iOS Certificates:** App Store Connect → Certificates

---

## 🔄 Kako ažurirati secret

```bash
# Preko GitHub CLI
gh secret set SECRET_NAME

# Ili preko GitHub Web UI
# Settings → Secrets and variables → Actions → Update secret
```

---

## ✅ Quick Validation Script

```bash
#!/bin/bash
echo "🔍 Validating GitHub Secrets..."

REQUIRED_SECRETS=(
  "KEYSTORE_BASE64"
  "KEYSTORE_PASSWORD"
  "KEY_ALIAS"
  "KEY_PASSWORD"
  "AGC_BASE64"
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
  "AGC_CLIENT_ID"
  "AGC_CLIENT_SECRET"
  "AGC_APP_ID"
  "APP_STORE_CONNECT_ISSUER_ID"
  "APP_STORE_CONNECT_KEY_IDENTIFIER"
  "APP_STORE_CONNECT_PRIVATE_KEY"
  "CERTIFICATE_PRIVATE_KEY"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
  if gh secret list | grep -q "$secret"; then
    echo "✅ $secret"
  else
    echo "❌ $secret - MISSING!"
  fi
done
```

Sačuvaj kao `validate-secrets.sh` i pokreni sa `bash validate-secrets.sh`
