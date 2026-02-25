# 🤖 Auto Update Version Script

Automatski ažurira `latest_version` u Supabase `app_settings` tabeli nakon što je nova verzija objavljena na Google Play.

## 📋 Podešavanje

1. **Dodaj Supabase credentials u `.env` fajl:**

```bash
# Dodaj u google-play-mcp/.env ili kreiraj .env.auto-update
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...your-service-role-key
```

2. **Instaliraj dependencies (već urađeno):**

```bash
npm install --prefix ./google-play-mcp js-yaml @supabase/supabase-js
```

## 🚀 Korišćenje

### Opcija 1: Automatski (proveri Google Play)

Skript će:
- Pročitati najnoviju LIVE verziju sa Google Play production track-a
- Uporediti sa trenutnom verzijom u Supabase
- Ažurirati `latest_version` ako je nova verzija dostupna

```bash
node auto-update-version.js
```

**Output:**
```
🤖 Auto Update Version Script

📡 Connecting to Supabase...
✅ Current Supabase versions:
   Min version: 6.0.50
   Latest version: 6.0.50

🔍 Checking Google Play Console...
✅ Google Play production version: 6.0.51
   Version codes: 51
   Status: completed

🔄 Updating app_settings in Supabase...

✅ SUCCESS! Version updated in Supabase:
   Latest version: 6.0.50 → 6.0.51

🔔 All users will receive update notification in real-time!
```

### Opcija 2: Force Update (ručno iz pubspec.yaml)

Koristi verziju iz `pubspec.yaml` umesto Google Play:

```bash
node auto-update-version.js --force
```

### Opcija 3: Force Update (obavezna verzija)

Postavlja i `min_version` i `latest_version` (force update za sve korisnike):

```bash
node auto-update-version.js --force-all
```

**Output sa force update:**
```
✅ SUCCESS! Version updated in Supabase:
   Min version: 6.0.50 → 6.0.51 (FORCE UPDATE)
   Latest version: 6.0.50 → 6.0.51

🔔 All users will receive MANDATORY update notification!
```

## 🔄 Automatizacija (GitHub Actions)

Možeš dodati u `.github/workflows/release.yml`:

```yaml
name: Auto Update Version

on:
  release:
    types: [published]

jobs:
  update-version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm install --prefix ./google-play-mcp
      
      - name: Update Supabase version
        env:
          GOOGLE_PLAY_SERVICE_ACCOUNT_KEY: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: node auto-update-version.js
```

## 🔧 Kada koristiti?

### Scenario 1: Nova funkcionalnost (optional update)
1. Objavi verziju 6.0.51 na Google Play
2. Čekaj da bude LIVE (1-2 dana)
3. Pokreni: `node auto-update-version.js`
4. Korisnici dobijaju notifikaciju sa "Kasnije" dugmetom

### Scenario 2: Kritičan bugfix (force update)
1. Objavi verziju 6.0.51 na Google Play
2. Čekaj da bude LIVE
3. Pokreni: `node auto-update-version.js --force-all`
4. Korisnici dobijaju OBAVEZNU notifikaciju (bez "Kasnije")

## 📊 Šta radi?

1. **Provera trenutne verzije** - Čita `app_settings.latest_version` iz Supabase
2. **Provera Google Play** - API poziv ka production track-u
3. **Poređenje** - Ako je Google Play verzija novija
4. **Update** - Ažurira Supabase tabelu
5. **Realtime** - Svi korisnici odmah dobijaju notifikaciju (Supabase realtime)

## ⚠️ Napomene

- Skript koristi Google Play Console API (isti ključ kao `google-play-mcp`)
- Potreban je Supabase Service Role Key (admin pristup)
- Ne menja verziju NA Google Play-u - samo čita i ažurira Supabase
- Korisnici moraju biti povezani na internet da bi dobili realtime notifikaciju
