# 📋 PLAN ISPRAVKI - Nepostojeće kolone u bazi

**Datum:** 7. decembar 2025  
**Status:** U toku

---

## 🗄️ KOMPLETNA ŠEMA BAZE PODATAKA (STVARNO STANJE)

### PUTOVANJA_ISTORIJA tabela (17 kolona)
```
✅ id                  (UUID)
✅ mesecni_putnik_id   (UUID, nullable)
✅ datum_putovanja     (DATE)
✅ vreme_polaska       (TEXT)
✅ status              (TEXT)
✅ vozac_id            (UUID, nullable)
✅ napomene            (TEXT, nullable)
✅ obrisan             (BOOLEAN)
✅ created_at          (TIMESTAMP)
✅ updated_at          (TIMESTAMP)
✅ adresa_id           (UUID, nullable)
✅ cena                (DECIMAL)
✅ tip_putnika         (TEXT)
✅ putnik_ime          (TEXT)
✅ created_by          (UUID, nullable)
✅ action_log          (JSONB)
✅ grad                (TEXT, nullable)
✅ broj_telefona       (TEXT, nullable)
```

**❌ NE POSTOJE U PUTOVANJA_ISTORIJA:**
- ❌ `vreme_placanja`
- ❌ `placeno`
- ❌ `iznos_placanja`
- ❌ `adresa` (TEXT polje - samo `adresa_id` postoji)
- ❌ `vreme_pokupljenja`
- ❌ `vozac` (samo `vozac_id`)
- ❌ `pokupljen` (koristi se `status`)

---

### MESECNI_PUTNICI tabela (32 kolone)
```
✅ id, putnik_ime, tip, tip_skole
✅ broj_telefona, broj_telefona_oca, broj_telefona_majke
✅ polasci_po_danu, tip_prikazivanja, radni_dani
✅ aktivan, status
✅ datum_pocetka_meseca, datum_kraja_meseca
✅ ukupna_cena_meseca, cena
✅ broj_putovanja, broj_otkazivanja, poslednje_putovanje
✅ vreme_placanja, placeni_mesec, placena_godina
✅ vozac_id, pokupljen, vreme_pokupljenja
✅ statistics, obrisan
✅ created_at, updated_at, updated_by
✅ adresa_bela_crkva_id, adresa_vrsac_id
✅ napomena, action_log, dodali_vozaci
✅ placeno, datum_placanja
✅ pin, push_token, push_provider
```

---

### DNEVNI_PUTNICI tabela (17 kolona) - STARA TABELA
```
✅ id, putnik_ime, telefon, grad, broj_mesta
✅ datum_putovanja, vreme_polaska, cena, status
✅ vozac_id, obrisan, created_at, updated_at
✅ ruta_id, vozilo_id, adresa_id, created_by, action_log
```
**NAPOMENA:** Ova tabela se više ne koristi - sve ide u putovanja_istorija!

---

### VOZACI tabela (12 kolona)
```
✅ id, ime, email, telefon, aktivan
✅ created_at, updated_at, kusur
✅ obrisan, deleted_at, status, sifra
```

---

### ADRESE tabela (8 kolona)
```
✅ id, naziv, grad, ulica, broj
✅ koordinate, created_at, updated_at
```

---

### VOZAC_LOKACIJE tabela (12 kolona)
```
✅ id, vozac_id, vozac_ime, lat, lng
✅ grad, vreme_polaska, aktivan
✅ created_at, updated_at, smer, putnici_eta
```

---

### ZAKAZANE_VOZNJE tabela (9 kolona)
```
✅ id, putnik_id, datum, smena
✅ vreme_bc, vreme_vs, status, napomena
✅ created_at, updated_at
```

---

### KAPACITET_POLAZAKA tabela (8 kolona)
```
✅ id, grad, vreme, max_mesta
✅ aktivan, napomena, created_at, updated_at
```

---

### DAILY_CHECKINS tabela (11 kolona)
```
✅ id, vozac, datum, sitan_novac
✅ dnevni_pazari, ukupno, checkin_vreme
✅ created_at, updated_at, obrisan, deleted_at, status
```

---

