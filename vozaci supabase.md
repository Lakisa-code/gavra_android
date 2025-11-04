# Vozaci Supabase

## 👨‍💼 Tabela vozaci - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Aktivna - 4 reda podataka

## 📊 Trenutno stanje

- **Broj redova:** 4 ⭐
- **RLS:** ✅ Uključen
- **Realtime:** ✅ Uključen
- **Status:** ✅ RLS + Realtime

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default | Constraint |
|--------|-----|--------|---------|------------|
| `id` | uuid | Primary Key | gen_random_uuid() | - |
| `ime` | varchar | Required, Unique | - | UNIQUE |
| `email` | varchar | Nullable | - | - |
| `telefon` | varchar | Nullable | - | - |
| `aktivan` | boolean | Nullable | true | - |
| `created_at` | timestamptz | Nullable | now() | - |
| `updated_at` | timestamptz | Nullable | now() | - |
| `kusur` | numeric | Nullable | 0.0 | >= 0 |

## 🛡️ RLS Policies

```sql
-- Development permissive policy
CREATE POLICY "dev_allow_all_vozaci" ON vozaci 
  FOR ALL TO anon, authenticated 
  USING (true) WITH CHECK (true);
```

## 🔗 Foreign Key veze (Incoming)

**Vozaci se koriste u SVIM ostalim tabelama:**

### Dnevni putnici (8 veza!):
- `dnevni_putnici.dodao_vozac_id` → `vozaci.id`
- `dnevni_putnici.pokupio_vozac_id` → `vozaci.id`
- `dnevni_putnici.naplatio_vozac_id` → `vozaci.id`
- `dnevni_putnici.otkazao_vozac_id` → `vozaci.id`
- `dnevni_putnici.vozac_id` → `vozaci.id`

### Ostale tabele:
- `gps_lokacije.vozac_id` → `vozaci.id`
- `putovanja_istorija.vozac_id` → `vozaci.id`
- `mesecni_putnici.vozac_id` → `vozaci.id`

## 📱 Realtime implementacija

```dart
final vozaciSubscription = supabase
  .channel('vozaci-updates')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'vozaci'
  }, (payload) {
    print('Vozač Update: ${payload['new']}');
    // Ažuriraj listu vozača
    updateVozaciList(payload['new']);
  })
  .subscribe();
```

## 💡 Ključne funkcionalnosti

- **Centralna tabela:** Sve operacije prolaze kroz vozače
- **Unique ime:** Svaki vozač ima jedinstveno ime
- **Kusur tracking:** Numeric polje sa check constraint (>= 0)
- **Aktivni status:** `aktivan` flag za upravljanje
- **Audit trail:** `created_at`, `updated_at`
- **Kontakt podaci:** Email i telefon

## 🎯 Biznis logika

**Najvažnija tabela u sistemu:**
- 4 vozača trenutno u sistemu
- Učestvuju u SVIM operacijama
- GPS tracking povezan sa vozačima
- Finansijski tracking (kusur)
- Multiple role sistema (dodao, pokupio, naplatio, otkazao)

## 💰 Finansijski aspekt

```sql
-- Kusur mora biti >= 0
ALTER TABLE vozaci ADD CONSTRAINT kusur_positive 
CHECK (kusur >= 0::numeric);
```

## ⚠️ Kritična napomena

- **Samo 4 vozača** u sistemu
- **Sve operacije zavise** od vozača
- **Unique constraint** na ime - pažljivo upravljanje
- **RLS enabled** - osetljivi podaci (email, telefon)

## 🎯 **KONKRETNI PODACI ANALIZE:**

### **TIM VOZAČA (4 aktivna):**
| Ime | Kusur | GPS | Mesečni | Istorija | Status |
|-----|-------|-----|---------|----------|--------|
| **Bojan** | 10.0 RSD | 2,611 📍 | 91 👥 | 120 📋 | **GLAVNI** |
| **Bilevski** | 0.0 RSD | 0 📍 | 0 👥 | 0 📋 | Neaktivan |
| **Bruda** | 0.0 RSD | 0 � | 0 👥 | 0 📋 | Neaktivan |
| **Svetlana** | 0.0 RSD | 0 📍 | 0 👥 | 0 📋 | Neaktivna |

### **KRITIČNI UVID:**
- **BOJAN** = 100% aktivnosti! 🏆
  - **2,611 GPS lokacija** (sav tracking)
  - **91 mesečnih putnika** (94.8% od 96 total)
  - **120 putovanja u istoriji** (100% aktivnosti)
  - **Jedini sa kusur** (10 RSD)

### **PROBLEM:** 
- **3 vozača totalno neaktivno** ❌
- **Single point of failure** - sve zavisi od Bojana
- **Potrebna redistribucija aktivnosti**

## 🚨 **DNEVNI PUTNICI STATUS:**
**0 zapisa** u svim kategorijama:
- `dodao_vozac_id` = 0 
- `naplatio_vozac_id` = 0
- `pokupio_vozac_id` = 0  
- `otkazao_vozac_id` = 0
- `vozac_id` = 0

**→ Dnevni putnici funkcionalnost nije u upotrebi!**

## 🔧 **BUSINESS LOGIKA ANALIZA:**

### **1. AKTIVNI vs NEAKTIVNI PATTERN:**
```sql
-- 1 vozač = 100% opterećenja
-- 3 vozača = 0% korišćenja  
-- Loša distribucija posla
```

### **2. FINANSIJSKI TRACKING:**
- **Kusur sistem** implementiran ✅
- **Samo Bojan ima kusur** (10 RSD)
- **Check constraint** (>= 0) aktivan

### **3. GPS DOMINACIJA:**
- **2,611 GPS zapisa** - svi na Bojana
- **Real-time tracking** centralizovan
- **Performance bottleneck** potencijal

### **4. MESEČNI PUTNICI LOAD:**
- **91 od 96** putnika na Bojana (94.8%)
- **Extreme single-point dependency**

## 💡 **PREPORUKE ZA OPTIMIZACIJU:**

### **1. Load Balancing:**
```sql
-- Redistribuiraj mesečne putnike
UPDATE mesecni_putnici 
SET vozac_id = (SELECT id FROM vozaci WHERE ime = 'Svetlana')
WHERE id IN (SELECT id FROM mesecni_putnici LIMIT 20);
```

### **2. Aktivacija vozača:**
```sql
-- Dodeli kontakt podatke
UPDATE vozaci 
SET telefon = '+381..', email = '..@gmail.com'
WHERE ime IN ('Svetlana', 'Bruda', 'Bilevski');
```

### **3. GPS Diversifikacija:**
```sql
-- Buduće GPS zapise distribuiraj
-- Implementiraj round-robin algoritam
```

---

## 📈 **ZAVRŠETAK ANALIZE:**

**Status:** ✅ **KRITIČNI PROBLEM IDENTIFIKOVAN**  
- **Centralna tabela** ✅ analizirana
- **Single point of failure** 🚨 detektovan  
- **Load balancing** 💡 potreban
- **Business continuity** ⚠️ ugrožen

**Tabela funkcionalna ali NEOPTIMALNA!** ⚖️