# Analiza mapiranja - Tabela DNEVNI_PUTNICI

## Pregled tabele u Supabase

```sql
create table public.dnevni_putnici (
  id uuid not null default gen_random_uuid (),
  putnik_ime character varying not null,
  telefon character varying null,
  grad character varying not null,
  broj_mesta integer null,
  datum_putovanja date not null,
  vreme_polaska character varying null,
  cena numeric null,
  status character varying null default 'aktivno'::character varying,
  naplatio_vozac_id uuid null,
  pokupio_vozac_id uuid null,
  dodao_vozac_id uuid null,
  otkazao_vozac_id uuid null,
  vozac_id uuid null,
  obrisan boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  ruta_id uuid null,
  vozilo_id uuid null,
  adresa_id uuid null,
  -- Foreign Keys:
  constraint dnevni_putnici_adresa_id_fkey foreign KEY (adresa_id) references adrese (id),
  constraint dnevni_putnici_ruta_id_fkey foreign KEY (ruta_id) references rute (id),
  constraint dnevni_putnici_vozac_id_fkey foreign KEY (vozac_id) references vozaci (id),
  -- ... ostali FK-ovi
)
```

## Dart model - klasa DnevniPutnik

```dart
class DnevniPutnik {
  final String id;                         // uuid
  final String ime;                        // ???
  final String? brojTelefona;              // ???
  final String adresaId;                   // uuid (FK)
  final String rutaId;                     // uuid (FK)
  final DateTime datumPutovanja;           // date
  final String vremePolaska;               // character varying
  final int brojMesta;                     // integer
  final double cena;                       // numeric
  final DnevniPutnikStatus status;         // character varying (enum)
  final String? napomena;                  // ???
  final DateTime? vremePokupljenja;        // ???
  final String? pokupioVozacId;            // uuid (FK)
  final DateTime? vremePlacanja;           // ???
  final String? naplatioVozacId;           // uuid (FK)
  final String? dodaoVozacId;              // uuid (FK)
  final bool obrisan;                      // boolean
  final DateTime createdAt;                // timestamp with time zone
  final DateTime updatedAt;                // timestamp with time zone
}
```

## ❌ KRITIČNE GREŠKE U MAPIRANJU

### Problemi u FromMap:

| Supabase kolona | Dart property | FromMap ključ | Status |
|-----------------|---------------|---------------|---------|
| `putnik_ime` | `ime` | `'ime'` | ❌ **POGREŠNO** |
| `telefon` | `brojTelefona` | `'broj_telefona'` | ❌ **POGREŠNO** |
| `datum_putovanja` | `datumPutovanja` | `'datum'` | ❌ **POGREŠNO** |
| `vreme_polaska` | `vremePolaska` | `'polazak'` | ❌ **POGREŠNO** |
| `status` | `status` | `'status'` | ✅ DOBRO |
| `naplatio_vozac_id` | `naplatioVozacId` | `'naplatio_vozac_id'` | ✅ DOBRO |
| `pokupio_vozac_id` | `pokupioVozacId` | `'pokupio_vozac_id'` | ✅ DOBRO |
| `dodao_vozac_id` | `dodaoVozacId` | `'dodao_vozac_id'` | ✅ DOBRO |

### Problemi u ToMap:

| Dart property | Supabase kolona | ToMap ključ | Status |
|---------------|-----------------|-------------|---------|
| `ime` | `putnik_ime` | `'ime'` | ❌ **POGREŠNO** |
| `brojTelefona` | `telefon` | `'broj_telefona'` | ❌ **POGREŠNO** |
| `datumPutovanja` | `datum_putovanja` | `'datum'` | ❌ **POGREŠNO** |
| `vremePolaska` | `vreme_polaska` | `'polazak'` | ❌ **POGREŠNO** |

### ❌ NEDOSTAJU KOLONE U SUPABASE TABELI:
1. `napomena` - nema u tabeli, ali postoji u modelu
2. `vreme_pokupljenja` - nema u tabeli, ali postoji u modelu  
3. `vreme_placanja` - nema u tabeli, ali postoji u modelu

### ❌ NEDOSTAJU KOLONE U MODELU:
1. `grad` - postoji u tabeli, nema u modelu
2. `otkazao_vozac_id` - postoji u tabeli, nema u modelu
3. `vozac_id` - postoji u tabeli, nema u modelu
4. `vozilo_id` - postoji u tabeli, nema u modelu

## Status incompatibilnost

### Supabase default: `'aktivno'`
### Model enum statusi:
- `rezervisan`
- `pokupljen` 
- `otkazan`
- `bolovanje`
- `godisnji`

❌ **Default vrednost 'aktivno' se ne nalazi u enum-u!**

## ZAKLJUČAK
❌ **MAPIRANJE JE KOMPLETNO POGREŠNO** - postoje kritične greške:

1. **Ključevi ne odgovaraju**: FromMap/ToMap koriste pogrešne ključeve
2. **Nedostaju kolone**: U oba smera nedostaju kolone  
3. **Status incompatibilnost**: Default vrednosti se ne poklapaju
4. **FK incompatibilnost**: Neki FK-ovi nisu implementirani

## 🚨 HITNO POTREBNE ISPRAVKE:

### 1. Popraviti FromMap mapiranje:
```dart
factory DnevniPutnik.fromMap(Map<String, dynamic> map) {
  return DnevniPutnik(
    ime: map['putnik_ime'] as String,           // ISPRAVKA
    brojTelefona: map['telefon'] as String?,    // ISPRAVKA
    datumPutovanja: DateTime.parse(map['datum_putovanja'] as String), // ISPRAVKA
    vremePolaska: map['vreme_polaska'] as String, // ISPRAVKA
    // ... ostalo
  );
}
```

### 2. Popraviti ToMap mapiranje:
```dart
Map<String, dynamic> toMap() {
  return {
    'putnik_ime': ime,                          // ISPRAVKA
    'telefon': brojTelefona,                    // ISPRAVKA  
    'datum_putovanja': datumPutovanja.toIso8601String().split('T')[0], // ISPRAVKA
    'vreme_polaska': vremePolaska,              // ISPRAVKA
    // ... ostalo
  };
}
```

### 3. Dodati nedostajuće kolone
### 4. Uskladiti status vrednosti
### 5. Implementirati nedostajuće FK-ove

🔥 **OVO JE NAJVAŽNIJA GREŠKA U CELOM PROJEKTU!**