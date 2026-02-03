# 📱 Gavra Android - APK Build Guide za Vozače

## ✅ Available Workflows

Imaš 3 opcije za pravljenje APK-a:

### 1️⃣ **Quick Build** (📲 Najbrže za testiranje)
- **Idi na**: GitHub repo → **Actions** tab
- **Klikni**: **📲 Quick Build (Driver Download)**
- **Unesi**: Opis promjena (npr. "Ispravljena greška pri login-u")
- **Rezultat**: APK file za download sa jasan link

### 2️⃣ **Build & Release** (🚀 Sa verzionisanjem)
- **Idi na**: **Actions** tab
- **Klikni**: **🚀 Build & Release APK**
- **Unesi**: 
  - Release type: `alpha`, `beta` ili `production`
  - Build notes za vozače
- **Rezultat**: GitHub Release sa verzijom i download linkom

### 3️⃣ **Original Build** (📱 Bazni workflow)
- **Idi na**: **Actions** tab
- **Klikni**: **📱 APK Build for Testing**
- **Opciono**: Unesi build name
- **Rezultat**: APK dostupan u Artifacts

---

## 🔐 Preduslov: GitHub Secrets (VEĆ POSTAVLJENI)

Svi secrets su već postavljeni:
- ✅ `KEYSTORE_BASE64` - Digitalni potis za signing APK-a
- ✅ `KEYSTORE_STORE_PASSWORD` - Lozinka za keystore
- ✅ `KEYSTORE_KEY_PASSWORD` - Lozinka za key
- ✅ `KEYSTORE_KEY_ALIAS` - Alias ključa

---

## 🚀 Brzi Startup (Preporuka)

Koristi **📲 Quick Build** workflow jer je:
- ⚡ Najbrži (~10-15 minuta)
- 🎯 Jasne instrukcije za vozače
- 📥 Direktan download link
- 📝 Mogućnost dodavanja changelog-a

### Koraci:
1. Idi na repo: `https://github.com/kadpitamkurac-hash/gavra_android`
2. Klikni **Actions** tab
3. Odaberi **📲 Quick Build (Driver Download)**
4. Klikni **Run workflow**
5. Unesi changelog (npr. "Ispravljena GPS lokacija, brža login ruta")
6. Čekaj ~15 minuta
7. Workflow će prikazati download link

---

## 📲 Kako Vozači Instaliraju APK

1. **Download APK**: Klikni na link iz workflow output-a
2. **Prenesu na telefon**: Via USB ili email
3. **Omoguće Unknown Sources**:
   - Settings → Security → Unknown Sources (ON)
4. **Otvore APK file** → "Install" → "Done"
5. **Applikacija je instalirana** ✨

---

## 🔗 Direktni GitHub Links

- **Repo**: https://github.com/kadpitamkurac-hash/gavra_android
- **Actions**: https://github.com/kadpitamkurac-hash/gavra_android/actions
- **Releases**: https://github.com/kadpitamkurac-hash/gavra_android/releases

---

## 💡 Tips

- Workflow se pokreće samo sa `main` branch-a
- Svi builds su signed sa production keystore-om
- Artifacts se čuvaju 30-90 dana
- Možeš pokrenut multiple builds paralelno
- Verzija je u `pubspec.yaml` (`version: 6.0.54+424`)

---

## ❓ Ako Build Faila

Provjerite:
1. Da li secrets postoje u Settings → Secrets
2. Da li je `pubspec.lock` committed
3. Da li je Android SDK postavljen (obično je, GitHub Actions to radi)
4. Pogledajte workflow run log za detaljnu grešku

---

*Last Updated: 3.2.2026*
