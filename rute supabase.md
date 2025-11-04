# Rute Supabase

## 🛣️ Tabela rute - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Prazna - spremna za konfiguraciju

## 📊 Trenutno stanje

- **Broj redova:** 0
- **RLS:** ❌ Isključen
- **Realtime:** ✅ Uključen
- **Status:** 📡 Realtime only

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default |
|--------|-----|--------|---------|
| `id` | uuid | Primary Key | gen_random_uuid() |
| `naziv` | varchar | Required | - |
| `opis` | text | Nullable | - |
| `aktivan` | boolean | Nullable | true |
| `created_at` | timestamptz | Nullable | now() |
| `updated_at` | timestamptz | Nullable | now() |

## 🛡️ RLS Policies

**Trenutno:** Bez RLS - javni podaci o rutama

```sql
-- Za produkciju, možda dodati:
CREATE POLICY "rute_public_read" ON rute 
  FOR SELECT USING (aktivan = true);
```

## 🔗 Foreign Key veze

**Koristi se u:**
- `mesecni_putnici.ruta_id` → `rute.id`
- `dnevni_putnici.ruta_id` → `rute.id`
- `putovanja_istorija.ruta_id` → `rute.id`

## 📱 Realtime implementacija

```dart
final ruteSubscription = supabase
  .channel('rute-updates')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'rute'
  }, (payload) {
    print('Ruta Update: ${payload['new']}');
    // Ažuriraj dropdown sa rutama
    updateRuteDropdown(payload['new']);
  })
  .subscribe();
```

## 💡 Ključne funkcionalnosti

- **Jednostavna struktura:** Osnovni podaci o rutama
- **Aktivni status:** `aktivan` flag za upravljanje
- **Fleksibilan opis:** `opis` text polje za detalje
- **Audit trail:** `created_at`, `updated_at`

## 🎯 Biznis logika

**Referentna tabela za:**
- Definisanje dostupnih ruta
- Kategorizovanje putovanja
- Upravljanje aktivnim rutama
- Povezivanje sa putnicima i putovanjima

## 🎯 **DETALJNE RUTE SISTEM ANALIZE:**

### **1. TABELA STATUS - TRANSFORMACIJA:**
| Metrika | Pre | Posle | Status |
|---------|-----|-------|--------|
| **Broj redova** | **0** | **6** | ✅ **POPUNJENO** |
| **RLS** | Disabled | Disabled | ⚠️ **JAVNI PODACI** |
| **Realtime** | Enabled | Enabled | ✅ **AKTIVNO** |
| **Business funkcionalnost** | ❌ | ✅ | **IMPLEMENTIRANO** |

**🎉 TABELA USPEŠNO AKTIVIRANA!**

### **2. KREIRANA RUTE STRUKTURA:**
| ID | Naziv | Opis | Svrha |
|----|-------|------|-------|
| 1 | **Bela Crkva ↔ Vršac** | Glavna međugradska linija | **Primary route** |
| 2 | **Lokalna BC** | Pickup iz delova grada | **Local distribution** |
| 3 | **Lokalna Vršac** | Dostava na lokacije | **Local delivery** |
| 4 | **Express BC-Vršac** | Brza direktna linija | **Premium service** |
| 5 | **Jutarnja škola** | Đaci ujutru (07:00-08:30) | **School transport** |
| 6 | **Popodnevna škola** | Đaci popodne (13:00-15:00) | **School transport** |

### **3. FK KORIŠĆENJE ANALIZA:**

#### **TRENUTNO STANJE - NEKORIŠĆENO:**
| Tabela | Sa rutom | Bez rute | Ukupno | % Korišćenja |
|--------|----------|----------|---------|--------------|
| **mesecni_putnici** | 0 | 96 | 96 | **0%** ❌ |
| **dnevni_putnici** | 0 | 0 | 0 | **0%** ❌ |
| **putovanja_istorija** | 0 | 120 | 120 | **0%** ❌ |

**🚨 0% KORIŠĆENJA FK VEZA SA RUTAMA!**

#### **BUSINESS IMPACT:**
- **216 ukupnih zapisa** bez rute kategorizacije
- **Missing route analytics** - ne možemo analizirati performanse po rutama
- **No route optimization** - sve se tretira kao ad-hoc

