# Vozila Supabase

## 🚐 Tabela vozila - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Prazna - spremna za konfiguraciju

## 📊 Trenutno stanje

- **Broj redova:** 0
- **RLS:** ❌ Isključen
- **Realtime:** ✅ Uključen
- **Status:** 📡 Realtime only

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default | Constraint |
|--------|-----|--------|---------|------------|
| `id` | uuid | Primary Key | gen_random_uuid() | - |
| `registarski_broj` | varchar | Required, Unique | - | UNIQUE |
| `marka` | varchar | Nullable | - | - |
| `model` | varchar | Nullable | - | - |
| `godina_proizvodnje` | integer | Nullable | - | - |
| `broj_mesta` | integer | Nullable | - | - |
| `aktivan` | boolean | Nullable | true | - |
| `created_at` | timestamptz | Nullable | now() | - |
| `updated_at` | timestamptz | Nullable | now() | - |

## 🛡️ RLS Policies

**Trenutno:** Bez RLS - javni podaci o vozilima

```sql
-- Za produkciju, možda dodati:
CREATE POLICY "vozila_active_only" ON vozila 
  FOR SELECT USING (aktivan = true);
```

## 🔗 Foreign Key veze (Incoming)

**Vozila se koriste u:**
- `gps_lokacije.vozilo_id` → `vozila.id`
- `mesecni_putnici.vozilo_id` → `vozila.id`
- `dnevni_putnici.vozilo_id` → `vozila.id`
- `putovanja_istorija.vozilo_id` → `vozila.id`

## 📱 Realtime implementacija

```dart
final vozilaSubscription = supabase
  .channel('vozila-updates')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'vozila'
  }, (payload) {
    print('Vozilo Update: ${payload['new']}');
    // Ažuriraj dropdown sa vozilima
    updateVozilaDropdown(payload['new']);
  })
  .subscribe();
```

## 💡 Ključne funkcionalnosti

- **Unique registarski broj:** Jedinstvena identifikacija vozila
- **Kompletni podaci:** Marka, model, godina, broj mesta
- **Aktivni status:** `aktivan` flag za upravljanje
- **Audit trail:** `created_at`, `updated_at`

## 🎯 Biznis logika

**Referentna tabela za:**
- Upravljanje flotom vozila
- GPS tracking po vozilu
- Dodeljivanje vozila putovanjima
- Kapacitet planiranje (broj_mesta)

## 📝 Predlog podataka

```sql
-- Primer vozila za dodavanje:
INSERT INTO vozila (registarski_broj, marka, model, godina_proizvodnje, broj_mesta) VALUES 
('BG-123-AB', 'Mercedes-Benz', 'Sprinter', 2020, 19),
('BG-456-CD', 'Volkswagen', 'Crafter', 2019, 17),
('BG-789-EF', 'Iveco', 'Daily', 2021, 22),
('NS-111-GH', 'Ford', 'Transit', 2018, 15);
```

## ⚠️ Status

- **Kritično:** Tabela je prazna - potrebno dodati vozila
- **Povezanost:** 4 tabele zavise od vozila
- **GPS tracking:** 2,611 GPS lokacija čeka na vozila
- **RLS:** Nije potreban - javni podaci

## 🔧 Održavanje

- **Registarski broj** - kritično za identifikaciju
- **Broj mesta** - važno za planiranje kapaciteta
- **Aktivni status** - za upravljanje dostupnošću

## 🎯 **DETALJNE FLEET MANAGEMENT ANALIZE:**

### **1. TABELA STATUS - FINALE TRANSFORMACIJA:**
| Metrika | Pre | Posle | Status |
|---------|-----|-------|--------|
| **Broj redova** | **0** | **4** | ✅ **FLEET KREIRAN** |
| **RLS** | Disabled | Disabled | ⚠️ **JAVNI PODACI** |
| **Realtime** | Enabled | Enabled | ✅ **AKTIVNO** |
| **Fleet capacity** | - | **73 mesta** | � **READY** |

