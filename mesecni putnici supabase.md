# Mesečni Putnici Supabase

## 👥 Tabela mesecni_putnici - Analiza i konfiguracija

**Kreiran:** 4. novembar 2025  
**Status:** Aktivna - 96 redova podataka

## 📊 Trenutno stanje

- **Broj redova:** 96 ⭐⭐
- **RLS:** ✅ Uključen
- **Realtime:** ✅ Uključen
- **Status:** ✅ RLS + Realtime

## 🗂️ Struktura tabele

| Kolona | Tip | Opcije | Default |
|--------|-----|--------|---------|
| `id` | uuid | Primary Key | gen_random_uuid() |
| `putnik_ime` | varchar | Required | - |
| `tip` | varchar | Required | - |
| `tip_skole` | varchar | Nullable | - |
| `broj_telefona` | varchar | Nullable | - |
| `broj_telefona_oca` | varchar | Nullable | - |
| `broj_telefona_majke` | varchar | Nullable | - |
| `polasci_po_danu` | jsonb | Required | - |
| `adresa_bela_crkva` | text | Nullable | - |
| `adresa_vrsac` | text | Nullable | - |
| `tip_prikazivanja` | varchar | Nullable | 'standard' |
| `radni_dani` | varchar | Nullable | - |
| `aktivan` | boolean | Nullable | true |
| `status` | varchar | Nullable | 'aktivan' |
| `datum_pocetka_meseca` | date | Required | - |
| `datum_kraja_meseca` | date | Required | - |
| `ukupna_cena_meseca` | numeric | Nullable | - |
| `cena` | numeric | Nullable | - |
| `broj_putovanja` | integer | Nullable | 0 |
| `broj_otkazivanja` | integer | Nullable | 0 |
| `poslednje_putovanje` | timestamptz | Nullable | - |
| `vreme_placanja` | timestamptz | Nullable | - |
| `placeni_mesec` | integer | Nullable | - |
| `placena_godina` | integer | Nullable | - |
| `vozac_id` | uuid | Nullable, FK | - |
| `pokupljen` | boolean | Nullable | false |
| `vreme_pokupljenja` | timestamptz | Nullable | - |
| `statistics` | jsonb | Nullable | '{}' |
| `obrisan` | boolean | Nullable | false |
| `created_at` | timestamptz | Nullable | now() |
| `updated_at` | timestamptz | Nullable | now() |
| `ruta_id` | uuid | Nullable, FK | - |
| `vozilo_id` | uuid | Nullable, FK | - |
| `adresa_polaska_id` | uuid | Nullable, FK | - |
| `adresa_dolaska_id` | uuid | Nullable, FK | - |
| `ime` | varchar | Nullable | - |
| `prezime` | varchar | Nullable | - |
| `datum_pocetka` | date | Nullable | - |
| `datum_kraja` | date | Nullable | - |

## 🛡️ RLS Policies

```sql
-- Development permissive policy
CREATE POLICY "dev_allow_all_mesecni" ON mesecni_putnici 
  FOR ALL TO anon, authenticated 
  USING (true) WITH CHECK (true);
```

## 🔗 Foreign Key veze

- `vozac_id` → `vozaci.id`
- `ruta_id` → `rute.id`
- `vozilo_id` → `vozila.id`
- `adresa_polaska_id` → `adrese.id`
- `adresa_dolaska_id` → `adrese.id`

**Vezane tabele:**
- `putovanja_istorija.mesecni_putnik_id` → `mesecni_putnici.id`

## 📱 Realtime implementacija

```dart
final mesecniSubscription = supabase
  .channel('mesecni-putnici')
  .on('postgres_changes', {
    'event': '*',
    'schema': 'public',
    'table': 'mesecni_putnici'
  }, (payload) {
    print('Mesečni putnik Update: ${payload['new']}');
    // Ažuriraj listu mesečnih putnika
    updateMesecniPutnici(payload['new']);
  })
  .subscribe();
```

## 💡 Ključne funkcionalnosti

- **Finansijsko praćenje:** `ukupna_cena_meseca`, `vreme_placanja`
- **Statistike:** `broj_putovanja`, `broj_otkazivanja`, `statistics` (jsonb)
- **Fleksibilni polasci:** `polasci_po_danu` (jsonb struktura)
- **Kontakt podaci:** Telefoni putnika i roditelja
- **Adrese:** Bela Crkva i Vršac destinacije
- **Status tracking:** `pokupljen`, `vreme_pokupljenja`
- **Soft delete:** `obrisan` polje

## 🎯 **DETALJNE BUSINESS ANALIZE:**

