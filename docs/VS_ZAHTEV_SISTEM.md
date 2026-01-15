# VS Zahtev Sistem - Lista Čekanja (Rush Hour)

## 🎯 Cilj
Optimizacija popunjenosti vozila u "Rush Hour" terminima (13:00, 14:00, 15:30).
Umesto odbijanja putnika kada je kombi pun, sistem treba da ih skuplja na listu čekanja. Kada se skupi dovoljno (**4 zahteva**), šalje se drugi kombi.

---

## 🚦 Algoritam (Logic Flow)

### 1. Zahtev (Korisnik bira termin)
- Korisnik bira VS termin (npr. 14:00).
- Sistem stavlja status `pending` i pokreće timer **10 minuta**.
- Korisnik dobija poruku: *"✅ Zahtev je uspešno primljen i biće obrađen u najkraćem mogućem roku."*

### 2. Provera (Nakon 10 minuta)
Sistem proverava slobodna mesta (`SlobodnaMestaService`).

#### ✅ SCENARIO 1: Ima slobodnih mesta
- Kapacitet nije popunjen.
- Status prelazi u `confirmed`.
- Notifikacija: *"✅ Zahtev potvrđen. Vaš povratak u 14:00 je potvrđen. Vidimo se!"*

#### 🔵 SCENARIO 2: Nema mesta - Rush Hour (13:00, 14:00, 15:30)
- Kapacitet je popunjen, ali je termin **špic**.
- Status prelazi u `ceka_mesto`.
- Prikaz u aplikaciji: **Plava boja** (ikona sata).

**Sistem proverava 3 uslova:**

##### 2A. Ima 4+ zahteva na čekanju
- **Aktivira se drugi kombi!**
- Svi putnici na listi dobijaju status `confirmed`.
- Notifikacija svima: *"✅ Zahtev potvrđen. Vaš povratak u 14:00 je potvrđen. Vidimo se!"*

##### 2B. Nema 4 zahteva, ALI ima slobodna alternativa
- Notifikacija sa ponudom: *"Obrađuje se zahtev. Imate alternativu u 13:00."*
- Akcije: **[✅ 13:00]** **[⏳ Sačekaj 14:00]**
- Ako prihvati alternativu → `confirmed` za taj termin
- Ako sačeka → ostaje `ceka_mesto`

##### 2C. Nema 4 zahteva, NEMA alternativa
- Notifikacija: *"⏳ Zahtev i dalje u obradi. Obavestićemo vas čim se situacija promeni."*
- Ostaje `ceka_mesto` i čeka da se ili skupi 4, ili da neko otkaže

#### ❌ SCENARIO 3: Nema mesta - Van špica (npr. 11:00)
- Kapacitet je popunjen, termin nije kritičan.
- Status prelazi u `null` (odbijen).
- Notifikacija sa alternativama.

---

## 🔔 Realtime: Kada se oslobodi mesto

Kada neko **otkaže** VS Rush Hour termin:
1. Sistem detektuje otkazivanje
2. Pronalazi sve putnike sa `ceka_mesto` za taj termin
3. **Sortira po FIFO** - ko se prvi prijavio, prvi dobija ponudu
4. Šalje im notifikaciju sa ponudom: *"Oslobodilo se mesto. Imate alternativu u X:XX."*
5. Putnik može prihvatiti ili nastaviti da čeka željeni termin

### 📋 FIFO Redosled
- Kada putnik dobije `ceka_mesto` status, čuva se `vs_ceka_od` timestamp
- Prilikom slanja notifikacija, lista se sortira po ovom timestampu
- **Ko se prvi prijavio → prvi dobija ponudu**

---

## 📊 Statusi u bazi

| Status (`vs_status`) | Značenje | Boja u app | Logika |
|----------------------|----------|------------|--------|
| `pending`            | Čeka 10 min proveru | 🟠 Narandžasta | Timer aktivan |
| `confirmed`          | Potvrđeno mesto | ✅ Zelena | Zauzima 1 mesto |
| `ceka_mesto`         | Lista čekanja (2. kombi) | 🔵 Plava | **Ne zauzima** 1. kombi, skuplja se za 2. |
| `waiting`            | Čeka oslobođeno mesto | 🔵 Plava | Alternativa ceka_mesto |
| `null`               | Odbijen / Nema zahteva | - | Nije prošao proveru |

---

## ⚙️ Tehnička implementacija

### `SlobodnaMestaService`
- `waitingCount` property za broj na čekanju
- `brojCekaMestoZaVsTermin(vreme, dan)` - broji putnike koji čekaju
- `potvrdiSveCekaMestoZaVsTermin(vreme, dan)` - potvrđuje sve kada ima 4+
- `dohvatiCekaMestoZaVsTermin(vreme, dan)` - vraća listu ID-jeva

### `RegistrovaniPutnikProfilScreen`
- `_confirmVsZahtev`:
  1. Proveri ima li mesta → `confirmed`
  2. Rush Hour? → `ceka_mesto` + proveri broj zahteva
  3. 4+ zahteva? → Potvrdi sve
  4. Ima alternativa? → Ponudi
  5. Ništa? → "I dalje u obradi"
- `_notifyWaitingPassengers(vreme, dan)` - obaveštava sve na čekanju kada neko otkaže

### `LocalNotificationService`
- `showVsAlternativeNotification` sa `isRushHourWaiting` flag
- `_handleVsZadrziAction` - potvrđuje čekanje
- `_handleVsCekajAction` - prelazi u waiting status

### `TimePickerCell`
- Podrška za `waiting` i `ceka_mesto` status (plava boja)
