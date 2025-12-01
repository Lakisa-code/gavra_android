# 🚀 Huawei AppGallery Connect MCP Server

MCP (Model Context Protocol) server za upravljanje Huawei AppGallery Connect aplikacijama direktno iz VS Code.

## ✨ Funkcionalnosti

| Tool | Opis |
|------|------|
| `huawei_list_apps` | Lista svih aplikacija u tvom nalogu |
| `huawei_get_app_info` | Detalji o aplikaciji |
| `huawei_upload_apk` | Upload APK/AAB fajla |
| `huawei_update_app_info` | Ažuriraj naziv, opis, "šta je novo" |
| `huawei_submit_for_review` | Pošalji na recenziju |
| `huawei_get_status` | Proveri status recenzije |

## 📋 Preduslovi

1. **AppGallery Connect nalog** sa verifikovanim developerom
2. **API kredencijali** iz AppGallery Connect Console

## 🔐 Dobijanje API Kredencijala

1. Idi na [AppGallery Connect Console](https://developer.huawei.com/consumer/en/service/josp/agc/index.html)
2. Klikni na **Users and permissions** > **Connect API**
3. Kreiraj novi API client sa **Publishing API** dozvolama
4. Sačuvaj **Client ID** i **Client Secret**

## 🛠️ Instalacija

```bash
cd huawei-appgallery-mcp
npm install
npm run build
```

## ⚙️ Konfiguracija

### 1. Dodaj u `mcp.json` (VS Code)

```json
{
  "mcpServers": {
    "huawei-appgallery": {
      "command": "node",
      "args": ["C:/Users/Bojan/gavra_android/huawei-appgallery-mcp/dist/index.js"],
      "env": {
        "HUAWEI_CLIENT_ID": "tvoj-client-id",
        "HUAWEI_CLIENT_SECRET": "tvoj-client-secret"
      }
    }
  }
}
```

### 2. Ili koristi environment varijable

```powershell
$env:HUAWEI_CLIENT_ID = "tvoj-client-id"
$env:HUAWEI_CLIENT_SECRET = "tvoj-client-secret"
```

## 📖 Primeri Korišćenja

### Lista aplikacija
```
> huawei_list_apps
```

### Upload APK
```
> huawei_upload_apk appId="12345" filePath="C:/path/to/app-release.apk"
```

### Ažuriraj opis
```
> huawei_update_app_info appId="12345" language="sr-Latn-RS" appName="Gavra 013" appDesc="Transport putnika Bela Crkva - Vršac"
```

### Pošalji na recenziju
```
> huawei_submit_for_review appId="12345"
```

## 🌍 Podržani jezici

| Kod | Jezik |
|-----|-------|
| `en-US` | English |
| `sr-Latn-RS` | Srpski (latinica) |
| `sr-Cyrl-RS` | Српски (ћирилица) |
| `de-DE` | German |
| `fr-FR` | French |

## 📊 Release States

| Kod | Status |
|-----|--------|
| 1 | Draft |
| 2 | Reviewing |
| 3 | Review Rejected |
| 4 | Released |
| 5 | Updating |
| 6 | Update Rejected |
| 7 | Removed |

## 🔧 Development

```bash
# Run in development mode
npm run dev

# Build
npm run build

# Run built version
npm start
```

## 📝 API Dokumentacija

- [AppGallery Connect API Overview](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-overview-0000001158245067)
- [Publishing API Reference](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-gettoken-0000001158245053)

## 📄 Licenca

MIT
