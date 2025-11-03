# Analiza mapiranja - Tabela VOZILA

## Pregled tabele u Supabase

```sql
create table public.vozila (
  id uuid not null default gen_random_uuid (),
  registarski_broj character varying not null,
  marka character varying null,
  model character varying null,
  godina_proizvodnje integer null,
  broj_mesta integer null,
  aktivan boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint vozila_pkey primary key (id),
  constraint vozila_registarski_broj_key unique (registarski_broj)
)
```

## Dart model - klasa Vozilo

```dart
class Vozilo {
  final String id;                    // uuid
  final String registracija;          // registarski_broj
  final String? marka;                // character varying
  final String? model;                // character varying
  final int? godinaProizvodnje;       // integer
  final int brojSedista;              // broj_mesta
  final bool aktivan;                 // boolean
  final DateTime createdAt;           // timestamp with time zone
  final DateTime updatedAt;           // timestamp with time zone
}
```

## Mapiranje kolona

| Supabase kolona | Dart property | Tip Supabase | Tip Dart | Mapiranje status |
|-----------------|---------------|--------------|----------|------------------|
| `id` | `id` | `uuid` | `String` | ✅ DOBRO |
| `registarski_broj` | `registracija` | `character varying` | `String` | ✅ DOBRO |
| `marka` | `marka` | `character varying` | `String?` | ✅ DOBRO |
| `model` | `model` | `character varying` | `String?` | ✅ DOBRO |
| `godina_proizvodnje` | `godinaProizvodnje` | `integer` | `int?` | ✅ DOBRO |
| `broj_mesta` | `brojSedista` | `integer` | `int` | ✅ DOBRO |
| `aktivan` | `aktivan` | `boolean` | `bool` | ✅ DOBRO |
| `created_at` | `createdAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |
| `updated_at` | `updatedAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |

## FromMap/ToMap mapiranje

### FromMap:
- ✅ `map['registarski_broj']` -> `registracija` (dobro mapiranje)
- ✅ `map['broj_mesta']` -> `brojSedista` (dobro mapiranje)
- ✅ Svi ostali keyovi se poklapaju sa kolonama

### ToMap:
- ✅ `registracija` -> `'registarski_broj'` (dobro mapiranje)
- ✅ `brojSedista` -> `'broj_mesta'` (dobro mapiranje)
- ✅ Svi ostali keyovi se poklapaju sa kolonama

## Ograničenja baze

1. ✅ **Primary Key**: `id` kao UUID - implementirano
2. ✅ **Unique constraint**: `registarski_broj` mora biti jedinstven - implementirano
3. ✅ **NOT NULL**: `registarski_broj` - implementirano kao required
4. ✅ **Default values**: `aktivan=true` - implementirano

## Model specifičnosti

### ✅ DOBRE FUNKCIONALNOSTI:
1. **Unique field mapping**: `registarski_broj` <-> `registracija`
2. **Default values**: `brojSedista = 50` (razumna default vrednost za autobus)
3. **Computed property**: `punNaziv` getter koji kombinuje marku, model i registraciju

### 💡 JEDNOSTAVAN ALI EFIKASAN:
- Model je jednostavan i fokusiran
- Nema nepotrebnih komplikacija
- Dobro handluje nullable polja

## Preporuke za poboljšanje

### 💡 PREPORUKE:
1. **Validacije**: Dodati validaciju za srpske registarske brojeve
2. **Constants**: Dodati konstante za tipične brojeve sedišta
3. **Business logic**: Dodati metode za računanje kapaciteta
4. **UI helpers**: Dodati status icon ili color getters

### 🔧 PRIMER POBOLJŠANJA:
```dart
// Validacija registarske tablice
bool get isValidRegistracija {
  final srbijanRegex = RegExp(r'^[A-Z]{2}-?\d{3,4}-?[A-Z]{2}$');
  return srbijanRegex.hasMatch(registracija.replaceAll('-', ''));
}

// Status za UI
String get statusIcon => aktivan ? '✅' : '❌';

// Kategorija vozila
String get kategorijaVozila {
  if (brojSedista <= 9) return 'Minibus';
  if (brojSedista <= 30) return 'Srednji autobus';
  return 'Veliki autobus';
}
```

## ZAKLJUČAK
✅ **Mapiranje je SAVRŠENO** - sva polja su dobro mapirana između baze i modela.
✅ **JEDNOSTAVNA I ČISTA IMPLEMENTACIJA** - model je dobro dizajniran bez nepotrebnih komplikacija.
💡 **PROSTOR ZA POBOLJŠANJA** - mogu se dodati validacije i helper metode.
🏅 **DOBAR PRIMER** jednostavnog ali efikasnog modela.