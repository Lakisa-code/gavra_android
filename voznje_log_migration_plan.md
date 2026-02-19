# Plan Migracije Tabele `voznje_log` - Prelazak sa JSONB na Obične Kolone

**Datum analize:** 19. februar 2026  
**Analizirano redova:** 2,804  
**Veličina tabele:** 640 kB

---

## 📊 TRENUTNO STANJE TABELE

### Postojeće Kolone
| Kolona | Tip | Nullable | Default | Svrha |
|--------|-----|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primarni ključ |
| putnik_id | uuid | YES | null | Referenca na putnika |
| datum | date | YES | null | Datum vožnje/događaja |
| tip | text | YES | null | Tip log zapisa |
| iznos | numeric | YES | null | Novčani iznos |
| vozac_id | uuid | YES | null | Referenca na vozača |
| created_at | timestamp with time zone | YES | now() | Vreme kreiranja |
| placeni_mesec | integer | YES | null | Mesec plaćanja |
| placena_godina | integer | YES | null | Godina plaćanja |
| sati_pre_polaska | integer | YES | null | Sati pre polaska |
| broj_mesta | integer | YES | 1 | Broj mesta |
| detalji | text | YES | null | Tekstualni detalji |
| **meta** | **jsonb** | YES | null | **JSONB kolona za migraciju** |
| tip_placanja | text | YES | null | Tip plaćanja |
| status | text | YES | null | Status |

---

## 🔍 ANALIZA JSONB KOLONE `meta`

### Distribucija Tipova Log Zapisa
| Tip | Ukupno | Sa meta | Bez meta | % sa meta |
|-----|--------|---------|----------|-----------|
| voznja | 1,063 | 153 | 910 | 14.4% |
| promena_statusa | 736 | 0 | 736 | 0% |
| prijava | 344 | 0 | 344 | 0% |
| zakazivanje_putnika | 161 | 161 | 0 | 100% |
| potvrda_mesta | 147 | 0 | 147 | 0% |
| otkazivanje | 128 | 7 | 121 | 5.5% |
| nedeljni_reset | 56 | 0 | 56 | 0% |
| uplata_dnevna | 51 | 0 | 51 | 0% |
| uplata_mesecna | 46 | 0 | 46 | 0% |
| otkazivanje_putnika | 21 | 0 | 21 | 0% |
| admin_akcija | 15 | 0 | 15 | 0% |
| uplata | 13 | 7 | 6 | 53.8% |
| odobravanje_mesta | 8 | 0 | 8 | 0% |
| reset_kartice | 7 | 0 | 7 | 0% |
| greska_zahteva | 6 | 6 | 0 | 100% |
| odsustvo | 2 | 0 | 2 | 0% |

**Ukupno sa meta podacima:** 334 od 2,804 (11.9%)

### Identifikovani Ključevi u `meta` JSONB Koloni

#### 1. **zakazivanje_putnika** (161 zapisa - 100% koristi meta)
```json
{
  "dan": "pon|uto|sre|cet|pet|sub|ned",
  "grad": "bc|vs",
  "vreme": "HH:MM",
  "adresa_id": "uuid",
  "datum": "YYYY-MM-DD",
  "adresa": "string",
  "broj_telefona": "string",
  "tip_putnika": "string"
}
```

#### 2. **voznja** (153 od 1,063 koriste meta - 14.4%)
```json
{
  "grad": "bc|vs",
  "vreme": "HH:MM"
}
```

#### 3. **otkazivanje** (7 od 128 koriste meta - 5.5%)
```json
{
  "grad": "bc|vs",
  "vreme": "HH:MM"
}
```

#### 4. **uplata** (7 od 13 koriste meta - 53.8%)
```json
{
  "grad": "bc|vs",
  "vreme": "HH:MM"
}
```

#### 5. **greska_zahteva** (6 zapisa - 100% koristi meta)
```json
{
  "ime": "Ime Prezime",
  "tip": "radnik|dnevni",
  "context": "RegistrovaniPutnikDialog_save"
}
```

---

## 🎯 PREDLOG ZA MIGRACIJU

### Strategija: **Ekstraktovanje Zajedničkih Polja**

