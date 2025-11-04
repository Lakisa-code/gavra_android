# Dnevni Putnici Supabase

## 🚌 Tabela dnevni_putnici - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Prazan - spremno za konfiguraciju

## 📊 Trenutno stanje

- **Broj redova:** 0
- **RLS:** ✅ Uključen
- **Realtime:** ✅ Uključen
- **Status:** ✅ RLS + Realtime

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default |
|--------|-----|--------|---------|
| `id` | uuid | Primary Key | gen_random_uuid() |
| `putnik_ime` | varchar | Required | - |
| `telefon` | varchar | Nullable | - |
| `grad` | varchar | Required | - |
| `broj_mesta` | integer | Nullable | - |
| `datum_putovanja` | date | Required | - |
| `vreme_polaska` | varchar | Nullable | - |
| `cena` | numeric | Nullable | - |
| `status` | varchar | Nullable | 'aktivno' |
| `naplatio_vozac_id` | uuid | Nullable, FK | - |
| `pokupio_vozac_id` | uuid | Nullable, FK | - |
| `dodao_vozac_id` | uuid | Nullable, FK | - |
| `otkazao_vozac_id` | uuid | Nullable, FK | - |
| `vozac_id` | uuid | Nullable, FK | - |
| `obrisan` | boolean | Nullable | false |
| `created_at` | timestamptz | Nullable | now() |
| `updated_at` | timestamptz | Nullable | now() |
| `ruta_id` | uuid | Nullable, FK | - |
| `vozilo_id` | uuid | Nullable, FK | - |
| `adresa_id` | uuid | Nullable, FK | - |

## 🛡️ RLS Policies

```sql
-- Development permissive policy
CREATE POLICY "dev_allow_all_dnevni" ON dnevni_putnici 
  FOR ALL TO anon, authenticated 
  USING (true) WITH CHECK (true);
```

## 🔗 Foreign Key veze

- `naplatio_vozac_id` → `vozaci.id`
- `pokupio_vozac_id` → `vozaci.id`
- `dodao_vozac_id` → `vozaci.id`
- `otkazao_vozac_id` → `vozaci.id`
- `vozac_id` → `vozaci.id`
- `ruta_id` → `rute.id`
- `vozilo_id` → `vozila.id`
- `adresa_id` → `adrese.id`

## 📱 Realtime implementacija

```dart
final dnevniSubscription = supabase
  .channel('dnevni-putnici')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'dnevni_putnici'
  }, (payload) {
    print('Dnevni putnik Update: ${payload['new']}');
    // Ažuriraj listu dnevnih putnika
  })
  .subscribe();
```

## 🎯 **BUSINESS LOGIKA ANALIZE**

### **1. KOMPLEKSAN FLOW:**
- **5 vozač tipova**: naplatio, pokupio, dodao, otkazao, osnovni vozač
- **Lifecycle tracking**: Ko je šta uradio u procesu
- **Dnevni karakter**: Za jednokratna putovanja

### **2. STATUS STATES:**
```sql
-- Mogući status-i:
'aktivno' (default) → 'naplaćeno' → 'pokupljeno' → 'završeno'
                   ↘ 'otkazano' → 'obrisan'
```

### **3. POVEZANOST SA OSTALIM TABELAMA:**
- **vozaci** (5x FK) - Multi-role tracking
- **rute** - Predefinisane linije  
- **vozila** - Kapacitet i tip prevoza
- **adrese** - Pickup/drop-off lokacije

### **4. RAZLIKA OD MESEČNIH:**
| Aspekt | Dnevni | Mesečni |
|--------|--------|---------|
| **Trajanje** | Jednokratno | Mesec dana |
| **Plaćanje** | Po putovanju | Paušalno |
| **Rezervacija** | Last-minute | Unapred |
| **Tracking** | Detaljno | Osnovni |

### **5. KRITIČNI INSIGHTS:**
- **Trenutno prazna** (0 redova) - Nova funkcionalnost
- **Over-engineered** - 5 FK na vozače možda previše
- **Realtime ready** - Za live booking sistem
- **Audit trail** - Ko je šta uradio je trackovan

## 🚀 **IMPLEMENTACIJA PREPORUKA:**

### **Flutter Booking Flow:**
```dart
// 1. Kreiranje novog putnika
await supabase.from('dnevni_putnici').insert({
  'putnik_ime': ime,
  'telefon': telefon,
  'grad': selectedGrad,
  'datum_putovanja': selectedDatum,
  'dodao_vozac_id': currentVozacId,
  'status': 'aktivno'
});

// 2. Naplata
await supabase.from('dnevni_putnici')
  .update({
    'naplatio_vozac_id': vozacId,
    'cena': iznos,
    'status': 'naplaćeno'
  })
  .eq('id', putnikId);
```

---

## 📈 **ZAVRŠETAK ANALIZE:**

**Status:** ✅ **ANALIZA ZAVRŠENA**
- Struktura detaljno analizirana
- Business logika mapirana
- Implementacija preporuke date
- Razlike od mesečnih putnika jasne

**Tabela spremna za development!** 🎯