# GPS Lokacije Supabase

## 📍 Tabela gps_lokacije - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Aktivna - 2,611 redova podataka

## 📊 Trenutno stanje

- **Broj redova:** 2,611 ⭐⭐⭐
- **RLS:** ❌ Isključen
- **Realtime:** ✅ Uključen (NOVO DODANO)
- **Status:** 📡 Realtime only

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default |
|--------|-----|--------|---------|
| `id` | uuid | Primary Key | gen_random_uuid() |
| `vozac_id` | uuid | Nullable, FK | - |
| `vozilo_id` | uuid | Nullable, FK | - |
| `latitude` | numeric | Required | - |
| `longitude` | numeric | Required | - |
| `brzina` | numeric | Nullable | - |
| `pravac` | numeric | Nullable | - |
| `tacnost` | numeric | Nullable | - |
| `vreme` | timestamptz | Nullable | now() |

## 🛡️ RLS Policies

**Trenutno:** Nema RLS - svi podaci su javni

```sql
-- Za produkciju, preporučuje se:
CREATE POLICY "gps_active_drivers" ON gps_lokacije 
  FOR SELECT USING (
    vozac_id IN (SELECT id FROM vozaci WHERE aktivan = true)
  );
```

## 🔗 Foreign Key veze

- `vozac_id` → `vozaci.id`
- `vozilo_id` → `vozila.id`

## 📱 Realtime implementacija

```dart
final gpsSubscription = supabase
  .channel('gps-tracking')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'gps_lokacije'
  }, (payload) {
    print('GPS Update: ${payload['new']}');
    // Ažuriraj mapu ili tracking UI
    updateMapLocation(payload['new']);
  })
  .subscribe();
```

## 🚀 Kritična izmena

**Problem:** GPS tabela sa 2,611 redova NIJE bila u Realtime  
**Rešenje:** Dodano u supabase_realtime publication  
**Rezultat:** Real-time GPS tracking sada radi! 

```sql
-- Izvršena komanda:
ALTER PUBLICATION supabase_realtime ADD TABLE gps_lokacije;
```

## ⚠️ Performance napomene

- Tabela sa najviše podataka (2,611 redova)
- Može generisati puno realtime event-ova
- Preporučuje se throttling ili filtering
- Razmotriti WHERE uslove u subscription-ima

## 🎯 **DETALJNE PERFORMANCE ANALIZE:**

### **1. VOZAČ MONOPOL (OPET!):**
| Vozač | GPS Zapisi | % | Period | Avg Brzina | Max Brzina |
|-------|------------|---|--------|------------|------------|
| **Bojan** | **2,611** | **100%** | 2025-10-03 do 11 | 0.15 km/h | 25.2 km/h |
| Ostali | **0** | **0%** | - | - | - |

**🚨 ISTI PATTERN: Bojan = 100% GPS tracking-a!**

### **2. VREMENSKA AKTIVNOST:**
| Datum | Zapisi | Period | Avg Brzina | Pokret (>5km/h) |
|-------|--------|--------|------------|-----------------|
| 2025-10-11 | 289 | 00:00-08:02 | 0.12 | 0 |
| 2025-10-10 | **637** | 00:00-23:59 | 0.12 | 2 |
| 2025-10-09 | 198 | 06:10-23:58 | 0.01 | 0 |
| 2025-10-04 | 496 | 00:02-23:59 | 0.18 | 0 |

**💡 INSIGHTS:**
- **24/7 tracking** aktivno
- **Very low average speeds** - parking tracking
- **Oct 10** = najaktivniji dan (637 zapisa)

### **3. BRZINSKA ANALIZA:**
| Kategorija | Zapisi | % | Avg Tačnost |
|------------|--------|---|-------------|
| **Parkiran (0 km/h)** | 1,614 | **61.8%** | 20.99m |
| **Spor (0-5 km/h)** | 992 | **38.0%** | 16.05m |
| **Gradski (5-30 km/h)** | 5 | **0.2%** | 20.76m |
| **Brži (30+ km/h)** | 0 | **0%** | - |

**🚨 KRITIČNI UVID:**
- **99.8% vremena = <= 5 km/h** (parkiran/spor)
- **Samo 5 zapisa** sa gradskom brzinom
- **Vozilo skoro ne ide** - tracking problem?

### **4. GEOGRAFSKA ANALIZA:**
**COORDINATES:** 44.9006, 21.4152 (Bela Crkva centar)

| Lokacija | Zapisi | % | Koordinate |
|----------|--------|---|------------|
| **Centar BC** | 1,766 | **67.6%** | 44.9006, 21.4152 |
| **Blizu 1** | 473 | **18.1%** | 44.9006, 21.4153 |
| **Blizu 2** | 134 | **5.1%** | 44.9007, 21.4153 |
| **Ostalo** | 238 | **9.1%** | Razne |

**🎯 PATTERN:**
- **67% vremena na istoj lokaciji** = Parking/depot
- **Vrlo mali geo-radius** (~100m)
- **Bela Crkva centar** dominacija

## 🚨 **KRITIČNI PROBLEMI:**

### **A) PERFORMANCE ISSUE:**
```sql
-- 2,611 real-time GPS zapisa = MASSIVE load!
-- Svaki INSERT/UPDATE = realtime event
-- Potreban throttling/batching
```

### **B) BUSINESS LOGIC PROBLEM:**
```sql
-- 99.8% parkiran/spor = vozilo ne radi?
-- Tracking accuracy problem?
-- False GPS data?
```

### **C) ARCHITECTURE ISSUE:**
```sql
-- Bojan monopol = single point of failure
-- Ostali vozači nemaju GPS tracking
-- Nebalansirana infrastruktura
```

## 💡 **PERFORMANCE OPTIMIZACIJE:**

### **1. Realtime Throttling:**
```dart
// Batch GPS updates svakih 30 sekundi
final gpsSubscription = supabase
  .channel('gps-throttled')
  .on('postgres_changes', {
    'event': 'INSERT',
    'schema': 'public',
    'table': 'gps_lokacije',
    'filter': 'vreme=gt.${DateTime.now().subtract(Duration(seconds: 30))}'
  }, (payload) {
    updateMapLocation(payload['new']);
  })
  .subscribe();
```

### **2. Data Cleanup:**
```sql
-- Archive old GPS data
DELETE FROM gps_lokacije 
WHERE vreme < NOW() - INTERVAL '30 days';

-- Index optimization
CREATE INDEX idx_gps_vozac_vreme ON gps_lokacije(vozac_id, vreme DESC);
```

### **3. Smart Filtering:**
```sql
-- Realtime samo za pokretne vozače
ALTER PUBLICATION supabase_realtime 
SET (publish_via_partition_root = true);

-- Filter za brzinu > 1 km/h
CREATE VIEW active_gps AS 
SELECT * FROM gps_lokacije WHERE brzina > 1;
```

---

## 📈 **ZAVRŠETAK ANALIZE:**

**Status:** ✅ **PERFORMANCE KRITIČAN**
- **Massive data volume** = 2,611 zapisa ⚡
- **Bojan monopol** = 100% tracking 🚨
- **99.8% statično** = vozilo ne radi? 🤔
- **Realtime overload** = performance risk 📊

**PRIORITET: Performance optimizacija + Data validation!** 🛠️