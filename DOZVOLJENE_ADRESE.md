# PLAN: Dozvoljene Adrese - Zatvoreni Sistem

## 📋 CILJ
Implementirati sistem gde su adrese fiksirane i kontrolisane od strane admina:
- Samo admin može dodati novu adresu sa koordinatama
- Korisnici (vozači) biraju iz postojećih odobrenih adresa
- Nova adresa = zahtev adminu za odobrenje

---

## 🔍 ANALIZA POSTOJEĆEG STANJA (Decembar 2025)

### Tabela `adrese` (trenutna struktura)
```sql
id              UUID PRIMARY KEY
naziv           TEXT          -- "Bolnica", "VG", "Posta"
grad            TEXT          -- "Bela Crkva", "Vršac"
ulica           TEXT
broj            TEXT
koordinate      JSONB         -- {"lat": 45.12, "lng": 21.30}
created_at      TIMESTAMP
updated_at      TIMESTAMP
```

### Servis `AdresaSupabaseService` - KLJUČNE METODE (lib/services/adresa_supabase_service.dart)
1. `createOrGetAdresa()` - **PROBLEM**: Bilo ko može kreirati novu adresu sa geocodingom
2. `searchAdrese()` - Pretraga za autocomplete (bez filtera za odobrenje)
3. `getAdreseZaGrad()` - Lista adresa po gradu (bez filtera za odobrenje)
4. `updateKoordinate()` - Ažurira koordinate
5. `getAdreseBezKoordinata()` - Lista adresa bez koordinata
6. `updateKoordinateFromGps()` - GPS learning za koordinate

### Model `Adresa` (lib/models/adresa.dart)
- Ima `fromMap()` i `toMap()` metode
- Nema polje `odobrena` trenutno
- JSONB koordinate sa `lat/lng`

### Admin ekran (lib/screens/admin_screen.dart)
- Postoji admin panel sa raznim funkcijama
- Već ima pristup GeocodingAdminScreen za upravljanje koordinatama
- Koristi se za PIN zahteve (sličan workflow kao za adrese)

### Trenutni tok (PROBLEMATIČAN):
```
Vozač unosi "Nova Adresa" → createOrGetAdresa() → KREIRA NOVU + GEOCODING bez odobrenja
```

---

## 📊 KOMPARATIVNA ANALIZA OPCIJA

### OPCIJA A: Dodati `odobrena` kolonu u postojeću tabelu ⭐ PREPORUČENO

**Prednosti:**
- ✅ Minimalne izmene baze (2 kolone)
- ✅ Kompatibilno sa postojećim kodom
- ✅ Jednostavna implementacija (~1h)
- ✅ Zahtevi se vide direktno u istoj tabeli
- ✅ Jedan query za sve (odobrene, neodobrene, sve)
- ✅ Jednostavan admin panel (filter po `odobrena`)

**Nedostaci:**
- ⚠️ Nema istorije zahteva (ko je odbio, kada)
- ⚠️ Nema napomena za odbijanje

**Izmene u bazi:**
```sql
-- Dodaj kolone
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS odobrena BOOLEAN DEFAULT false;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_od TEXT;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_datum TIMESTAMP;

-- Označi SVE postojeće adrese kao odobrene (imaju koordinate = bile su korišćene)
UPDATE adrese SET odobrena = true WHERE koordinate IS NOT NULL;

-- Adrese bez koordinata ostaju neodobrene (11 adresa)
-- UPDATE adrese SET odobrena = false WHERE koordinate IS NULL; -- DEFAULT je false
```

**Izmene u kodu:**

1. **Model `Adresa`** - dodati polja:
```dart
final bool odobrena;
final String? zahtevOd;
final DateTime? zahtevDatum;
```

2. **Servis** - filtriraj SAMO odobrene za korisnike:
```dart
// getAdreseZaGrad() - dodati
.eq('odobrena', true)

// searchAdrese() - dodati
.eq('odobrena', true)

// createOrGetAdresa() - postaviti odobrena = false za nove
'odobrena': false,
'zahtev_od': vozacId,
'zahtev_datum': DateTime.now().toIso8601String(),
```

3. **Admin panel** - nova sekcija:
```dart
// Lista neodobrenih adresa
Future<List<Adresa>> getNeodobreneAdrese()
// Odobri adresu
Future<bool> odobriAdresu(String id)
// Odbij/obriši zahtev
Future<bool> odbijAdresu(String id)
```

---

### OPCIJA B: Nova tabela `zahtevi_adresa`

**Prednosti:**
- ✅ Čistije razdvajanje (odobrene vs zahtevi)
- ✅ Detaljan workflow (status: ceka/odobreno/odbijeno)
- ✅ Istorija svih zahteva
- ✅ Napomene za odbijanje

**Nedostaci:**
- ❌ Kompleksnije (2 tabele)
- ❌ Više koda za sinhronizaciju
- ❌ Treba prebacivati iz zahteva u adrese
- ❌ Više vremena za implementaciju (~3h)

