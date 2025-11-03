# Analiza mapiranja - Tabela VOZACI

## Pregled tabele u Supabase

```sql
create table public.vozaci (
  id uuid not null default gen_random_uuid (),
  ime character varying not null,
  email character varying null,
  telefon character varying null,
  aktivan boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  kusur numeric null default 0.0,
  constraint vozaci_pkey primary key (id),
  constraint vozaci_ime_key unique (ime),
  constraint vozaci_kusur_check check ((kusur >= (0)::numeric))
)
```

## Dart model - klasa Vozac

```dart
class Vozac {
  final String id;               // uuid
  final String ime;              // character varying
  final String? brojTelefona;    // telefon -> character varying
  final String? email;           // character varying  
  final bool aktivan;            // boolean (default true)
  final double kusur;            // numeric (default 0.0)
  final DateTime createdAt;      // timestamp with time zone
  final DateTime updatedAt;      // timestamp with time zone
}
```

## Mapiranje kolona

| Supabase kolona | Dart property | Tip Supabase | Tip Dart | Mapiranje status |
|-----------------|---------------|--------------|----------|------------------|
| `id` | `id` | `uuid` | `String` | ✅ DOBRO |
| `ime` | `ime` | `character varying` | `String` | ✅ DOBRO |
| `telefon` | `brojTelefona` | `character varying` | `String?` | ✅ DOBRO |
| `email` | `email` | `character varying` | `String?` | ✅ DOBRO |
| `aktivan` | `aktivan` | `boolean` | `bool` | ✅ DOBRO |
| `kusur` | `kusur` | `numeric` | `double` | ✅ DOBRO |
| `created_at` | `createdAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |
| `updated_at` | `updatedAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |

## FromMap/ToMap mapiranje

### FromMap:
- ✅ `map['telefon']` -> `brojTelefona` (dobro mapiranje)
- ✅ Svi ostali keyovi se poklapaju sa kolonama

### ToMap:
- ✅ `brojTelefona` -> `'telefon'` (dobro mapiranje)
- ✅ Svi ostali keyovi se poklapaju sa kolonama

## Ograničenja baze

1. ✅ **Primary Key**: `id` kao UUID - implementirano
2. ✅ **Unique constraint**: `ime` mora biti jedinstveno - nema validacije u modelu
3. ✅ **Check constraint**: `kusur >= 0` - nema validacije u modelu

## Problemi i preporuke

### ⚠️ MANJKAJU VALIDACIJE:
1. **Jedinstveno ime**: Model ne proverava da li ime već postoji
2. **Kusur validacija**: Model ne proverava da kusur bude >= 0

### 💡 PREPORUKE:
1. Dodati validaciju u konstruktor za kusur >= 0
2. Dodati metodu za proveru jedinstvenog imena pre čuvanja
3. Dodati getter koji formatira telefon
4. Razmotriti dodavanje validacije za email format

## ZAKLJUČAK
✅ **Mapiranje je ISPRAVNO** - sva polja su dobro mapirana između baze i modela.
⚠️ **Manjkaju validacije** za business rules definisane u bazi.