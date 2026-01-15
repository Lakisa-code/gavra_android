# VS Zahtev Sistem - Lista Čekanja (Rush Hour)

## 🎯 Cilj
Optimizacija popunjenosti vozila u "Rush Hour" terminima (13:00, 14:00, 15:30).
Umesto odbijanja putnika kada je kombi pun, sistem treba da ih skuplja na listu čekanja. Kada se skupi dovoljno (3-4), šalje se drugi kombi.

---

## 🚦 Algoritam (Logic Flow)

### 1. Zahtev (Korisnik bira termin)
- Korisnik bira VS termin (npr. 14:00).
- Sistem stavlja status `pending` i pokreće timer **10 minuta**.
- Korisnik dobija poruku: *"⏳ VS Zahtev primljen, provera za 10 min..."*

### 2. Provera (Nakon 10 minuta)
Sistem proverava slobodna mesta (`SlobodnaMestaService`).

#### ✅ SCENARIO 1: Ima slobodnih mesta
- Kapacitet nije popunjen.
- Status prelazi u `confirmed`.
- Notifikacija: *"✅ VS Zahtev potvrđen!"*

#### 🔵 SCENARIO 2: Nema mesta - Rush Hour (13:00, 14:00, 15:30)
- Kapacitet je popunjen, ali je termin **špic**.
- Status prelazi u `ceka_mesto`.
- Prikaz u aplikaciji: **Plava boja** (ikona sata).
- Notifikacija: *"⏳ Zahtev u obradi. Vaš zahtev za 14:00 se obrađuje. Dobićete odgovor uskoro."*
- **Rezultat:** Putnik traži ISTI termin.

#### ❌ SCENARIO 3: Nema mesta - Van špica (npr. 11:00)
- Kapacitet je popunjen, termin nije kritičan.
- Status prelazi u `null` (odbijen).
- Notifikacija: *"❌ Nema mesta za 11:00. Slobodni termini: 10:00, 12:00"*.
- Ponuđene **alternative** (termin pre/posle).

---

## 📊 Statusi u bazi

| Status (`vs_status`) | Značenje | Boja u app | Logika |
|----------------------|----------|------------|--------|
| `pending`            | Čeka 10 min proveru | 🟠 Narandžasta | Timer aktivan |
| `confirmed`          | Potvrđeno mesto | (standard) | Zauzima 1 mesto |
| `ceka_mesto`         | Lista čekanja (2. kombi) | 🔵 Plava | **Ne zauzima** 1. kombi, skuplja se za 2. |
| `null`               | Odbijen / Nema zahteva | - | Nije prošao proveru |

---

## ⚙️ Tehnička implementacija

### `SlobodnaMestaService`
- Dodat property `waitingCount`.
- `_countPutniciZaPolazak` NE broji putnike sa statusom `ceka_mesto`.
- `_countWaitingZaPolazak` broji ISKLJUČIVO `ceka_mesto` putnike.

### `RegistrovaniPutnikProfilScreen`
- `_confirmVsZahtev`:
  - Ako `!imaMesta && isRushHour` -> `ceka_mesto`.
  - Ako `!imaMesta && !isRushHour` -> Alternative logic.

### `TimePickerCell`
- Added support for `waiting` status (blue indicator).
