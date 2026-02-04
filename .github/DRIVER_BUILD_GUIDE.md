# 🚀 GitHub Actions Workflows - VODIČ ZA VOZAČE I ADMIN

## 📱 BRZI START - Za Vozače (1 sat do deployment-a!)

### 🎯 CILJ: Izgraditi APK u ~10-15 minuta

```
GitHub repo → Actions tab → "📲 Quick APK Build for Drivers" → Run workflow
```

### Koraci:
1. **Idi na repo**: https://github.com/kadpitamkurac-hash/gavra_android
2. **Klikni "Actions" tab** (top menu)
3. **Odaberi "📲 Quick APK Build for Drivers"** (levo u workflow-ima)
4. **Klikni "Run workflow"** (desno, modrugumb)
5. **Unesi opis** (opcionalno): "Ispravljena greška pri loginu"
6. **Klikni "Run workflow"** (zeleni dugme)
7. **Čekaj ~15 minuta** (progres vidiš u real-time)
8. **Preuzmi iz Releases tab-a** (ili iz Artifacts)
9. **Pošalji link vozačima** ✅

---

## ⏱️ Timeline (Sat vremena Schedule)

```
00:00 - Kreniš build
00:15 - APK je spreman
00:15-00:30 - Testiraj na telefonu
00:30-00:45 - Pošalji vozačima link
00:45-01:00 - Vozači instaliraju

✅ GOTOVO! Voze sa novom verzijom!
```

---

## 📥 Available Workflows

### 🎯 Za Vozače (SADA DOSTUPAN!)

#### 📲 Quick APK Build for Drivers (PREPORUČENO!)
- **Status**: ✅ LIVE - Koristi odmah!
- **Fajl**: `.github/workflows/quick-apk-build.yml`
- **Trajanje**: ~10-15 minuta
- **Output**: 
  - ✅ GitHub Release sa APK-om
  - ✅ Direktan download link
  - ✅ Changelog sa izmena
  - ✅ Instrukcije za instalaciju
- **Parametri**:
  - `build_description`: Opis izmena (npr. "Fix login bug")
  - `publish_release`: true (automatski GitHub Release)

```bash
# Kako startovati:
GitHub → Actions → "📲 Quick APK Build for Drivers" → Run workflow
Parametri → Unesi opis → Run
```

---

#### 🔄 Auto APK Build on Push
- **Status**: ✅ LIVE - Automatski!
- **Fajl**: `.github/workflows/auto-apk-build.yml`
- **Trigger**: Automatski pri push-u na `main` branch
- **Trajanje**: ~15 minuta
- **Output**:
  - ✅ Artifact upload (7 dana retention)
  - ✅ Commit comment sa APK link-om
  - ✅ Build log za debugging

```bash
# Kako radi:
1. Lokalno radiš na kodu
2. Commitaš i push-uješ na main
3. GitHub Actions automatski pokreće build
4. Rezultat vidiš kao Artifact ili commit comment
```

---

### 🌍 Za Store Deployment (Later - Pod Planiranjem)

#### 🌍 All Platforms Release
- **Status**: 🔲 TODO
- **Deploy**: iOS + Google Play + Huawei (sve odjednom)
- **Trajanje**: ~20-30 minuta
- **Kada koristiti**: Pun release na svim platformama

---

#### 🍎 iOS Production
- **Status**: 🔲 TODO
- **Deploy**: Samo iOS App Store
- **Trajanje**: ~15-20 minuta (macOS runner je spora)

---

#### 📱 Google Play Release
- **Status**: 🔲 TODO
- **Deploy**: Samo Google Play Alpha/Beta/Production
- **Trajanje**: ~5-8 minuta

---

#### 🐧 Huawei AppGallery Release
- **Status**: 🔲 TODO
- **Deploy**: Samo Huawei AppGallery
- **Trajanje**: ~5-8 minuta

---

## 🔐 GitHub Secrets (SVI JE POSTAVLJENI!)

Provera da su aktivni u: `Settings → Secrets and variables → Actions`

### ✅ Android/APK Build Secrets
- ✅ `KEYSTORE_BASE64` - Digitalni potis (base64 kodovan)
- ✅ `KEYSTORE_STORE_PASSWORD` - Lozinka za keystore
- ✅ `KEYSTORE_KEY_PASSWORD` - Lozinka za ključ
- ✅ `KEYSTORE_KEY_ALIAS` - Alias ključa

**Status**: ✅ READY - Workflow-i mogu koristiti

