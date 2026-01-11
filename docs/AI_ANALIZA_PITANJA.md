# 🚐 Smart Seat Management - FINALNI DOGOVOR

## Problem
- ~100 putnika dnevno
- Fiksni putnici: uvek isto vreme (u `polasci_po_danu` imaju vreme)
- Fleksibilni putnici: nemaju fiksno vreme (`"vs": null` u JSON-u)
- Svi koji odu ujutru iz BC MORAJU se vratiti (sužen krug)
- Kapacitet kombija: 8 mesta

## Rešenje - Algoritam

### Input
- Admin postavi MAX kapacitet po terminu (već postoji u `kapacitet_polazaka`)
- Fiksni putnici već imaju termine u `polasci_po_danu`
- Fleksibilni putnici šalju zahteve (NOVA tabela `seat_requests`)

### Logika
```
1. Fleksibilan putnik traži vreme (npr. VS 14:00)
2. Sistem proverava: ima li mesta?
   - DA → odobri (status = approved)
   - NE → ponudi najbliže slobodno vreme
3. Putnik:
   - Prihvati alternativu → rezervisano
   - Odbije → lista čekanja (status = waitlist)
4. OPTIMIZACIJA: algoritam predlaže preraspodelu da minimizuje kombije
5. Kad se oslobodi mesto → push notifikacija putnicima na listi čekanja
```

### Primer optimizacije
```
ZAHTEVI:               ALGORITAM OPTIMIZUJE:
13:00 → 9 ljudi        13:00 → 8 (1 kombi)
14:00 → 18 ljudi   →   14:00 → 16 (2 kombija)  
15:30 → 7 ljudi        15:30 → 10 (2 kombija)

Prebaci 1 iz 13:00 u 14:00
Prebaci 3 iz 14:00 u 15:30
REZULTAT: 5 kombija umesto 6 = UŠTEDA
```

### Pravila
- Deadline za zahtev: 10 min pre polaska
- Admin postavlja MAX kapacitet (gornju granicu)
- Algoritam optimizuje broj kombija
- Fleksibilni se preraspoređuju, fiksni NE

---

## 📊 ANALIZA BAZE

### Postojeće tabele
| Tabela | Svrha | Status |
|--------|-------|--------|
| `kapacitet_polazaka` | MAX mesta po terminu | ✅ Već postoji |
| `registrovani_putnici` | Putnici + `polasci_po_danu` | ✅ Već postoji |
| `registrovani_putnici.polasci_po_danu` | JSON sa vremenima | ✅ Fiksni=vreme, Fleksibilni=null |

### Nova tabela: `seat_requests`
```sql
CREATE TABLE seat_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  putnik_id UUID NOT NULL REFERENCES registrovani_putnici(id),
  grad TEXT NOT NULL CHECK (grad IN ('BC', 'VS')),
  datum DATE NOT NULL,
  zeljeno_vreme TEXT NOT NULL,
  dodeljeno_vreme TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'waitlist', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  UNIQUE(putnik_id, grad, datum) -- jedan zahtev po putniku/gradu/danu
);
```

---

## 📋 TODO LISTA - IMPLEMENTACIJA

### FAZA 1: Baza podataka ✅ ZAVRŠENO
- [x] 1.1 Kreirati tabelu `seat_requests` ✅
- [x] 1.2 Dodati RLS politike (Row Level Security) ✅
- [x] 1.3 Kreirati indekse za brže pretrage ✅
- [x] 1.4 Omogućiti Realtime ✅

### FAZA 2: Backend servis (Dart) ✅ ZAVRŠENO
- [x] 2.1 Kreirati `seat_request_service.dart` - CRUD za zahteve ✅
- [x] 2.2 Kreirati `seat_optimization_service.dart` - algoritam optimizacije ✅
- [x] 2.3 Dodati metodu za proveru slobodnih mesta ✅ (checkAvailability)
- [x] 2.4 Dodati metodu za predlaganje alternativa ✅ (findAlternatives)
- [x] 2.5 Dodati metodu za optimizaciju rasporeda ✅ (optimize, applyOptimization)
- [x] 2.6 Integracija sa postojećim `kapacitet_service.dart` ✅

