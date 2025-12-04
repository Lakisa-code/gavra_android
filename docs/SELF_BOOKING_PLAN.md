# 📋 PLAN: Self-Booking za Putnike

> Ovaj dokument sadrži sve detalje za implementaciju sistema gde putnici sami zakazuju vožnje.
> Ažurira se tokom planiranja pre implementacije.

---

## 🎯 CILJ

Omogućiti putnicima (mesečnim i dnevnim) da sami zakazuju vožnje kroz aplikaciju, uz odobrenje admina.

---

## 📱 TOK ZA PUTNIKA

```
1. Admin šalje link za APK putniku
         ↓
2. Putnik instalira APK
         ↓
3. Putnik otvara app → EKRAN ZA REGISTRACIJU
         ↓
4. Popunjava formu sa podacima
         ↓
5. Klikne "Pošalji zahtev"
         ↓
6. Admin vidi zahtev i odobri/odbije
         ↓
7. Putnik dobija pristup svom ekranu
```

---

## ✅ ODLUKE

### 1. Razlikovanje vozača od putnika

**Odluka:** ✅ **Dugme "Vozači" sa dijalogom**

Welcome screen ima providno dugme "Vozači" koje otvara dijalog sa listom vozača.
Putnici vide dugme "Zatraži pristup" na sredini ekrana.

```
┌─────────────────────────┐
│      DOBRODOŠLI         │
├─────────────────────────┤
│       [O nama]          │
│       [Vozači]          │  ← Otvara dijalog sa vozačima
├─────────────────────────┤
│                         │
│   [📝 Zatraži pristup]  │  ← Na sredini ekrana
│                         │
├─────────────────────────┤
│      GAVRA 013          │
└─────────────────────────┘
```

---

### 2. Forma za registraciju - polja

| Polje | Obavezno? | Tip | Status |
|-------|-----------|-----|--------|
| Grad | ✅ | Dropdown: BC / VS | ✅ Potvrđeno |
| Ime | ✅ | Text (min 2 kar.) | ✅ Potvrđeno |
| Prezime | ✅ | Text (min 2 kar.) | ✅ Potvrđeno |
| Adresa | ✅ | Text | ✅ Potvrđeno |
| Email | ❌ | Email | ✅ **Opciono** |
| Broj telefona | ✅ | Phone | ✅ Potvrđeno |
| Poruka za admina | ❌ | Text | ✅ **Opciono** |

**Napomena:** Tip putnika je automatski `dnevni` - mesečni se dodaju ručno.

**Info box:** Forma prikazuje poruku "Registracija se vrši samo jednom! Nakon odobrenja, tvoji podaci se pamte..."

---

### 3. Šta se dešava posle registracije?

**Odluka:** ✅ **Opcija A - Putnik čeka odobrenje admina**

```
Putnik se registruje → Vidi "Čekaj odobrenje" → Admin odobri → Putnik dobija pristup
```

---

### 4. Šta odobreni putnik vidi/radi?

**Za mesečnog putnika:**
- [x] Vidi svoj raspored
- [x] Vidi broj vožnji
- [x] Vidi broj otkazivanja
- [ ] Može da otkaže dan (naknadno)
- [ ] Može da zakaže van rasporeda (naknadno)

**Za dnevnog putnika:**
- [x] Može da pošalje ZAHTEV za vožnju (admin odobrava)
- [ ] Vidi slobodna mesta (naknadno)

**Napomena:** Sistem sa zahtevima daje kontrolu adminu - može da odbije ako nema mesta ili dođe do kvara.

---

### 5. Postojeća tabela ili nova?

**Odluka:** ✅ **Opcija A - Koristi postojeću tabelu `zahtevi_pristupa`**

Tabela `zahtevi_pristupa` je prazna (0 redova) i može se iskoristiti.
Potrebno je dodati 3 kolone:

```sql
ALTER TABLE zahtevi_pristupa
ADD COLUMN grad TEXT,           -- 'BC' / 'VS'
ADD COLUMN tip_putnika TEXT,    -- 'mesecni' / 'dnevni'
ADD COLUMN podtip TEXT;         -- 'ucenik' / 'radnik' (za mesečne)
```

Postojeće kolone koje se koriste:
- `ime`, `prezime`, `adresa`, `telefon`, `email` ✅
- `status` (pending/approved/rejected) ✅
- `poruka` ✅
- `created_at` ✅

---

### 6. Kapacitet vozila

| Stavka | Vrednost |
|--------|----------|
| Podešavanje | Admin ručno menja broj slobodnih mesta |
| Promenljivo | Da - zbog kvara, broja kombija, itd. |

**Napomena:** Detalji o kapacitetu (tabela, UI) će se definisati naknadno.

---

### 7. Distribucija APK-a

**Metod:** Link za GitHub artifact ili direktno slanje APK fajla

**Napomena:** Treba proveriti da li je repo privatan.

---

### 8. Brisanje vozačkog zahteva

**Odluka:** ✅ **DA - obrisati kod, zadržati tabelu**

Fajlovi za brisanje/modifikaciju:
- `lib/screens/zahtev_pristupa_screen.dart` → PREPRAVI za putnike
- Dugme "Zatraži pristup" u `welcome_screen.dart` → Zameni sa "Registruj se"
- Sekcija zahteva u `auth_screen.dart` → Prilagodi za putnike

Tabela `zahtevi_pristupa` ostaje - dodaju se kolone.

---

## 🗄️ STANJE SUPABASE TABELA

