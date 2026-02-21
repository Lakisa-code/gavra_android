# Plan refaktorisanja: UUID-based vozač identifikacija

## Problem (tačna dijagnoza)

### Korijen zla: `VozacBoja.getSync(String? ime)` baca Exception ako ime nije tačno

```dart
// vozac_boja.dart:149
static Color getSync(String? ime) {
  if (ime != null && _cachedBoje.containsKey(ime)) {
    return _cachedBoje[ime]!;
  }
  throw ArgumentError('Vozač "$ime" nije registrovan...');
}
```

Svako mjesto koje pozove `getSync` s null ili netačnim stringom ruši app.

### Sva mjesta koja pozivaju `getSync` (20 ukupno):
| Fajl | Linija | Rizik |
|------|--------|-------|
| `putnik_card.dart` | 1459, 1471, 1485 | VISOK — dolazi iz RPC/loga |
| `dodeli_putnike_screen.dart` | 355, 394, 559, 576, 708, 753, 1006, 1062 | SREDNJI — dolazi iz liste |
| `home_screen.dart` | 2175 | NIZAK — `_currentDriver` je logovan vozač |
| `vozac_screen.dart` | 1346 | NIZAK — `previewAsDriver` je iz liste |
| `vozac_action_log_screen.dart` | 71, 165 | NIZAK — `widget.vozacIme` je iz navigacije |
| `registrovani_putnici_screen.dart` | 1666 | SREDNJI |
| `popis_service.dart` | 137 | SREDNJI |
| `bottom_nav_bar_zimski/letnji/praznici.dart` | 223, 219, 214 | NIZAK — iz `vreme_vozac` cache-a |

---

## Stanje baze podataka