Identifikovani su sledeći zajednički podaci u `meta` koloni:
- **grad** - koristi se u 4 različita tipa (voznja, zakazivanje_putnika, otkazivanje, uplata)
- **vreme** - koristi se u 4 različita tipa
- **dan** - koristi se u zakazivanje_putnika
- **adresa_id** - koristi se u zakazivanje_putnika
- **adresa** - koristi se u zakazivanje_putnika
- **broj_telefona** - koristi se u zakazivanje_putnika
- **tip_putnika** - koristi se u zakazivanje_putnika
- **ime** - koristi se u greska_zahteva
- **context** - koristi se u greska_zahteva

### Preporučene Nove Kolone

```sql
-- Kolone za zakazivanje i vožnje
ALTER TABLE voznje_log ADD COLUMN grad VARCHAR(10);           -- 'bc' ili 'vs'
ALTER TABLE voznje_log ADD COLUMN vreme_polaska TIME;         -- Vreme polaska (iz meta.vreme)
ALTER TABLE voznje_log ADD COLUMN dan_u_nedelji VARCHAR(3);   -- 'pon', 'uto', 'sre', itd.

-- Kolone za zakazivanje putnika
ALTER TABLE voznje_log ADD COLUMN adresa_id UUID;             -- Referenca na adresu
ALTER TABLE voznje_log ADD COLUMN adresa_text TEXT;           -- Tekstualna adresa
ALTER TABLE voznje_log ADD COLUMN broj_telefona VARCHAR(20);  -- Telefon putnika
ALTER TABLE voznje_log ADD COLUMN tip_putnika VARCHAR(20);    -- Tip putnika

-- Kolone za greške
ALTER TABLE voznje_log ADD COLUMN ime_subjekta TEXT;          -- Ime iz greška (može biti i putnik)
ALTER TABLE voznje_log ADD COLUMN error_context TEXT;         -- Kontekst greške

-- Zadržati meta za edge cases i buduću ekstenzibilnost
-- meta će postati NULL za većinu zapisa nakon migracije
```

---

## 📋 PLAN IMPLEMENTACIJE MIGRACIJE

### **Faza 1: Priprema** (Dan 1)

1. **Backup baze podataka**
   ```sql
   -- Kreirati backup tabele
   CREATE TABLE voznje_log_backup AS SELECT * FROM voznje_log;
   ```

2. **Kreirati nove kolone**
   ```sql
   ALTER TABLE voznje_log ADD COLUMN grad VARCHAR(10);
   ALTER TABLE voznje_log ADD COLUMN vreme_polaska TIME;
   ALTER TABLE voznje_log ADD COLUMN dan_u_nedelji VARCHAR(3);
   ALTER TABLE voznje_log ADD COLUMN adresa_id UUID;
   ALTER TABLE voznje_log ADD COLUMN adresa_text TEXT;
   ALTER TABLE voznje_log ADD COLUMN broj_telefona VARCHAR(20);
   ALTER TABLE voznje_log ADD COLUMN tip_putnika VARCHAR(20);
   ALTER TABLE voznje_log ADD COLUMN ime_subjekta TEXT;
   ALTER TABLE voznje_log ADD COLUMN error_context TEXT;
   ```

3. **Dodati indekse za performanse**
   ```sql
   CREATE INDEX idx_voznje_log_grad ON voznje_log(grad);
   CREATE INDEX idx_voznje_log_vreme_polaska ON voznje_log(vreme_polaska);
   CREATE INDEX idx_voznje_log_dan ON voznje_log(dan_u_nedelji);
   CREATE INDEX idx_voznje_log_adresa_id ON voznje_log(adresa_id);
   ```

### **Faza 2: Migracija Podataka** (Dan 2)

```sql
-- 1. Migracija zakazivanje_putnika zapisa
UPDATE voznje_log 
SET 
  grad = meta->>'grad',
  vreme_polaska = (meta->>'vreme')::TIME,
  dan_u_nedelji = meta->>'dan',
  adresa_id = (meta->>'adresa_id')::UUID,
  adresa_text = meta->>'adresa',
  broj_telefona = meta->>'broj_telefona',
  tip_putnika = meta->>'tip_putnika'
WHERE tip = 'zakazivanje_putnika' AND meta IS NOT NULL;

-- 2. Migracija voznja zapisa
UPDATE voznje_log 
SET 
  grad = meta->>'grad',
  vreme_polaska = (meta->>'vreme')::TIME
WHERE tip = 'voznja' AND meta IS NOT NULL;

-- 3. Migracija otkazivanje zapisa
UPDATE voznje_log 
SET 
  grad = meta->>'grad',
  vreme_polaska = (meta->>'vreme')::TIME
WHERE tip = 'otkazivanje' AND meta IS NOT NULL;

-- 4. Migracija uplata zapisa
UPDATE voznje_log 
SET 
  grad = meta->>'grad',
  vreme_polaska = (meta->>'vreme')::TIME
WHERE tip = 'uplata' AND meta IS NOT NULL;

-- 5. Migracija greska_zahteva zapisa
UPDATE voznje_log 
SET 
  ime_subjekta = meta->>'ime',
  tip_putnika = meta->>'tip',
  error_context = meta->>'context'
WHERE tip = 'greska_zahteva' AND meta IS NOT NULL;
```