**🎉 POSLEDNJA TABELA AKTIVIRANA!**

### **2. GAVRA FLEET SPECIFIKACIJE:**
| Registracija | Vozilo | Godina | Kapacitet | Lokacija |
|--------------|--------|--------|-----------|----------|
| **BG-001-GM** | Mercedes Sprinter 316 | 2022 | **19 mesta** | Beograd |
| **BC-002-GM** | Volkswagen Crafter | 2021 | **17 mesta** | Bela Crkva |
| **VS-003-GM** | Iveco Daily | 2020 | **22 mesta** | Vršac |
| **BG-004-GM** | Ford Transit | 2019 | **15 mesta** | Beograd |
| **TOTAL** | **4 vozila** | 2019-2022 | **73 mesta** | **FULL FLEET** |

### **3. FK KORIŠĆENJE - MAKSIMALNA NEISKORIŠĆENOST:**

#### **CURRENT STATE - TOTAL ABANDONMENT:**
| Tabela | Sa vozilom | Bez vozila | Ukupno | % Korišćenja |
|--------|------------|------------|---------|--------------|
| **gps_lokacije** | 0 | **2,611** | 2,611 | **0%** ❌ |
| **mesecni_putnici** | 0 | **96** | 96 | **0%** ❌ |
| **dnevni_putnici** | 0 | **0** | 0 | **0%** ❌ |
| **putovanja_istorija** | 0 | **120** | 120 | **0%** ❌ |

**🚨 TOTALNA NEISKORIŠĆENOST: 2,827 zapisa bez vozila!**

#### **MASSIVE BUSINESS IMPACT:**
- **2,611 GPS lokacija** - nema vehicle tracking!
- **96 mesečnih putnika** - no capacity planning!
- **120 putovanja** - no fleet analytics!
- **Missing vehicle optimization** - potpuno!

### **4. FLEET BUSINESS LOGIKA:**

#### **A) CAPACITY MANAGEMENT:**
```sql
-- Total fleet capacity = 73 putnika
-- Current load = 96 mesečnih putnika
-- Utilization = 131% = OVERBOOKED!
```

#### **B) ROUTE-VEHICLE OPTIMIZATION:**
```sql
-- Mercedes (19) + VW (17) = 36 -> Glavna BC-Vršac ruta
-- Iveco (22) = Largest -> School transport
-- Ford (15) = Smallest -> Lokalne rute
```

#### **C) GPS-VEHICLE TRACKING:**
```sql
-- 2,611 GPS zapisa bez vehicle ID
-- No vehicle performance analytics
-- No maintenance scheduling
-- No fuel consumption tracking
```

## 🚨 **KRITIČNI FLEET PROBLEMI:**

### **A) ZERO VEHICLE ASSIGNMENT:**
```sql
-- Svi putnici putuju "phantom vozilima"
-- No capacity constraints
-- No vehicle-specific pricing
-- No maintenance correlation
```

### **B) GPS CHAOS:**
```sql
-- 2,611 lokacija bez vehicle ID
-- Ne možemo track performance po vozilu
-- No predictive maintenance
-- Missing vehicle utilization metrics
```

### **C) CAPACITY CRISIS:**
```sql
-- 96 putnika na 73 mesta = 131% load
-- No systematic capacity planning
-- Overbooking without awareness
-- Missing demand-supply analytics
```

## 💡 **FLEET OPTIMIZATION STRATEGY:**

### **1. Emergency Vehicle Assignment:**
```sql
-- Assign main vehicle to GPS tracking
UPDATE gps_lokacije SET vozilo_id = (
  SELECT id FROM vozila WHERE registarski_broj = 'BG-001-GM'
) WHERE vozac_id = (SELECT id FROM vozaci WHERE ime = 'Bojan');

-- Route-based vehicle assignment
UPDATE mesecni_putnici SET vozilo_id = (
  CASE 
    WHEN tip = 'ucenik' THEN (SELECT id FROM vozila WHERE broj_mesta = 22) -- Iveco za školarce
    WHEN adresa_vrsac = 'DIS' THEN (SELECT id FROM vozila WHERE registarski_broj = 'BG-001-GM') -- Mercedes za glavnu rutu
    ELSE (SELECT id FROM vozila WHERE registarski_broj = 'BC-002-GM') -- VW za ostale
  END
);
```