### FAZA 3: UI - Putnik ✅ ZAVRŠENO
- [x] 3.1 Widget za slanje zahteva (izbor vremena) ✅ `seat_request_widget.dart`
- [x] 3.2 Prikaz statusa zahteva (pending/approved/waitlist) ✅
- [x] 3.3 Otkazivanje zahteva ✅
- [ ] 3.4 Push notifikacija kad se oslobodi mesto

### FAZA 4: UI - Admin ✅ ZAVRŠENO
- [x] 4.1 Dashboard sa pregledom svih zahteva po terminu ✅ `seat_management_screen.dart`
- [x] 4.2 Vizualizacija popunjenosti (progress bar) ✅
- [x] 4.3 Dugme "Optimizuj raspored" ✅
- [x] 4.4 Pregled predloga optimizacije ✅ `seat_optimization_widget.dart`
- [x] 4.5 Odobrenje/korekcija rasporeda ✅
- [x] 4.6 Navigacija iz Admin menija ✅

### FAZA 5: Testiranje i fine-tuning
- [ ] 5.1 Testiranje sa realnim podacima
- [ ] 5.2 Fine-tuning algoritma
- [ ] 5.3 Performance optimizacija
- [ ] 5.4 Edge cases (deadline, puno sve, itd.)

---

## 🕐 PROCENA VREMENA

| Faza | Procena |
|------|---------|
| Faza 1 (Baza) | 30 min |
| Faza 2 (Servis) | 2-3 sata |
| Faza 3 (UI Putnik) | 2-3 sata |
| Faza 4 (UI Admin) | 2-3 sata |
| Faza 5 (Test) | 1-2 sata |
| **UKUPNO** | **~10 sati** |

---

## ✅ STATUS

- [x] Dogovor finalizovan - 11. januar 2026.
- [x] Analiza baze završena
- [x] Plan implementacije napravljen
- [x] **FAZA 1 ZAVRŠENA** - Tabela `seat_requests` kreirana ✅
  - Tabela kreirana sa svim kolonama
  - RLS politike dodate (SELECT, INSERT, UPDATE, DELETE)
  - Indeksi kreirani (datum, grad_vreme, status, putnik)
  - Realtime uključen
  - Trigger za auto updated_at
- [ ] **SLEDEĆI KORAK: Faza 2.1 - Kreirati `seat_request_service.dart`**

---

## 📅 LOG PROMENA

| Datum | Vreme | Akcija | Status |
|-------|-------|--------|--------|
| 2026-01-11 | - | Dogovor finalizovan | ✅ |
| 2026-01-11 | - | Kreirana tabela `seat_requests` | ✅ |
| 2026-01-11 | - | Dodate RLS politike | ✅ |
| 2026-01-11 | - | Kreiran indeksi + realtime | ✅ |

---

## 📝 BELEŠKE

### Kako detektovati fleksibilnog putnika:
```dart
// U polasci_po_danu JSON:
// Fiksni:      {"pon": {"bc": "06:00", "vs": "14:00"}}
// Fleksibilan: {"pon": {"bc": "06:00", "vs": null}}

bool isFleksibilan(Map<String, dynamic> polasciPoDanu, String dan, String smer) {
  final danData = polasciPoDanu[dan];
  if (danData == null) return true; // nema podatke = fleksibilan
  return danData[smer] == null;
}
```

### Vremena polazaka (iz baze):
**BC:** 5:00, 6:00, 7:00, 8:00, 9:00, 11:00, 12:00, 13:00, 14:00, 15:00, 15:30, 18:00
**VS:** 6:00, 7:00, 8:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:30, 17:00, 19:00