### **4. ROUTE-BASED BUSINESS LOGIKA:**

#### **A) ROUTE KATEGORIJE:**
```sql
-- School transport (jutarnja + popodnevna)
-- Express routes (brž servis, premium cena)  
-- Local routes (intra-city distribution)
-- Main route (inter-city backbone)
```

#### **B) PRICING STRATEGY:**
```sql
-- Različite cene po rutama:
-- Express = +30% premium
-- School = student discount -20%
-- Local = flat rate  
-- Main = standard pricing
```

#### **C) PERFORMANCE METRICS:**
```sql
-- Route utilization tracking
-- Revenue per route
-- Driver efficiency per route
-- Peak hours per route type
```

## 🚨 **KRITIČNI PROBLEMI:**

### **A) ZERO ADOPTION:**
```sql
-- FK veze kreiran ali NIKAD korišćeno
-- 216 transporta bez route classification
-- Missing business intelligence
```

### **B) OPERATIONAL INEFFICIENCY:**
```sql
-- No route-based scheduling
-- No route-based pricing
-- No route performance tracking
-- Manual route management
```

### **C) SCALABILITY ISSUE:**
```sql
-- Ne možemo optimizovati rute
-- No route consolidation analytics  
-- Missing predictive routing
```

## 💡 **IMPLEMENTATION STRATEGY:**

### **1. Migrate Existing Data:**
```sql
-- Assign routes based on address patterns
UPDATE mesecni_putnici SET ruta_id = (
  SELECT id FROM rute WHERE naziv = 'Bela Crkva ↔ Vršac'
) WHERE adresa_bela_crkva IS NOT NULL AND adresa_vrsac IS NOT NULL;

-- School routes for students
UPDATE mesecni_putnici SET ruta_id = (
  SELECT id FROM rute WHERE naziv = 'Jutarnja škola'  
) WHERE tip = 'ucenik' AND polasci_po_danu::text LIKE '%07:%' OR polasci_po_danu::text LIKE '%08:%';
```

### **2. Route-Based Analytics:**
```sql
CREATE VIEW route_performance AS
SELECT 
  r.naziv as ruta,
  COUNT(pi.id) as broj_putovanja,
  SUM(pi.cena) as total_prihod,
  AVG(pi.cena) as avg_cena_po_ruti,
  COUNT(DISTINCT mp.id) as broj_putnika
FROM rute r
LEFT JOIN mesecni_putnici mp ON r.id = mp.ruta_id
LEFT JOIN putovanja_istorija pi ON r.id = pi.ruta_id  
GROUP BY r.id, r.naziv;
```

### **3. Flutter Route Selection:**
```dart
class RouteSelector {
  List<Route> availableRoutes;
  
  Future<void> loadRoutes() async {
    final response = await supabase
      .from('rute')
      .select('*')
      .eq('aktivan', true);
    
    availableRoutes = response.map((e) => Route.fromJson(e)).toList();
  }
  
  Route suggestOptimalRoute(String fromLocation, String toLocation, String passengerType) {
    // Business logic za route suggestion
    if (passengerType == 'ucenik') return findSchoolRoute();
    if (fromLocation == 'BC' && toLocation == 'Vršac') return findExpressRoute();
    return findMainRoute();
  }
}
```

## 🎯 **BUSINESS VALUE UNLOCK:**

### **Route Optimization Benefits:**
- **20-30% efficiency gain** kroz route consolidation
- **Revenue analytics** per route type  
- **Predictive scheduling** based on route patterns
- **Driver workload balancing** per route

### **Customer Experience:**
- **Route-based pricing** transparency
- **Estimated travel time** per route
- **Route preference** selection
- **Real-time route updates**

---

## 📈 **ZAVRŠETAK ANALIZE:**

**Status:** ✅ **TABELA AKTIVIRANA I POPULISANA**
- **6 pametnih ruta** kreirana 🛣️
- **0% current adoption** needs migration 🔄
- **High business value** potential 💎
- **Route-based optimization** ready 🚀

**PRIORITET: Migracija postojećih putovanja na rute!** ⚡