### `vozaci` tabela:
```
id (uuid, PK) | ime (text, NOT NULL) | boja (text) | email | telefon | sifra
```
- 4 vozača: Bilevski, Bojan, Bruda, Voja
- **`boja` je hex string** npr. `#FF9800`, ali `Voja` ima `ffd700` (bez #!) — bug u bazi

### `voznje_log` tabela:
- `vozac_id uuid FK → vozaci.id`
- `vozac_ime text` (redundantno — denormalizovano za brzinu čitanja)
- **98 zapisa** imaju `vozac_id != null` ali `vozac_ime = null` (historijski podaci bez imena)
- **25 zapisa** imaju oba null (anonimine akcije — putnik sam otkazao, itd.)

### `seat_requests` tabela:
- Nema `vozac_id` kolone — vozač se nigdje ne čuva direktno uz zahtjev
- `cancelled_by text` — ime vozača koji je otkazao (nedavno dodato)

### `vreme_vozac` tabela:
- `vozac_ime text` — termin → vozač mapiranje (sve po imenu)

---

## Arhitekturalni problemi (ranked by severity)

### 🔴 KRITIČNO

**1. `getSync` baca Exception na null/nepoznato ime**
- Ne smije bacati exception u build metodi — Flutter crash
- Mjesta: sva 20 lokacija gore

**2. 98 starih log zapisa nemaju `vozac_ime`**
- RPC vraća `pokupioVozac/naplatioVozac/otkazaoVozac = null` za te datume
- `putnik_card.dart` poziva `getSync(null)` → crash

**3. `vreme_vozac` tabela čuva `vozac_ime` string, ne UUID**
- Bottom nav bar koristi to ime direktno za `getSync`
- Ako se vozaču promijeni ime → sve boje puknu

### 🟡 SREDNJE

**4. Dvostruki in-memory cache sistemi koji se ne sinhronizuju**
- `VozacBoja._cachedBoje` (ime → Color)
- `VozacBoja._cachedBojeUuid` (uuid → Color)
- `VozacMappingService._vozacNameToUuid` (ime → uuid)
- `VozacMappingService._vozacUuidToName` (uuid → ime)
- `VozacMappingService._vozacUuidToColor` (uuid → hex)
- `VremeVozacService._cache` (grad|vreme|dan → ime)
- Svi se inicijalizuju odvojeno, mogu biti out of sync

**5. `Vozac.color` parsira hex bez `#` podrške**
- Voja ima `ffd700` (bez #) → `Color(int.parse('FFffd700'))` = works by accident
- Ako se `#ffd700` unese → `int.parse('FF#ffd700')` = crash

**6. `voznje_log.vozac_ime` je denormalizovana kopija**
- Ako se promijeni ime vozača u `vozaci` tabeli, svi historijski logovi imaju staro ime
- Kod to koristi za display i za boju lookup

### 🟢 MANJE VAŽNO

**7. `logGeneric` radi async DB query za `vozac_ime` pri svakom logu**
- Svaki `logGeneric` poziv → `SELECT ime FROM vozaci WHERE id = ?`
- Mogli bi koristiti cache

**8. `getVozacUuid` u `VozacMappingService` je async ali `getVozacUuidSync` može vratiti null**
- `otkaziPutnika` async-no dohvata UUID pa poziva `logGeneric`
- Ako `VozacMappingService` nije inicijalizovan → `vozacUuid = null`

---

## Plan refaktorisanja (3 opcije)

---

### Opcija A — MINIMALNI FIX (1-2h)
**Cilj: Eliminisati crashove bez arhitekturalnih promjena**

1. **`getSync` → ne baca exception, vraća fallback boju**
   ```dart
   static Color getSync(String? ime, {Color fallback = Colors.grey}) {
     if (ime == null || ime.isEmpty) return fallback;
     return _cachedBoje[ime] ?? _cachedBojeUuid[ime] ?? fallback;
   }
   ```

2. **Popraviti 98 starih log zapisa u bazi** (1 SQL query):
   ```sql
   UPDATE voznje_log vl SET vozac_ime = v.ime
   FROM vozaci v WHERE vl.vozac_id = v.id AND vl.vozac_ime IS NULL;
   ```

3. **Popraviti Voja boju** (dodati `#`):
   ```sql
   UPDATE vozaci SET boja = '#ffd700' WHERE ime = 'Voja';
   ```

**Rezultat:** Nema više crashova. Sistem ostaje prljav ali stabilan.

---

### Opcija B — ČIŠĆENJE (1-2 dana)
**Cilj: Jedan cache sistem, UUID kao identifikator svuda gdje je moguće**

Pored svih promjena iz Opcije A, dodatno:

1. **Spojiti `VozacBoja` i `VozacMappingService` u jedan `VozacCache` singleton**
   - Jedan `initialize()` call
   - Expose: `getColorByIme()`, `getColorByUuid()`, `getImeByUuid()`, `getUuidByIme()`

2. **`getSync` prihvata i ime i UUID**
   - Već postoji `getColorOrDefaultSync(identifikator)` — jednostavno rename i make default

3. **`putnik_card.dart` koristi `pokupioVozacId` (UUID) za boju ako je dostupan**
   - RPC proširiti da vraća i `pokupioVozacId`, `naplatioVozacId`, `otkazaoVozacId`
   - Fallback na ime ako UUID nije dostupan

4. **`vreme_vozac` tabela — dodati `vozac_id uuid` kolonu**
   - Bottom nav bar čita UUID, koristi za boju
   - `vreme_vozac_service` čuva i ime i UUID u cache-u

5. **DB cleanup: `voznje_log` trigger koji automatski puni `vozac_ime` iz `vozaci`**
   ```sql
   CREATE OR REPLACE FUNCTION sync_vozac_ime()
   RETURNS TRIGGER AS $$
   BEGIN
     IF NEW.vozac_id IS NOT NULL AND NEW.vozac_ime IS NULL THEN
       SELECT ime INTO NEW.vozac_ime FROM vozaci WHERE id = NEW.vozac_id;
     END IF;
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;
   ```

**Rezultat:** Jedna tačka istine za vozač data, UUID kao primarni identifikator, robustno.

---

### Opcija C — PUNO ČISTO (3-5 dana)
**Sve iz B, plus:**

1. `seat_requests` dobija `vozac_id uuid FK` kolonu (ko je dodeljen terminu)
2. `vreme_vozac` radi samo s UUID-ovima
3. `cancelled_by` mijenja se u `cancelled_by_vozac_id uuid FK`
4. `logGeneric` ne radi DB query za ime — koristi `VozacCache`
5. Sve `getSync` pozive zamijeniti sa `getColorByUuid` tamo gdje imamo UUID

**Rezultat:** Potpuno čist sistem. Promjena imena vozača ne remeti ništa.

---

## Preporuka

**Uradi odmah:** SQL fix za 98 zapisa + `getSync` bez exception-a (30 min)

**Ove sedmice:** Opcija B — spoji cacheove, UUID u putnik_card (ne mijenja bazu dramatično)

**Opcija C** — samo ako planiraš dodavati nove vozače ili mjenjati imena

---

## TODO lista

### HITNO (rade se odmah)
- [ ] SQL: `UPDATE voznje_log SET vozac_ime = v.ime FROM vozaci v WHERE vozac_id = v.id AND vozac_ime IS NULL`
- [ ] SQL: `UPDATE vozaci SET boja = '#ffd700' WHERE ime = 'Voja'`
- [ ] `getSync()` — ukloniti `throw`, vratiti fallback boju

### Opcija B (1-2 dana)
- [ ] Kreirati `VozacCache` koji zamjenjuje `VozacBoja` + `VozacMappingService`
- [ ] RPC proširiti: dodati `pokupioVozacId`, `naplatioVozacId`, `otkazaoVozacId` UUID polja
- [ ] `putnik_card.dart`: koristiti UUID za boju lookup
- [ ] `vreme_vozac` tabela: dodati `vozac_id` kolonu
- [ ] `vreme_vozac_service.dart`: čuvati i UUID u cache-u
- [ ] DB trigger: `sync_vozac_ime` na `voznje_log INSERT`
- [ ] `logGeneric`: koristiti `VozacCache` umesto async DB query

### Opcija C (3-5 dana, opcionalno)
- [ ] `seat_requests`: dodati `vozac_id uuid FK` kolonu
- [ ] `cancelled_by` → `cancelled_by_vozac_id uuid FK`
- [ ] Migracija svih `getSync(ime)` → `getColorByUuid(uuid)` poziva