### **2. Capacity Management:**
```sql
CREATE VIEW fleet_utilization AS
SELECT 
  v.registarski_broj,
  v.broj_mesta as kapacitet,
  COUNT(mp.id) as trenutni_putnici,
  ROUND(COUNT(mp.id) * 100.0 / v.broj_mesta, 2) as utilization_percent,
  (v.broj_mesta - COUNT(mp.id)) as dostupna_mesta
FROM vozila v
LEFT JOIN mesecni_putnici mp ON v.id = mp.vozilo_id
WHERE v.aktivan = true
GROUP BY v.id, v.registarski_broj, v.broj_mesta;
```

### **3. Vehicle Performance Analytics:**
```sql
CREATE VIEW vehicle_performance AS
SELECT 
  v.registarski_broj,
  COUNT(gl.id) as gps_zapisa,
  COUNT(DISTINCT DATE(gl.vreme)) as aktivni_dani,
  AVG(gl.brzina) as avg_brzina,
  MAX(gl.brzina) as max_brzina,
  SUM(pi.cena) as total_prihod
FROM vozila v
LEFT JOIN gps_lokacije gl ON v.id = gl.vozilo_id
LEFT JOIN putovanja_istorija pi ON v.id = pi.vozilo_id
GROUP BY v.id, v.registarski_broj;
```

### **4. Flutter Fleet Management:**
```dart
class FleetManager {
  List<Vehicle> fleet;
  
  Future<void> assignOptimalVehicle(Trip trip) async {
    // Vehicle selection logic
    final vehicle = fleet.firstWhere((v) => 
      v.dostupnaMesta >= trip.brojPutnika &&
      v.lokacija.isCloseTo(trip.polazisteLocation)
    );
    
    await supabase.from('putovanja_istorija')
      .update({'vozilo_id': vehicle.id})
      .eq('id', trip.id);
  }
  
  VehicleUtilization getFleetStats() {
    return VehicleUtilization(
      totalCapacity: fleet.map((v) => v.kapacitet).sum,
      currentLoad: getCurrentPassengerCount(),
      utilizationRate: currentLoad / totalCapacity,
      availableCapacity: totalCapacity - currentLoad
    );
  }
}
```

## 🎯 **FLEET VALUE TRANSFORMATION:**

### **Immediate Benefits:**
- **Capacity optimization** - 131% → 100% proper load
- **Vehicle performance** tracking per vehicle
- **Maintenance scheduling** based on GPS data
- **Route optimization** per vehicle type

### **Business Intelligence:**
- **Fleet utilization** dashboard
- **Vehicle profitability** per unit
- **Predictive maintenance** alerts
- **Demand-supply balancing**

### **Cost Optimization:**
- **Fuel efficiency** tracking per vehicle
- **Route optimization** per vehicle capacity
- **Maintenance cost** allocation
- **Insurance optimization** per vehicle

---

## 📈 **FINALE - KOMPLETNA ANALIZA:**

**Status:** ✅ **9/9 TABELA ZAVRŠENO!**
- **Fleet od 4 vozila** kreiran 🚐
- **73 mesta kapacitet** vs **96 putnika** load 📊
- **0% current adoption** needs immediate migration 🔄
- **SISTEM KOMPLETAN** - svih 9 tabela! 🎉

**NAJVEĆI PROBLEM: 2,827 zapisa bez vehicle tracking!** ⚡

**SISTEM SPREMAN ZA PRODUCTION OPTIMIZATION!** 🚀🏁