### ZAHTEVI_PRISTUPA tabela (13 kolona)
```
✅ id, ime, prezime, email, telefon
✅ adresa, grad, tip_putnika, podtip
✅ poruka, status, created_at
✅ processed_at, processed_by
```

---

### DNEVNI_PUTNICI_REGISTROVANI tabela (12 kolona)
```
✅ id, ime, prezime, telefon, adresa
✅ grad, status, zahtev_id
✅ pin, push_token, push_provider
✅ created_at, updated_at
```

---

## 🔴 GREŠKE ZA ISPRAVKU

### 1. putnik_service.dart - undoLastAction() 'delete' case
**Lokacija:** Linija ~627  
**Problem:** Koristi `'pokupljen': false` za putovanja_istorija  
**Ispravka:** Ukloniti `pokupljen` - putovanja_istorija koristi samo `status`

```dart
// POGREŠNO:
await supabase.from(tabela).update({
  'status': lastAction.oldData['status'] ?? 'radi',
  'pokupljen': false, // ❌ NE POSTOJI
}).eq('id', lastAction.putnikId as String);

// ISPRAVNO:
await supabase.from(tabela).update({
  'status': lastAction.oldData['status'] ?? 'radi',
}).eq('id', lastAction.putnikId as String);
```

---

### 2. putnik_service.dart - undoLastAction() 'payment' case
**Lokacija:** Linija ~654-660  
**Problem:** Koristi `placeno`, `iznos_placanja`, `vreme_placanja` za putovanja_istorija  
**Ispravka:** Koristiti samo `cena` i `status`

```dart
// POGREŠNO:
await supabase.from(tabela).update({
  'placeno': false,           // ❌ NE POSTOJI
  'iznos_placanja': null,     // ❌ NE POSTOJI
  'vreme_placanja': null,     // ❌ NE POSTOJI
  'status': lastAction.oldData['status'],
}).eq('id', lastAction.putnikId as String);

// ISPRAVNO:
await supabase.from(tabela).update({
  'cena': 0,
  'status': lastAction.oldData['status'] ?? 'radi',
}).eq('id', lastAction.putnikId as String);
```

---

### 3. putnik_service.dart - undoLastAction() 'cancel' case
**Lokacija:** Linija ~670-674  
**Problem:** Koristi `'vozac': lastAction.oldData['vozac']` za putovanja_istorija  
**Ispravka:** Ukloniti `vozac` - koristi se samo `vozac_id` (ako treba)

```dart
// POGREŠNO:
await supabase.from(tabela).update({
  'status': lastAction.oldData['status'],
  'vozac': lastAction.oldData['vozac'], // ❌ NE POSTOJI
}).eq('id', lastAction.putnikId as String);

// ISPRAVNO:
await supabase.from(tabela).update({
  'status': lastAction.oldData['status'] ?? 'radi',
}).eq('id', lastAction.putnikId as String);
```

---

### 4. putnik_service.dart - otkaziPutnika() INSERT
**Lokacija:** Linija ~1383  
**Problem:** Koristi `'adresa': adresa` TEXT polje koje ne postoji  
**Ispravka:** Koristiti samo `adresa_id` ili staviti u `napomene`

```dart
// POGREŠNO:
await supabase.from('putovanja_istorija').insert({
  ...
  'adresa': adresa, // ❌ NE POSTOJI
  'adresa_id': adresaId,
  ...
});

// ISPRAVNO:
await supabase.from('putovanja_istorija').insert({
  ...
  'adresa_id': adresaId,
  'napomene': adresa != null ? 'Adresa: $adresa' : null,
  ...
});
```

---

### 5. putnik_service.dart - oznaciPlaceno() za putovanja_istorija
**Lokacija:** Linija ~1293-1299  
**Problem:** Koristi `'vreme_placanja'` koje ne postoji u putovanja_istorija  
**Status:** ✅ PROVERITI - možda je OK ako koristi action_log

```dart
// TRENUTNO:
await supabase.from(tabela).update({
  'cena': iznos,
  'vozac_id': validVozacId,
  'vreme_placanja': DateTime.now().toIso8601String(), // ❌ MOŽDA NE POSTOJI
  'action_log': updatedActionLog2.toJson(),
  'status': 'placeno',
}).eq('id', id as String);

// ISPRAVNO:
await supabase.from(tabela).update({
  'cena': iznos,
  'vozac_id': validVozacId,
  'action_log': updatedActionLog2.toJson(),
  'status': 'placeno',
  'updated_at': DateTime.now().toIso8601String(),
}).eq('id', id as String);
```

