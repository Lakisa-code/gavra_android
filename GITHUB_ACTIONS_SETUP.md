# 🤖 GitHub Actions - Auto Update Version

Automatsko ažuriranje verzije u Supabase preko GitHub Actions.

## 🔐 Setup (jednom)

1. **Idi na GitHub → Repository → Settings → Secrets and variables → Actions**

2. **Dodaj sledeće secrets:**

   - `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY`
     ```
     Kopiraj vrednost iz google-play-mcp/.env
     (ceo JSON objekat)
     ```

   - `SUPABASE_URL`
     ```
     https://gjtabtwudbrmfeyjiicu.supabase.co
     ```

   - `SUPABASE_SERVICE_ROLE_KEY`
     ```
     sb_secret_KjG-h8DIdo5v2WgIxnDyWw_9By0UDcA
     ```

3. **Commit i push `.github/workflows/update-version.yml` fajl**
   ```bash
   git add .github/workflows/update-version.yml
   git commit -m "Add GitHub Actions workflow for auto version update"
   git push
   ```

## 🚀 Korišćenje

### **GitHub UI (preporučeno)**

1. Idi na GitHub → **Actions** tab
2. Izaberi workflow **"Update App Version in Supabase"**
3. Klikni **"Run workflow"** dugme
4. Izaberi opcije:
   - ☐ Force update (use pubspec.yaml version)
   - ☐ Force update for all users (mandatory)
5. Klikni **"Run workflow"** zeleno dugme

### **Opcije:**

#### **Opcija 1: Auto (default)**
- Čita najnoviju verziju sa Google Play
- Ažurira samo `latest_version`
- Korisnici dobijaju OPCIONI update

**Kada koristiti:**
- Nova funkcionalnost
- Minor bugfixevi
- Performance improvements

#### **Opcija 2: Force update**
✅ **Force update (use pubspec.yaml version)**
- Koristi verziju iz `pubspec.yaml` umesto Google Play
- Ažurira samo `latest_version`

**Kada koristiti:**
- Testiranje pre nego što je verzija live
- Ručna kontrola verzije

#### **Opcija 3: Force update for all**
✅ **Force update for all users (mandatory)**
- Postavlja `min_version = latest_version`
- Korisnici MORAJU da ažuriraju

**Kada koristiti:**
- Kritičan security bug
- Breaking change u backend API
- Obavezan hotfix

## 📊 Workflow

```
1. Build nova verzija (6.0.51)
   └─> flutter build appbundle --release

2. Upload na Google Play
   └─> Čekaj approval (1-2 dana)

3. Kada je LIVE → GitHub Actions
   └─> Actions → Update App Version → Run workflow
   
4. Korisnici automatski dobijaju notifikaciju! 🔔
```

## 🔄 Lokalno vs GitHub Actions

| Metod | Prednost |
|---|---|
| **Lokalno** (`node auto-update-version.js`) | Brže, trenutno, za testiranje |
| **GitHub Actions** | Automatizovano, logovanje, iz bilo kog uređaja |

## 📝 Logs

Možeš videti šta se desilo u Actions tab → klikni na run → vidi output.

**Output primer:**
```
Run auto-update script
🤖 Auto Update Version Script

📡 Connecting to Supabase...
✅ Current Supabase versions:
   Min version: 6.0.50
   Latest version: 6.0.50

🔍 Checking Google Play Console...
✅ Google Play production version: 6.0.51
   Status: completed

🔄 Updating app_settings in Supabase...

✅ SUCCESS! Version updated in Supabase:
   Latest version: 6.0.50 → 6.0.51

🔔 All users will receive update notification in real-time!
```

## 🎯 Troubleshooting

**Problem:** "GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not found"
- Proveri da si dodao secret u GitHub Settings → Secrets

**Problem:** "No completed production release found"
- Verzija još nije LIVE na Google Play
- Koristi `--force` opciju da ažuriraš iz pubspec.yaml

**Problem:** "Supabase connection failed"
- Proveri SUPABASE_URL i SUPABASE_SERVICE_ROLE_KEY secrets
