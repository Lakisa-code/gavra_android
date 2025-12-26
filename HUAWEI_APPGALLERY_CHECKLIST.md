# Huawei AppGallery Deploy - Checklist i Status

**Poslednje ažuriranje:** 26. decembar 2025.

---

## 🎯 CILJ

Automatski deploy APK na Huawei AppGallery putem GitHub Actions nakon svakog push-a na `main` branch ili kreiranja taga.

---

## 📊 BROJ KORISNIKA I HUAWEI LIMITI

**Trenutni broj korisnika u sistemu:**
| Tip | Broj |
|-----|------|
| Registrovani putnici | 149 |
| Vozači | 5 |
| **UKUPNO** | ~154 |

**Huawei AppGallery limiti:**
| Tip Release-a | Max korisnika | Za Gavra (~154)? |
|---------------|---------------|------------------|
| Open Testing | Neograničeno | ✅ OK |
| **Closed Testing** | 2,000 | ✅ **DOVOLJNO** |
| Phased Release | % svih korisnika | ✅ OK |
| Full Release | Svi | ✅ OK |

**ZAKLJUČAK:** Huawei nema restriktivne limite - svih ~154 korisnika mogu koristiti bilo koji tip testiranja.

---

## 📊 TRENUTNI STATUS

| Stavka | Status |
|--------|--------|
| GitHub Actions Android build | ✅ Postoji (`apk-release.yml`) |
| Signed APK kreiranje | ✅ Radi |
| GitHub Release kreiranje | ✅ Radi |
| AppGallery Connect pristup | ✅ **AKTIVAN** |
| API Client kreiran | ✅ **KREIRAN** |
| GitHub Secrets dodati | ✅ **DODATI** |
| Prvi ručni upload na AppGallery | ❌ **OBAVEZNO PRE AUTOMATIZACIJE** |
| agconnect-services.json | ✅ Postoji (`assets/agconnect-services.json`) |

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

## ✅ Checklist - Potrebni koraci

### 1. AppGallery Connect - Pristup
- [x] **STATUS:** ✅ AKTIVAN
- **URL:** https://developer.huawei.com/consumer/en/service/josp/agc/index.html
- **Nalog:** Aktivan Huawei Developer nalog
- **Cena:** Besplatno za individualne developere

### 2. Aplikacija registrovana na AppGallery Connect
- [x] **STATUS:** ✅ REGISTROVANA
- **Package name:** `com.gavra013.gavra_android`
- **App ID:** `116046535`
- **⚠️ VAŽNO:** Mora se uploadovati bar jedan APK ručno PRE automatizacije!

### 3. API Client za Publishing API
- [x] **STATUS:** ✅ KREIRAN
- **Client ID:** `1825559368939142080`
- **Client Secret:** `1F4A1FEE55AC46A497B3AF46511BA7390BE3A98FB1305E03D9815AB1A84C5685`
- **Izvor:** mcp.json

### 4. Dobiti App ID
- [x] **STATUS:** ✅ PRONAĐEN
- **App ID:** `116046535`
- **Izvor:** agconnect-services.json

### 5. GitHub Secrets
- [x] **STATUS:** ✅ DODATI

| Secret Name | Opis | Status |
|-------------|------|--------|
| `AGC_CLIENT_ID` | API Client ID | ✅ Dodato |
| `AGC_CLIENT_SECRET` | API Client Secret | ✅ Dodato |
| `AGC_APP_ID` | App ID iz AppGallery Connect | ✅ Dodato |

**GitHub Secrets URL:** https://github.com/bojanbc83/gavra_android/settings/secrets/actions

### 6. Prvi ručni upload (OBAVEZNO!)
- [ ] **STATUS:** ❌ POTREBNO
- **⚠️ VAŽNO:** Huawei Publishing API radi samo sa postojećim aplikacijama!
- **Akcija:** Uploadovati prvi APK ručno kroz AppGallery Connect
- **Minimalni zahtevi:**
  - App ikona
  - Screenshot-ovi (min 3)
  - Opis aplikacije
  - Kategorija
  - Privacy policy URL

---

## 🔐 GitHub Secrets - Potrebni