### 🔲 Store Secrets (Dodati Later)
- 🔲 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Za Google Play upload
- 🔲 `HUAWEI_CLIENT_ID` - Za Huawei AppGallery
- 🔲 `HUAWEI_CLIENT_SECRET` - Za Huawei AppGallery
- 🔲 `APP_STORE_CONNECT_KEY_ID` - Za iOS App Store
- itd...

---

## 📊 Verzionisanje

### Format u `pubspec.yaml`
```yaml
version: 6.0.54+424
         ^       ^
         |       +-- Build number (int, povećava se)
         +---------- Version (prikazuje se vozačima)
```

### Kako Povećati Verziju?
1. **Otvori** `pubspec.yaml`
2. **Nađi** liniju `version: X.Y.Z+BUILD`
3. **Povećaj** BUILD broj za 1 (npr. 424 → 425)
4. **Commit & Push**
5. **Pokreni workflow** (Build će biti sa novom verzijom)

### Primer:
```yaml
# Stara verzija
version: 6.0.54+424

# Nova verzija (bugfix)
version: 6.0.54+425

# Ili ako dodaješ feature
version: 6.0.55+1
```

---

## 📥 Preuzimanje APK-a

### Opcija 1: GitHub Releases (BEST ZA VOZAČE)
```
Repo → Releases tab → Latest release → Download .apk
```
✅ Najčistije, lako share-ati link

### Opcija 2: GitHub Artifacts (ZA TESTING)
```
Repo → Actions tab → Poslednji workflow → Artifacts → Download
```
✅ Svi build-ovi dostupni (čak i failed)

### Opcija 3: Direktan Link (BEST ZA SHARING)
```
https://github.com/kadpitamkurac-hash/gavra_android/releases/download/v6.0.54-build-425/app-release.apk
```
✅ Copy-paste u chat direktno vozačima

---

## 📱 Instalacija APK-a na Telefon (Za Vozače)

### Pre Instalacije:
```
Telefon → Settings → Security → Unknown sources
- Omogući "Allow installation from unknown sources"
```

### Instalacija:
```
1. Preuzmi APK fajl na telefon
2. Otvori File Manager
3. Nađi preuzeti APK
4. Klikni na njega
5. Klikni "Install"
6. Ako pita - klikni "Replace" (zameni staru verziju)
7. Čekaj ~30 sekundi
8. Klikni "Open" (pokreni app)
9. ✅ GOTOVO!
```

---

## 🎯 Workflow Status Board

```
📲 Quick APK Build for Drivers        ✅ LIVE   🚀 Ready to use!
🔄 Auto APK Build on Push             ✅ LIVE   🚀 Automatic!
---
🌍 All Platforms Release              🔲 TODO   (planira se)
🍎 iOS Production                     🔲 TODO   (planira se)
📱 Google Play Release                🔲 TODO   (planira se)
🐧 Huawei AppGallery Release          🔲 TODO   (planira se)
```

---

## 🆘 Troubleshooting

### Problem: Build failuje
```
1. Klikni na failed workflow
2. Otvori "Build APK (Release)" step
3. Čitaj error poruku
4. Ispravi problem u kodu
5. Commit, push, pokreni build ponovo
```

### Problem: APK se ne instalira na telefon
```
1. Proveri Android verziju na telefonu
2. Proveri da je "Unknown sources" omogućen
3. Obrisi staru verziju prvo
4. Probaj sa drugom brzinom interneta
```

### Problem: Ne mogu da preuzimam APK
```
1. Provera internet konekcije
2. Čekaj malo (traffic limit)
3. Probaj sa drugog browsera
4. Ili preuzmi iz Artifacts tab-a umesto Release-a
```

---

## 💡 Pro Tips za Vozače

1. **Čuva link za brz pristup**:
   - Bookmark: https://github.com/kadpitamkurac-hash/gavra_android/releases
   - Skoro uvek novija verzija na vrhu!

2. **Automatske notifikacije**:
   - Star repo (gornje desno) → Watch → Custom → Releases
   - Dobijaš email kada je nova verzija dostupna!

3. **Backup APK**:
   - Čuva preuzetu .apk datoteku
   - Ako nešto pođe po zlu - imaš kopiju

4. **Sharuj sa drugima**:
   - GitHub Release link je najjednostavniji
   - Vozači kliknu link → Preuzmu → Instaliraju
   - Bez kompliciranih instrukcija!

---

## 📞 Support

**Pitanja o build-u?** → Kontaktiraj administratora  
**Ako APK ne radi?** → Kontaktiraj development team-a  
**Novi feature request?** → Otvori GitHub Issue  

---

**Zadnja ažuriranja**: 4. februar 2026.  
**Status**: ✅ Sve je spremno za vozače!