**Nova tabela:**
```sql
CREATE TABLE zahtevi_adresa (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  naziv TEXT NOT NULL,
  grad TEXT NOT NULL,
  ulica TEXT,
  broj TEXT,
  zahtev_od TEXT NOT NULL,
  status TEXT DEFAULT 'ceka',   -- 'ceka', 'odobreno', 'odbijeno'
  napomena TEXT,
  koordinate_predlog JSONB,     -- ako vozač ima GPS
  obradio TEXT,                 -- admin koji je obradio
  obradio_datum TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### OPCIJA C: Hybrid - Kolona + Soft delete za istoriju

**Prednosti:**
- ✅ Jednostavno kao Opcija A
- ✅ Čuva istoriju odbijenih

**Nova kolona:**
```sql
ALTER TABLE adrese ADD COLUMN status TEXT DEFAULT 'odobrena';
-- Moguće vrednosti: 'odobrena', 'ceka', 'odbijena'
```

---

## 🎯 PREPORUKA: OPCIJA A (Kolona `odobrena`)

### Zašto?
1. **Manje koda** - samo dodaj filter `.eq('odobrena', true)`
2. **Postojeće adrese rade** - samo ih označimo kao odobrene
3. **Brže** - implementacija za ~1h
4. **Dovoljno za potrebe** - zahtevi se vide u tabeli (odobrena = false)
5. **Sličan pattern** - već imate PIN zahteve sa sličnom logikom
6. **Jednostavan admin** - već postoji `GeocodingAdminScreen` kao template

---

## 📝 PLAN IMPLEMENTACIJE (Opcija A)

### FAZA 1: Baza (5 min)
```sql
-- Supabase SQL Editor
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS odobrena BOOLEAN DEFAULT false;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_od TEXT;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_datum TIMESTAMP;

-- Označi sve postojeće adrese SA koordinatama kao odobrene
UPDATE adrese SET odobrena = true WHERE koordinate IS NOT NULL;

-- Verifikacija
SELECT COUNT(*) as ukupno, 
       COUNT(*) FILTER (WHERE odobrena = true) as odobrene,
       COUNT(*) FILTER (WHERE odobrena = false OR odobrena IS NULL) as neodobrene
FROM adrese;
```

### FAZA 2: Model `Adresa` (10 min)
**Fajl:** `lib/models/adresa.dart`

Dodati polja:
```dart
final bool odobrena;
final String? zahtevOd;
final DateTime? zahtevDatum;
```

Ažurirati `fromMap()`:
```dart
odobrena: map['odobrena'] as bool? ?? false,
zahtevOd: map['zahtev_od'] as String?,
zahtevDatum: map['zahtev_datum'] != null 
    ? DateTime.parse(map['zahtev_datum'] as String) 
    : null,
```

Ažurirati `toMap()`:
```dart
'odobrena': odobrena,
'zahtev_od': zahtevOd,
'zahtev_datum': zahtevDatum?.toIso8601String(),
```

### FAZA 3: Servis `AdresaSupabaseService` (20 min)
**Fajl:** `lib/services/adresa_supabase_service.dart`

**3.1 Izmeni `getAdreseZaGrad()`:**
```dart
static Future<List<Adresa>> getAdreseZaGrad(String grad, {bool samoOdobrene = true}) async {
  try {
    var query = supabase.from('adrese').select('*').eq('grad', grad);
    
    if (samoOdobrene) {
      query = query.eq('odobrena', true);
    }
    
    final response = await query.order('naziv');
    return response.map((json) => Adresa.fromMap(json)).toList();
  } catch (e) {
    return [];
  }
}
```

**3.2 Izmeni `searchAdrese()`:**
```dart
static Future<List<Adresa>> searchAdrese(String query, {String? grad, bool samoOdobrene = true}) async {
  try {
    var queryBuilder = supabase.from('adrese').select().ilike('naziv', '%$query%');

    if (grad != null) {
      queryBuilder = queryBuilder.eq('grad', grad);
    }
    
    if (samoOdobrene) {
      queryBuilder = queryBuilder.eq('odobrena', true);
    }

    final response = await queryBuilder.order('naziv').limit(20);
    return response.map((json) => Adresa.fromMap(json)).toList();
  } catch (e) {
    return [];
  }
}
```

**3.3 Izmeni `createOrGetAdresa()` - nova adresa je NEODOBRENA:**
```dart
// Pri INSERT-u nove adrese:
final response = await supabase.from('adrese').insert({
  'naziv': naziv,
  'grad': grad,
  'ulica': ulica ?? naziv,
  'broj': broj,
  'odobrena': false,  // 🆕 Nova adresa nije odobrena
  'zahtev_od': zahtevOd,  // 🆕 Ko je zatražio
  'zahtev_datum': DateTime.now().toIso8601String(),  // 🆕 Kada
  if (geoLat != null && geoLng != null) 'koordinate': {'lat': geoLat, 'lng': geoLng},
}).select('*').single();
```

**3.4 Nove admin metode:**
```dart
/// 🔐 ADMIN: Dobij sve neodobrene adrese (zahtevi)
static Future<List<Adresa>> getNeodobreneAdrese() async {
  try {
    final response = await supabase
        .from('adrese')
        .select('*')
        .eq('odobrena', false)
        .order('zahtev_datum', ascending: false);
    return response.map((json) => Adresa.fromMap(json)).toList();
  } catch (e) {
    return [];
  }
}