| Secret Name | Opis | Status |
|-------------|------|--------|
| `AGC_CLIENT_ID` | API Client ID | ✅ `1825559368939142080` |
| `AGC_CLIENT_SECRET` | API Client Secret | ✅ Dodato (skriveno) |
| `AGC_APP_ID` | Numerički App ID | ✅ `116046535` |

**Postojeći secrets (za build):**
| Secret Name | Status |
|-------------|--------|
| `KEYSTORE_BASE64` | ✅ Postoji |
| `KEY_ALIAS` | ✅ Postoji |
| `KEY_PASSWORD` | ✅ Postoji |
| `KEYSTORE_PASSWORD` | ✅ Postoji |
| `AGC_BASE64` | ✅ Postoji (agconnect-services.json) |

---

## 📝 Primer Workflow koda

```yaml
# Dodati u postojeći apk-release.yml nakon builda

- name: Upload to Huawei AppGallery
  env:
    HUAWEI_CLIENT_ID: ${{ secrets.AGC_CLIENT_ID }}
    HUAWEI_CLIENT_SECRET: ${{ secrets.AGC_CLIENT_SECRET }}
    HUAWEI_APP_ID: ${{ secrets.AGC_APP_ID }}
  run: |
    # 1. Dobiti access token
    TOKEN_RESPONSE=$(curl -s -X POST \
      "https://connect-api.cloud.huawei.com/api/oauth2/v1/token" \
      -H "Content-Type: application/json" \
      -d '{
        "grant_type": "client_credentials",
        "client_id": "'$HUAWEI_CLIENT_ID'",
        "client_secret": "'$HUAWEI_CLIENT_SECRET'"
      }')
    
    ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
    
    if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
      echo "❌ Failed to get access token"
      echo "Response: $TOKEN_RESPONSE"
      exit 1
    fi
    
    echo "✅ Access token obtained"
    
    # 2. Dobiti upload URL
    UPLOAD_URL_RESPONSE=$(curl -s -X GET \
      "https://connect-api.cloud.huawei.com/api/publish/v2/upload-url/for-obs?appId=$HUAWEI_APP_ID&releaseType=1" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "client_id: $HUAWEI_CLIENT_ID")
    
    UPLOAD_URL=$(echo $UPLOAD_URL_RESPONSE | jq -r '.uploadUrl')
    AUTH_CODE=$(echo $UPLOAD_URL_RESPONSE | jq -r '.authCode')
    
    if [ "$UPLOAD_URL" == "null" ] || [ -z "$UPLOAD_URL" ]; then
      echo "❌ Failed to get upload URL"
      echo "Response: $UPLOAD_URL_RESPONSE"
      exit 1
    fi
    
    echo "✅ Upload URL obtained"
    
    # 3. Upload APK fajla
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    
    UPLOAD_RESPONSE=$(curl -s -X POST "$UPLOAD_URL" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -F "file=@$APK_PATH" \
      -F "authCode=$AUTH_CODE" \
      -F "fileCount=1")
    
    FILE_DEST=$(echo $UPLOAD_RESPONSE | jq -r '.result.UploadFileRsp.fileInfoList[0].fileDestUlr')
    
    if [ "$FILE_DEST" == "null" ] || [ -z "$FILE_DEST" ]; then
      echo "❌ Failed to upload APK"
      echo "Response: $UPLOAD_RESPONSE"
      exit 1
    fi
    
    echo "✅ APK uploaded successfully"
    
    # 4. Ažurirati app info sa novim APK-om
    UPDATE_RESPONSE=$(curl -s -X PUT \
      "https://connect-api.cloud.huawei.com/api/publish/v2/app-file-info?appId=$HUAWEI_APP_ID" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "client_id: $HUAWEI_CLIENT_ID" \
      -H "Content-Type: application/json" \
      -d '{
        "fileType": 5,
        "files": [{
          "fileName": "app-release.apk",
          "fileDestUrl": "'$FILE_DEST'"
        }]
      }')
    
    echo "✅ App file info updated"
    echo "Response: $UPDATE_RESPONSE"
    
    # 5. (Opciono) Submit za review
    # Odkomentarisati kada želiš automatski submit
    # SUBMIT_RESPONSE=$(curl -s -X POST \
    #   "https://connect-api.cloud.huawei.com/api/publish/v2/app-submit?appId=$HUAWEI_APP_ID" \
    #   -H "Authorization: Bearer $ACCESS_TOKEN" \
    #   -H "client_id: $HUAWEI_CLIENT_ID")
    # echo "Submit response: $SUBMIT_RESPONSE"
```