| Tabela | Redova | Status | Napomena |
|--------|--------|--------|----------|
| `mesecni_putnici` | 88 | ✅ KEEP | Aktivni putnici (+ kolona `pin`) |
| `putovanja_istorija` | 124 | ✅ KEEP | Istorija vožnji |
| `adrese` | 75 | ✅ KEEP | Adrese putnika |
| `vozaci` | 5 | ✅ KEEP | Vozači |
| `vozila` | 4 | ✅ KEEP | Kombiji (8-14 mesta) |
| `zahtevi_pristupa` | 0 | ✅ REUSE | Koristi za registraciju putnika (+grad, tip_putnika, podtip) |
| `dnevni_putnici` | 0 | ✅ KEEP | Koristi se u kodu za dnevne putnike |
| `daily_checkins` | 0 | ✅ KEEP | Koristi se za check-in vozača |
| `gps_lokacije` | 0 | ✅ KEEP | Koristi se za GPS tracking |
| `rute` | - | ✅ OBRISANO | 2025-12-04 |

---

## 📍 KORACI IMPLEMENTACIJE

### Dnevni putnici (self-booking)

| # | Korak | Opis | Status |
|---|-------|------|--------|
| 1 | Dodaj kolone u `zahtevi_pristupa` | grad, tip_putnika, podtip | ✅ Završeno |
| 2 | Modifikuj `welcome_screen.dart` | Novi layout: O nama, Vozači, Zatraži pristup, Mesečni putnici | ✅ Završeno |
| 3 | Prepravi `zahtev_pristupa_screen.dart` | Forma za DNEVNE putnike | ✅ Završeno |
| 4 | Admin panel - pregled zahteva putnika | `zahtevi_pregled_screen.dart` - Lista + Odobri/Odbij | ✅ Završeno |
| 5 | Dugme "Zahtevi" u admin ekranu | Treći red u `admin_screen.dart` | ✅ Završeno |
| 6 | Napravi ekran "Čekaj odobrenje" | `putnik_cekanje_screen.dart` - realtime praćenje statusa | ✅ Završeno |
| 7 | Ekran za odobrenog dnevnog putnika | `dnevni_putnik_screen.dart` - Forma za zahtev vožnje | ✅ Završeno |
| 8 | Testiranje | Ceo flow | ⏳ Čeka |

### Mesečni putnici (pristup profilu)

| # | Korak | Opis | Status |
|---|-------|------|--------|
| 1 | Dugme "Mesečni putnici" na welcome screen | Otvara login ekran | ✅ Završeno |
| 2 | `mesecni_putnik_login_screen.dart` | Login sa telefon + PIN | ✅ Završeno |
| 3 | `mesecni_putnik_profil_screen.dart` | Prikazuje profil putnika (ime, tip, statistike) | ✅ Završeno |
| 4 | Kolona `pin` u tabeli `mesecni_putnici` | 4-cifreni PIN | ✅ Završeno |
| 5 | PIN dijalog za admina | `pin_dialog.dart` - generiši/pošalji PIN | ✅ Završeno |
| 6 | PIN dugme na kartici putnika | U `mesecni_putnici_screen.dart` | ✅ Završeno |
| 7 | Testiranje | Login flow | ⏳ Čeka |

---

## 📝 BELEŠKE

- Putnici pristupaju app samo ako im admin pošalje APK link
- Samo admin može da odobri zahteve
- Kapacitet (broj mesta) je promenljiv - admin postavlja

---

## 📅 ISTORIJA IZMENA

| Datum | Izmena |
|-------|--------|
| 2025-12-04 | Kreiran dokument |
| 2025-12-04 | Analiza tabela završena - Opcija A potvrđena |
| 2025-12-04 | Ažurirana lista tabela sa statusom KEEP/DELETE |
| 2025-12-04 | Tabela `rute` obrisana iz Supabase |
| 2025-12-04 | Dodate kolone u `zahtevi_pristupa`: grad, tip_putnika, podtip |
| 2025-12-04 | Welcome screen redizajniran: O nama, Vozači (dijalog), Zatraži pristup na sredini |
| 2025-12-04 | Odluka: Opcija A - registracija samo za DNEVNE putnike (mesečni ostaju ručno) |
| 2025-12-04 | `zahtev_pristupa_screen.dart` prepravljen za dnevne putnike |
| 2025-12-04 | Dodat info box "Registracija se vrši samo jednom", Email opciono, naslov "Zakaži vožnju" |
| 2025-12-04 | Kreiran `zahtevi_pregled_screen.dart` za admin pregled zahteva |
| 2025-12-04 | Dodato dugme "Zahtevi" u admin_screen.dart |
| 2025-12-04 | Dodato dugme "Mesečni putnici" na welcome screen |
| 2025-12-04 | Kreiran `mesecni_putnik_login_screen.dart` sa telefon + PIN loginom |
| 2025-12-04 | Kreiran `mesecni_putnik_profil_screen.dart` za prikaz profila |
| 2025-12-04 | Dodata kolona `pin` u tabelu `mesecni_putnici` |
| 2025-12-04 | Kreiran `pin_dialog.dart` za admina (generiši/pošalji PIN) |
| 2025-12-04 | Dodato PIN dugme na kartici putnika u mesecni_putnici_screen.dart |
| 2025-12-04 | Kreiran `putnik_cekanje_screen.dart` - ekran za čekanje odobrenja sa realtime |
| 2025-12-04 | Kreiran `dnevni_putnik_screen.dart` - ekran za zakazivanje vožnji |
| 2025-12-04 | Povezano: registracija → čekanje → odobren ekran |

