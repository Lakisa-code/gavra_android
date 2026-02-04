# 📱 APK Build Guide za Vozače

## ⚡ Brzi Start (Sat vremena da budeš gotov!)

### 1️⃣ **Pokreni Build**
```
GitHub repo → Actions tab → "📲 Quick APK Build for Drivers" → Run workflow
```

### 2️⃣ **Unesi Opis Izmena** (Opcionalno)
```
npr. "Ispravljena greška pri loginu, bolje obaveštenja"
```

### 3️⃣ **Klikni "Run workflow"** ✅

---

## ⏱️ Koliko Traje Build?

| Faza | Trajanje |
|------|----------|
| Setup & Dependencies | ~3 min |
| Flutter Build | ~5 min |
| APK Signing | ~2 min |
| Upload | ~1 min |
| **UKUPNO** | **~10-15 minuta** |

---

## 📥 Preuzimanje APK-a

### Opcija 1: GitHub Release (PREPORUČENO)
1. Idi na **Releases** sekciju repo-a
2. Preuzmi najnoviji `.apk` fajl
3. Šalji vozačima direktan link

### Opcija 2: GitHub Artifacts
1. Idi na **Actions** tab
2. Klikni na poslednji build
3. Preuzmi iz "Artifacts" sekcije

---

## 📱 Instalacija APK-a na Telefon (Vozačima)

### Za Android 12 i novije:
```
1. Settings → Apps → Special app access → Install unknown apps
2. Odaberi pretraživač koji koristiš
3. Uključi "Allow from this source"
```

### Za starije Android verzije:
```
1. Settings → Security → Unknown sources
2. Uključi "Allow installation of apps from sources other than the Play Store"
```

### Instalacija:
```
1. Preuzmi APK fajl
2. Otvori preuzeti fajl
3. Klikni "Install"
4. Ako pita - deinstalira staru verziju
5. Gotovin! ✅
```

---

## 🔐 GitHub Secrets (Već postavljeni!)

Svi potrebni secrets za signing APK-a su već postavljeni:
- ✅ `KEYSTORE_BASE64` - Digitalni potis
- ✅ `KEYSTORE_STORE_PASSWORD` - Lozinka keystore-a
- ✅ `KEYSTORE_KEY_PASSWORD` - Lozinka ključa
- ✅ `KEYSTORE_KEY_ALIAS` - Alias ključa

**❌ Ne dodaj nove secrets bez dogovora sa Admin-om!**

---

## 🚀 Opcije Build-a

### 📲 Quick APK Build (NAJBRŽI - ZA VOZAČE)
- Brz build (~10 min)
- Automatski GitHub Release
- Direktan download link
- Changelog sa izmena

```yaml
GitHub → Actions → "📲 Quick APK Build for Drivers"
```

### 🔄 Auto Build on Push
- Automatski build pri svakom push-u na `main`
- Upload u Artifacts
- Trajanje: ~15 min
- Commit comment sa linkom

```yaml
Automatski pokrene se pri push-u
```

---

## 📊 Build Status & Monitoring

### Gde Vidim Status?
1. Repo → **Actions** tab
2. Klikni na poslednji workflow
3. Vidiš sve korake i greške (ako ima)

### Ako Build Padne ❌
1. Klikni na failed workflow
2. Vidiš error poruku
3. Ispravi problem u kodu
4. Pokreni build ponovo

---

## 🎯 Best Practices

✅ **RADI:**
- Push samo stable kod na `main`
- Testira lokalno pre push-a
- Koristi descriptive commit messages
- Prati build status

❌ **NE RADI:**
- Dodaj secrets bez dogovora
- Push broken code
- Testiraj direktno na production branch-u
- Ignoriši build errors

---

## 📞 Troubleshooting

### Problem: Build fails sa "Keystore error"
**Rešenje:** Keystore secrets su ispravni. Kontaktiraj admin-a.

### Problem: Flutter dependencies error
**Rešenje:** 
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Problem: Build je spora
**Rešenje:** Runner kešira dependencies - drugi build-ovi će biti brži.

### Problem: APK ne instalira se na telefon
**Rešenje:** 
- Obrisi staru verziju prvo
- Proveri Android verziju
- Omogući "Unknown sources"

---

## 📈 Verzionisanje

### Gde Se Verzija Menja?
`pubspec.yaml`:
```yaml
version: 6.0.54+424
         ^       ^
         |       +-- Build number (Build ID)
         +---------- Version number
```

### Kako Povećati Verziju?
```yaml
# Za minor update
version: 6.0.54+425

# Za patch (npr. bugfix)
version: 6.0.55+1

# Za major update
version: 6.1.0+1
```

---

## 🔗 Važni Linkovi

- 📦 **Repo**: https://github.com/kadpitamkurac-hash/gavra_android
- 🔗 **Releases**: https://github.com/kadpitamkurac-hash/gavra_android/releases
- ⚙️ **Actions**: https://github.com/kadpitamkurac-hash/gavra_android/actions
- 📱 **Google Play**: [Link kada bude live]
- 🐧 **Huawei AppGallery**: [Link kada bude live]

---

## 💡 Pro Tips

1. **Brz Download za Vozače**: 
   - Koristi GitHub Release link - najčistije za share
   
2. **Praćenje Build-a**:
   - Bookmark Actions tab u browser-u
   
3. **Backup APK-a**:
   - Čuva APK u lokalnoj mapi pre nego što ga šaleš

4. **Notify Vozače**:
   - Pošalji im GitHub Release link sa `Ctrl+C` (copy link)

---

**Pitanja? Kontaktiraj administratora! 📧**