---

## 🌐 Huawei Publishing API Endpoints

| Endpoint | Metoda | Opis |
|----------|--------|------|
| `/api/oauth2/v1/token` | POST | Dobijanje access tokena |
| `/api/publish/v2/upload-url/for-obs` | GET | Dobijanje URL-a za upload |
| `/api/publish/v2/app-file-info` | PUT | Ažuriranje APK fajla |
| `/api/publish/v2/app-submit` | POST | Submit za review |
| `/api/publish/v2/app-info` | GET | Info o aplikaciji |
| `/api/publish/v2/aabcompile/status` | GET | Status kompajliranja |

**Base URL:** `https://connect-api.cloud.huawei.com`

---

## 📚 Korisni linkovi

- [AppGallery Connect Console](https://developer.huawei.com/consumer/en/service/josp/agc/index.html)
- [Huawei Publishing API dokumentacija](https://developer.huawei.com/consumer/en/doc/development/AppGallery-connect-References/agcapi-reference-oauth-0000001055074875)
- [Connect API - Kreiranje klijenta](https://developer.huawei.com/consumer/en/doc/distribution/app/agc-help-teamaccount-0000001074614594)
- [GitHub Secrets](https://github.com/bojanbc83/gavra_android/settings/secrets/actions)
- [Lokalni MCP server referenca](huawei-appgallery-mcp/src/index.ts)

---

## 📝 Poznate informacije

```
Package Name: com.gavra013.gavra_android
App Name: Gavra 013
App ID: 116046535
Client ID: 1825559368939142080
GitHub Repo: bojanbc83/gavra_android
Workflow: .github/workflows/apk-release.yml
agconnect-services.json: assets/agconnect-services.json
MCP Server: huawei-appgallery-mcp/ (referenca za API)

GitHub Secrets (već dodati):
- AGC_APP_ID
- AGC_CLIENT_ID  
- AGC_CLIENT_SECRET
```

---

## 🚀 Sledeći koraci

1. ✅ ~~Proveriti da li postoji Huawei Developer nalog~~ AKTIVAN
2. ✅ ~~Registrovati aplikaciju na AppGallery Connect~~ App ID: 116046535
3. ❌ **OBAVEZNO:** Uploadovati prvi APK ručno sa svim potrebnim podacima
4. ✅ ~~Kreirati API Client (Connect API)~~ KREIRANO
5. ✅ ~~Zabeležiti Client ID, Client Secret i App ID~~ PRONAĐENO
6. ✅ ~~Dodati secrets u GitHub~~ AGC_* secrets postoje
7. ❌ Ažurirati `apk-release.yml` workflow
8. ❌ Test push i verifikacija

---

## ⚠️ ČESTI PROBLEMI

### "Invalid client credentials"
- **Uzrok:** Pogrešan Client ID ili Client Secret
- **Rešenje:** Proveriti credentials u AppGallery Connect → Connect API

### "App not found"
- **Uzrok:** Pogrešan App ID ili aplikacija nije registrovana
- **Rešenje:** Proveriti App ID u AppGallery Connect → App information

### "Permission denied"
- **Uzrok:** API Client nema potrebne permisije
- **Rešenje:** Proveriti role u Connect API → Edit client → Roles

### "File upload failed"
- **Uzrok:** APK nije potpisan ili je neispravan
- **Rešenje:** Proveriti da li lokalni APK radi, proveriti signing konfiguraciju

### "Review rejected"
- **Uzrok:** Nedostaju obavezni elementi (screenshots, opis, privacy policy)
- **Rešenje:** Popuniti sve obavezne informacije u AppGallery Connect

---

## 🔄 Poređenje sa Google Play

| Aspekt | Google Play | Huawei AppGallery |
|--------|-------------|-------------------|
| GitHub Action | ✅ `r0adkll/upload-google-play` | ❌ Custom script |
| API kompleksnost | Srednja | Srednja |
| Potrebni credentials | 1 (JSON) | 3 (ID, Secret, AppID) |
| Review vreme | 1-3 dana | 1-5 dana |
| Tržište | Globalno | Kina + globalno |

---

*Ovaj dokument se ažurira kako napredujemo sa integracijom.*