/// 🔐 ADMIN: Odobri adresu
static Future<bool> odobriAdresu(String id, {double? lat, double? lng}) async {
  try {
    final updateData = {
      'odobrena': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    // Ako admin unese koordinate prilikom odobravanja
    if (lat != null && lng != null) {
      updateData['koordinate'] = {'lat': lat, 'lng': lng};
    }
    
    await supabase.from('adrese').update(updateData).eq('id', id);
    _cache.remove(id);
    return true;
  } catch (e) {
    return false;
  }
}

/// 🔐 ADMIN: Odbij/obriši zahtev za adresu
static Future<bool> odbijAdresu(String id) async {
  try {
    await supabase.from('adrese').delete().eq('id', id);
    _cache.remove(id);
    return true;
  } catch (e) {
    return false;
  }
}

/// 🔐 ADMIN: Broj neodobrenih adresa (za badge)
static Future<int> getBrojNeodobrenihAdresa() async {
  try {
    final response = await supabase
        .from('adrese')
        .select('id')
        .eq('odobrena', false);
    return response.length;
  } catch (e) {
    return 0;
  }
}
```

### FAZA 4: UI - Autocomplete (10 min)
**Fajl:** `lib/widgets/registrovani_putnik_dialog.dart` i drugi koji koriste autocomplete

Kada korisnik unese adresu koja ne postoji:
```dart
if (adreseResults.isEmpty) {
  // Prikaz poruke umesto kreiranja
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Adresa "$query" nije u sistemu.\nKontaktirajte admina za dodavanje.'),
      backgroundColor: Colors.orange,
    ),
  );
}
```

### FAZA 5: Admin Panel za Adrese (30 min)
**Novi fajl:** `lib/screens/adrese_zahtevi_screen.dart`

Template po uzoru na `pin_zahtevi_screen.dart`:
- Lista neodobrenih adresa
- Swipe za odobrenje/odbijanje
- Unos koordinata pri odobravanju (opciono)
- Badge sa brojem zahteva na AdminScreen

---

## ⚠️ VAŽNE NAPOMENE

1. **Existing koordinate** - sve adrese sa koordinatama automatski postaju odobrene
2. **Bez koordinata** - adrese bez koordinata ostaju neodobrene (~11 takvih)
3. **Autocomplete** - prikazuje SAMO odobrene
4. **Nova adresa** - ne kreira automatski, samo zahtev za admina
5. **Backward compatible** - postojeće funkcije rade, samo dodajemo filter

---

## 📊 STATISTIKA ADRESA

- Ukupno adresa: ~95
- Sa koordinatama (biće odobrene): ~84
- Bez koordinata (neodobrene): ~11

---

## 🔄 MIGRACIJA POSTOJEĆIH PODATAKA

```sql
-- KORAK 1: Dodaj kolone
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS odobrena BOOLEAN DEFAULT false;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_od TEXT;
ALTER TABLE adrese ADD COLUMN IF NOT EXISTS zahtev_datum TIMESTAMP;

-- KORAK 2: Označi postojeće adrese kao odobrene
UPDATE adrese SET odobrena = true WHERE koordinate IS NOT NULL;

-- KORAK 3: Za adrese bez koordinata, postavi kao neodobrene sa datumom
UPDATE adrese 
SET odobrena = false, 
    zahtev_datum = created_at,
    zahtev_od = 'sistem_migracija'
WHERE koordinate IS NULL;

-- KORAK 4: Kreiraj indeks za brže pretrage
CREATE INDEX IF NOT EXISTS idx_adrese_odobrena ON adrese(odobrena);
CREATE INDEX IF NOT EXISTS idx_adrese_grad_odobrena ON adrese(grad, odobrena);
```

---

## ✅ CHECKLIST ZA IMPLEMENTACIJU

- [ ] SQL migracija (kolone + update postojećih)
- [ ] Model `Adresa` - nova polja
- [ ] Servis - filter za odobrene
- [ ] Servis - admin metode (getNeodobrene, odobri, odbij)
- [ ] UI autocomplete - poruka za nepostojeće adrese
- [ ] Admin screen - sekcija za zahteve adresa
- [ ] Badge sa brojem zahteva
- [ ] Testiranje

---

## 🚀 SLEDEĆI KORACI

Kada odobriš plan:
1. Prvo ću izvršiti SQL migraciju na Supabase
2. Zatim ću ažurirati Model i Servis
3. Na kraju admin panel

**Pitanje:** Da li da implementiram **Opciju A** kako je predloženo?