### **1. DEMOGRAFSKA STRUKTURA:**
| Tip | Broj | % | Aktivni | Pokupljeni |
|-----|------|---|---------|------------|
| **Učenici** | 60 | 62.5% | 60 (100%) | 0 (0%) |
| **Radnici** | 36 | 37.5% | 36 (100%) | 0 (0%) |
| **UKUPNO** | **96** | 100% | **96** | **0** |

### **2. FINANSIJSKA ANALIZA:**
| Tip | Avg Cena | Total Prihod | Plaćeno | % Plaćeno |
|-----|----------|-------------|---------|-----------|
| **Učenici** | 6,005 RSD | 360,300 RSD | 51/60 | **85%** |
| **Radnici** | 3,281 RSD | 118,100 RSD | 30/36 | **83.3%** |
| **TOTAL** | 4,983 RSD | **478,400 RSD** | 81/96 | **84.4%** |

**💰 FINANSIJSKI INSIGHTS:**
- **Učenici = dvostruko skuplje** (6K vs 3.3K)
- **84.4% naplatnost** - odličan cash flow
- **478K RSD total value** - značajna suma

### **3. ADRESE PROBLEM - TEXT vs FK:**

#### **🚨 CRITICAL ISSUE: FK NEKORIŠĆENE!**
- `adresa_polaska_id` = **0 korišćenja** ❌
- `adresa_dolaska_id` = **0 korišćenja** ❌  
- **100% text adrese** umesto FK strukture! 

#### **TEXT ADRESE DISTRIBUCIJA:**

**Bela Crkva TOP locations:**
- NULL (14) - **Bez BC adrese** 
- Jasenovo fruti (5), Jasenovo (5), Kusić (5), Vg (5)
- Tri česme (4), Apolo (3), ostali...

**Vršac TOP destinations:**  
- **DIS** (38) - **50% putnika** 🏫
- Sud (10), Bolnica (6), Psihijatrija (5)
- 18 različitih lokacija ukupno

### **4. VOZAČ MONOPOL ANALIZA:**

| Vozač | Učenici | Radnici | Total | Value |
|-------|---------|---------|--------|-------|
| **Bojan** | 57 (95%) | 34 (94.4%) | **91** | 449,900 RSD |
| **NULL** | 3 (5%) | 2 (5.6%) | **5** | 28,500 RSD |

**🚨 EKSTREMNI MONOPOL:**
- **Bojan = 94.8% svih putnika**
- **94.8% finansijske vrednosti** 
- **Single point of failure** kritičan!

### **5. PUTOVANJA STATISTIKE:**
- **broj_putovanja** = 0 (sve) ❓ **Nije se koristilo**
- **broj_otkazivanja** = 0 (sve) ❓ **Tracking neaktivan**
- **pokupljen** = false (100%) **Pickup sistem neimplementiran**

## 🚨 **KRITIČNI PROBLEMI:**

### **A) ADDRESS ARCHITECTURE:**
```sql
-- PROBLEM: Text adrese umesto FK
-- REŠENJE: Migracija na strukturne veze
UPDATE mesecni_putnici SET 
  adresa_polaska_id = (SELECT id FROM adrese WHERE naziv = adresa_bela_crkva),
  adresa_dolaska_id = (SELECT id FROM adrese WHERE naziv = adresa_vrsac);
```

### **B) TRACKING NEAKTIVAN:**
```sql
-- broj_putovanja i broj_otkazivanja nisu tracking-ovani
-- pokupljen sistem nije implementiran  
-- statistics jsonb field prazan
```

### **C) LOAD BALANCING:**
```sql
-- 91/96 putnika na Bojanu
-- Potrebna redistribucija na ostale vozače
```

## 💡 **PREPORUKE:**

### **1. Address Migration:**
- Implementiraj FK veze umesto text
- Koristi postojeću `adrese` tabelu  

### **2. Tracking Aktivacija:**
- Uključi broj_putovanja counting
- Implementiraj pickup sistem
- Popuni statistics jsonb

### **3. Load Distribution:**
- Redistribuiraj na 4 vozača
- Bojan max 30-40 putnika

---

## 📈 **ZAVRŠETAK ANALIZE:**

**Status:** ✅ **BUSINESS KRITIČNI NALAZI**
- **Monopol Bojana** = 94.8% sistema 🚨
- **Text adrese** umesto FK strukture ❌  
- **Tracking sistemi** neaktivni 📊
- **Finansije** = 478K RSD, 84% naplatnost ✅

**PRIORITET: Address migration + Load balancing!** ⚡