### **Faza 3: Validacija** (Dan 3)

```sql
-- Provera da li su svi podaci migrirani
SELECT 
  tip,
  COUNT(*) as total,
  COUNT(CASE WHEN meta IS NOT NULL THEN 1 END) as ima_meta,
  COUNT(grad) as ima_grad,
  COUNT(vreme_polaska) as ima_vreme,
  COUNT(adresa_id) as ima_adresa
FROM voznje_log
GROUP BY tip
ORDER BY total DESC;

-- Provera konzistentnosti
SELECT * FROM voznje_log 
WHERE tip = 'zakazivanje_putnika' 
  AND meta IS NOT NULL 
  AND (grad IS NULL OR vreme_polaska IS NULL)
LIMIT 10;
```

### **Faza 4: Ažuriranje Aplikacijskog Koda** (Dan 4-5)

**Datoteke koje treba ažurirati:**

1. **lib/models/** - Update modela za voznje_log
2. **lib/services/** - Update servisa koji koriste voznje_log
3. **lib/screens/** - Update UI komponenti koje prikazuju log podatke
4. **supabase/functions/** - Update Edge funkcija koje koriste meta polje

**Primer izmene u Dart kodu:**

```dart
// STARO - korišćenje meta JSONB polja
final meta = log['meta'] as Map<String, dynamic>?;
final grad = meta?['grad'] as String?;
final vreme = meta?['vreme'] as String?;

// NOVO - korišćenje dediciranih kolona
final grad = log['grad'] as String?;
final vreme = log['vreme_polaska'] as String?;
final dan = log['dan_u_nedelji'] as String?;
```

### **Faza 5: Čišćenje i Finalizacija** (Dan 6)

```sql
-- Opciono: Očistiti meta polje za zapise koji su migrirani
-- (Zadržati meta za buduću ekstenzibilnost)
UPDATE voznje_log 
SET meta = NULL
WHERE tip IN ('zakazivanje_putnika', 'voznja', 'otkazivanje', 'uplata', 'greska_zahteva')
  AND meta IS NOT NULL;

-- Ili selektivno zadržati neke delove meta ako je potrebno
```

---

## ⚡ PREDNOSTI MIGRACIJE

### 1. **Performanse**
- ✅ **Brže upite:** Indeksi na običnim kolonama su efikasniji od GIN indeksa na JSONB
- ✅ **Manje CPU:** Nema potrebe za JSONB parsing u svakom upitu
- ✅ **Bolje optimizacije:** PostgreSQL optimizer može bolje da optimizuje upite sa običnim kolonama

### 2. **Type Safety**
- ✅ **Validacija tipova:** Garantovana konzistentnost tipova podataka (TIME, UUID, VARCHAR)
- ✅ **Constrainti:** Mogućnost dodavanja CHECK constrainta i foreign key-eva
- ✅ **Aplikacijski kod:** Type-safe pristup u Dart/Flutter kodu

### 3. **Lakša Analitika**
- ✅ **Jednostavniji upiti:** Direktan pristup kolonama umesto JSON ekstraktovanja
- ✅ **Reporting:** Lakše kreiranje izveštaja i agregacija
- ✅ **BI Tools:** Bolja integracija sa eksternim analitičkim alatima

### 4. **Maintainability**
- ✅ **Čitljiviji šema:** Jasna struktura podataka
- ✅ **Dokumentacija:** Kolone su self-documenting
- ✅ **Migracije:** Lakše schema evolution

---

## ⚠️ RIZICI I MITIGACIJA

### Rizik 1: Downtime tokom migracije
**Mitigacija:**
- Migracija se izvodi u transaction bloku
- Backup podataka pre migracije
- Test na staging okruženju
- Migracija van peak sati (noću/vikendom)

### Rizik 2: Gubitak podataka
**Mitigacija:**
- Zadržati `meta` kolonu kao fallback
- Ne brisati `meta` odmah
- Kompletna backup strategija

### Rizik 3: Breaking changes u aplikaciji
**Mitigacija:**
- Backward compatibility period - podržavati i meta i nove kolone 
- Gradualno ažuriranje aplikacije
- Feature flags za novi kod

### Rizik 4: Nepredviđeni meta podaci
**Mitigacija:**
- Zadržati `meta` kolonu za edge cases
- Log upozorenja za nepoznate ključeve u meta
- Monitoring nakon migracije

---

## 📊 UTICAJ NA PERFORMANSE (PROCENA)

### Trenutno (sa JSONB)
```sql
-- Upit sa JSONB ekstraktovanjem
SELECT * FROM voznje_log 
WHERE meta->>'grad' = 'bc' 
  AND (meta->>'vreme')::TIME > '10:00';
-- Koristi GIN indeks ili seq scan, sporije
```

### Nakon migracije (sa običnim kolonama)
```sql
-- Upit sa direktnim pristupom
SELECT * FROM voznje_log 
WHERE grad = 'bc' 
  AND vreme_polaska > '10:00';
-- Koristi B-tree indekse, brže (~2-5x)
```

**Očekivano poboljšanje:**
- 📈 Upiti: **2-5x brže**
- 📉 CPU utilization: **-30%**
- 📉 Memory usage: **-20%**
- 📈 Index efficiency: **+40%**

---

## 🔄 ROLLBACK PLAN

Ako nešto pođe po zlu:

```sql
-- 1. Restore iz backup-a
DROP TABLE voznje_log;
CREATE TABLE voznje_log AS SELECT * FROM voznje_log_backup;

-- 2. Restore samo podataka (ako je šema OK)
UPDATE voznje_log vl
SET meta = vlb.meta
FROM voznje_log_backup vlb
WHERE vl.id = vlb.id;

-- 3. Drop novih kolona (ako je potrebno)
ALTER TABLE voznje_log 
  DROP COLUMN grad,
  DROP COLUMN vreme_polaska,
  DROP COLUMN dan_u_nedelji,
  DROP COLUMN adresa_id,
  DROP COLUMN adresa_text,
  DROP COLUMN broj_telefona,
  DROP COLUMN tip_putnika,
  DROP COLUMN ime_subjekta,
  DROP COLUMN error_context;
```

---

## 📅 TIMELINE

| Faza | Trajanje | Aktivnost |
|------|----------|-----------|
| Planiranje | 1 dan | Review ovog plana, stakeholder approval |
| Priprema | 1 dan | Backup, kreiranje kolona, indeksi |
| Migracija | 1 dan | Data migration, validacija |
| Testing | 2 dana | QA testing na staging |
| Deployment | 1 dan | Code deployment, monitoring |
| Finalizacija | 1 dan | Čišćenje, dokumentacija |
| **UKUPNO** | **7 dana** | |

---

## ✅ CHECKLIST PRE PRODUKCIJE

- [ ] Kreiran backup tabele `voznje_log_backup`
- [ ] Testirano na staging okruženju
- [ ] Validirani svi migracije skriptovi
- [ ] Ažuriran aplikacijski kod (Dart/Flutter)
- [ ] Ažurirane Supabase Edge funkcije
- [ ] Kreirani indeksi za nove kolone
- [ ] Pripremljen rollback plan
- [ ] Stakeholder approval
- [ ] Scheduled maintenance window
- [ ] Monitoring setup za praćenje nakon migracije

---

## 💡 PREPORUKA

**DA, migracija je preporučena iz sledećih razloga:**

1. **Trenutno korišćenje meta kolone je ograničeno** - samo 11.9% zapisa koristi meta
2. **Konzistentni podaci** - meta podaci imaju predvidljivu strukturu
3. **Performanse** - Značajno poboljšanje brzine upita
4. **Skalabilnost** - Tabela ima samo 2,804 reda, migracija je jednostavna
5. **Maintainability** - Čistija šema olakšava razvoj

**Predloženi pristup:**
- Zadržati `meta` kolonu za buduću ekstenzibilnost
- Kreirati nove kolone za često korišćene podatke
- Postupno očistiti `meta` podatke
- Backward compatibility tokom prelaznog perioda

---

**Kreirao:** GitHub Copilot  
**Verzija:** 1.0  
**Poslednje ažuriranje:** 19. februar 2026