---

## ✅ REDOSLED ISPRAVKI

| # | Fajl | Funkcija | Linija | Problem | Status |
|---|------|----------|--------|---------|--------|
| 1 | putnik_service.dart | undoLastAction - delete | 627 | `pokupljen` ne postoji u putovanja_istorija | ✅ DONE |
| 2 | putnik_service.dart | undoLastAction - payment | 655-658 | `placeno`, `iznos_placanja`, `vreme_placanja` ne postoje | ✅ DONE |
| 3 | putnik_service.dart | undoLastAction - cancel | 673 | `vozac` ne postoji (samo vozac_id) | ✅ DONE |
| 4 | putnik_service.dart | otkaziPutnika - INSERT | 1382 | `adresa` TEXT ne postoji (samo adresa_id) | ✅ DONE |
| 5 | putnik_service.dart | oznaciPlaceno | 1296 | `vreme_placanja` ne postoji u putovanja_istorija | ✅ DONE |

### VERIFIKOVANO KAO OK:
- ✅ mesecni_putnik_service.dart INSERT - koristi samo postojeće kolone
- ✅ putovanja_istorija_service.dart - koristi toMap() koji je ispravan
- ✅ putnik.dart toPutovanjaIstorijaMap() - ne koristi problematične kolone
- ✅ oznaciPokupljen za putovanja_istorija - koristi samo `status` i `action_log`
- ✅ undoLastAction 'pickup' za putovanja_istorija - koristi samo `status`
- ✅ Sve operacije za mesecni_putnici - koriste postojeće kolone

### ANALIZA PO TIPU PUTNIKA:

#### MESEČNI PUTNICI (mesecni_putnici tabela):
- ✅ undoLastAction delete: `status`, `aktivan` - OK
- ✅ undoLastAction pickup: `broj_putovanja`, `pokupljen`, `vreme_pokupljenja` - OK  
- ✅ undoLastAction payment: `cena`, `vreme_placanja`, `vozac_id` - OK
- ✅ undoLastAction cancel: `status` - OK
- ✅ oznaciPokupljen: `vreme_pokupljenja`, `pokupljen`, `vozac_id`, `action_log`, `updated_at` - OK
- ✅ oznaciPlaceno: `cena`, `vreme_placanja`, `vozac_id`, `action_log`, `updated_at` - OK

#### DNEVNI PUTNICI (putovanja_istorija tabela):
- ❌ undoLastAction delete: koristi `pokupljen` koje NE POSTOJI
- ✅ undoLastAction pickup: koristi samo `status` - OK
- ❌ undoLastAction payment: koristi `placeno`, `iznos_placanja`, `vreme_placanja` koje NE POSTOJE
- ❌ undoLastAction cancel: koristi `vozac` koje NE POSTOJI
- ✅ oznaciPokupljen: koristi `status`, `action_log` - OK
- ❌ oznaciPlaceno: koristi `vreme_placanja` koje NE POSTOJI
- ❌ otkaziPutnika INSERT: koristi `adresa` TEXT koje NE POSTOJI

---

## 📝 NAPOMENE

1. **action_log** se koristi za čuvanje informacija o akcijama (ko je platio, pokupljen, otkazao) - to je ispravno
2. **status** kolona u putovanja_istorija se koristi umesto boolean flag-ova (`pokupljen`, `placeno`, `otkazan`)
3. **vozac_id** je UUID referenca na vozaci tabelu - nikada ne čuvati ime vozača direktno
4. **adresa_id** je UUID referenca na adrese tabelu - `adresa` TEXT kolona ne postoji

---

## 🔄 NAKON ISPRAVKI

1. Pokrenuti `flutter analyze` da proveri da nema grešaka
2. Testirati sve akcije na kartici putnika:
   - ✅ Pokupljanje
   - ✅ Plaćanje
   - ✅ Otkazivanje
   - ✅ Brisanje
   - ✅ Undo sve akcije
3. Proveriti da li se podaci ispravno čuvaju u bazi
