# Analiza mapiranja - Tabela MESECNI_PUTNICI

## Pregled tabele u Supabase

```sql
create table public.mesecni_putnici (
  id uuid not null default gen_random_uuid (),
  putnik_ime character varying not null,
  tip character varying not null,
  tip_skole character varying null,
  broj_telefona character varying null,
  broj_telefona_oca character varying null,
  broj_telefona_majke character varying null,
  polasci_po_danu jsonb not null,
  adresa_bela_crkva text null,
  adresa_vrsac text null,
  tip_prikazivanja character varying null default 'standard'::character varying,
  radni_dani character varying null,
  aktivan boolean null default true,
  status character varying null default 'aktivan'::character varying,
  datum_pocetka_meseca date not null,
  datum_kraja_meseca date not null,
  ukupna_cena_meseca numeric null,
  cena numeric null,
  broj_putovanja integer null default 0,
  broj_otkazivanja integer null default 0,
  poslednje_putovanje timestamp with time zone null,
  vreme_placanja timestamp with time zone null,
  placeni_mesec integer null,
  placena_godina integer null,
  vozac_id uuid null,
  pokupljen boolean null default false,
  vreme_pokupljenja timestamp with time zone null,
  statistics jsonb null default '{}'::jsonb,
  obrisan boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  ruta_id uuid null,
  vozilo_id uuid null,
  adresa_polaska_id uuid null,
  adresa_dolaska_id uuid null,
  ime character varying null,
  prezime character varying null,
  datum_pocetka date null,
  datum_kraja date null,
  -- Foreign Keys:
  constraint mesecni_putnici_vozac_id_fkey foreign KEY (vozac_id) references vozaci (id),
  constraint mesecni_putnici_ruta_id_fkey foreign KEY (ruta_id) references rute (id),
  constraint mesecni_putnici_vozilo_id_fkey foreign KEY (vozilo_id) references vozila (id),
  constraint mesecni_putnici_adresa_polaska_id_fkey foreign KEY (adresa_polaska_id) references adrese (id),
  constraint mesecni_putnici_adresa_dolaska_id_fkey foreign KEY (adresa_dolaska_id) references adrese (id)
)
```

## Dart model - klasa MesecniPutnik

```dart
class MesecniPutnik {
  final String id;                              // uuid
  final String putnikIme;                       // character varying
  final String? brojTelefona;                   // character varying
  final String? brojTelefonaOca;                // character varying
  final String? brojTelefonaMajke;              // character varying
  final String tip;                             // character varying
  final String? tipSkole;                       // character varying
  final Map<String, List<String>> polasciPoDanu; // jsonb
  final String? adresaBelaCrkva;                // text
  final String? adresaVrsac;                    // text
  final String radniDani;                       // character varying
  final DateTime datumPocetkaMeseca;            // date
  final DateTime datumKrajaMeseca;              // date
  final DateTime createdAt;                     // timestamp with time zone
  final DateTime updatedAt;                     // timestamp with time zone
  final bool aktivan;                           // boolean
  final String status;                          // character varying
  final double ukupnaCenaMeseca;                // numeric
  final double? cena;                           // numeric
  final int brojPutovanja;                      // integer
  final int brojOtkazivanja;                    // integer
  final DateTime? poslednjePutovanje;           // timestamp with time zone
  final bool obrisan;                           // boolean
  final DateTime? vremePlacanja;                // timestamp with time zone
  final int? placeniMesec;                      // integer
  final int? placenaGodina;                     // integer
  final Map<String, dynamic> statistics;       // jsonb
  
  // Nova polja iz baze
  final String tipPrikazivanja;                 // character varying
  final String? vozacId;                        // uuid (FK)
  final bool pokupljen;                         // boolean
  final DateTime? vremePokupljenja;             // timestamp with time zone
  final String? rutaId;                         // uuid (FK)
  final String? voziloId;                       // uuid (FK)
  final String? adresaPolaskaId;                // uuid (FK)
  final String? adresaDolaskaId;                // uuid (FK)
  final String? ime;                            // character varying
  final String? prezime;                        // character varying
  final DateTime? datumPocetka;                 // date
  final DateTime? datumKraja;                   // date
}
```

## Mapiranje kolona

| Supabase kolona | Dart property | Tip Supabase | Tip Dart | Mapiranje status |
|-----------------|---------------|--------------|----------|------------------|
| `id` | `id` | `uuid` | `String` | ✅ DOBRO |
| `putnik_ime` | `putnikIme` | `character varying` | `String` | ✅ DOBRO |
| `tip` | `tip` | `character varying` | `String` | ✅ DOBRO |
| `tip_skole` | `tipSkole` | `character varying` | `String?` | ✅ DOBRO |
| `broj_telefona` | `brojTelefona` | `character varying` | `String?` | ✅ DOBRO |
| `broj_telefona_oca` | `brojTelefonaOca` | `character varying` | `String?` | ✅ DOBRO |
| `broj_telefona_majke` | `brojTelefonaMajke` | `character varying` | `String?` | ✅ DOBRO |
| `polasci_po_danu` | `polasciPoDanu` | `jsonb` | `Map<String, List<String>>` | ✅ DOBRO |
| `adresa_bela_crkva` | `adresaBelaCrkva` | `text` | `String?` | ✅ DOBRO |
| `adresa_vrsac` | `adresaVrsac` | `text` | `String?` | ✅ DOBRO |
| `tip_prikazivanja` | `tipPrikazivanja` | `character varying` | `String` | ✅ DOBRO |
| `radni_dani` | `radniDani` | `character varying` | `String` | ✅ DOBRO |
| `aktivan` | `aktivan` | `boolean` | `bool` | ✅ DOBRO |
| `status` | `status` | `character varying` | `String` | ✅ DOBRO |
| `datum_pocetka_meseca` | `datumPocetkaMeseca` | `date` | `DateTime` | ✅ DOBRO |
| `datum_kraja_meseca` | `datumKrajaMeseca` | `date` | `DateTime` | ✅ DOBRO |
| `ukupna_cena_meseca` | `ukupnaCenaMeseca` | `numeric` | `double` | ✅ DOBRO |
| `cena` | `cena` | `numeric` | `double?` | ✅ DOBRO |
| `broj_putovanja` | `brojPutovanja` | `integer` | `int` | ✅ DOBRO |
| `broj_otkazivanja` | `brojOtkazivanja` | `integer` | `int` | ✅ DOBRO |
| `poslednje_putovanje` | `poslednjePutovanje` | `timestamp with time zone` | `DateTime?` | ⚠️ **PROBLEMATIČNO** |
| `vreme_placanja` | `vremePlacanja` | `timestamp with time zone` | `DateTime?` | ✅ DOBRO |
| `placeni_mesec` | `placeniMesec` | `integer` | `int?` | ✅ DOBRO |
| `placena_godina` | `placenaGodina` | `integer` | `int?` | ✅ DOBRO |
| `vozac_id` | `vozacId` | `uuid` | `String?` | ✅ DOBRO |
| `pokupljen` | `pokupljen` | `boolean` | `bool` | ✅ DOBRO |
| `vreme_pokupljenja` | `vremePokupljenja` | `timestamp with time zone` | `DateTime?` | ✅ DOBRO |
| `statistics` | `statistics` | `jsonb` | `Map<String, dynamic>` | ✅ DOBRO |
| `obrisan` | `obrisan` | `boolean` | `bool` | ✅ DOBRO |
| `created_at` | `createdAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |
| `updated_at` | `updatedAt` | `timestamp with time zone` | `DateTime` | ✅ DOBRO |
| `ruta_id` | `rutaId` | `uuid` | `String?` | ✅ DOBRO |
| `vozilo_id` | `voziloId` | `uuid` | `String?` | ✅ DOBRO |
| `adresa_polaska_id` | `adresaPolaskaId` | `uuid` | `String?` | ✅ DOBRO |
| `adresa_dolaska_id` | `adresaDolaskaId` | `uuid` | `String?` | ✅ DOBRO |
| `ime` | `ime` | `character varying` | `String?` | ✅ DOBRO |
| `prezime` | `prezime` | `character varying` | `String?` | ✅ DOBRO |
| `datum_pocetka` | `datumPocetka` | `date` | `DateTime?` | ✅ DOBRO |
| `datum_kraja` | `datumKraja` | `date` | `DateTime?` | ✅ DOBRO |

## Problemi u mapiranju

### ⚠️ PROBLEMATIČNO MAPIRANJE:

#### 1. **poslednje_putovanje vs vreme_pokupljenja**
U `fromMap`:
```dart
poslednjePutovanje: map['vreme_pokupljenja'] != null
    ? DateTime.parse(map['vreme_pokupljenja'] as String)
    : null, // ✅ FIXED: Koristi vreme_pokupljenja
```

U `toMap`:
```dart
'vreme_pokupljenja':
    poslednjePutovanje?.toIso8601String(), // ✅ FIXED: Koristi vreme_pokupljenja umesto poslednje_putovanje
```

**Problem**: Model koristi `poslednjePutovanje` ali mapira na `vreme_pokupljenja` kolonu! Ovo je konfuzno.

### ✅ ODLIČNA MAPIRANJA:
1. **JSONB handling**: Kompleksno parsiranje `polasci_po_danu` JSONB strukture
2. **Helper funkcije**: Koristi `MesecniHelpers` za parsiranje
3. **Fallback values**: Pametno handluje default vrednosti
4. **FK mappings**: Svi foreign key-jevi su dobro mapirati

## Dodatne funkcionalnosti modela

### ✅ ODLIČNE FUNKCIONALNOSTI:
1. **JSONB parsiranje**: Sofisticirano parsiranje `polasci_po_danu` strukture
2. **Helper methods**: `getPolazakBelaCrkvaZaDan()`, `getPolazakVrsacZaDan()`
3. **Validacije**: Kompleksne validacije sa phone number regex-om
4. **Business logic**: `radiDanas()`, `trebaPokupiti()`, `kalkulirajMesecnuCenu()`
5. **UI helpers**: Status colors, formatiran period, short/detail descriptions

### 💡 NAPREDNE FUNKCIONALNOSTI:
1. **Complex JSONB mapping**: Parsiranje nested strukture polazaka
2. **Phone validation**: Regex za srpske brojeve telefona
3. **Dynamic calculations**: Auto-kalkulacija mesečnih cena
4. **Flexible working days**: Support za različite radne dane

## Preporuke za poboljšanje

### 💡 PREPORUKE:
1. **Rename field**: `poslednjePutovanje` -> `vremePokupljenja` za konzistentnost
2. **Enum types**: Kreirati enum za `tip` umesto String
3. **Validation constants**: Izdvojiti regex pattern u konstante
4. **Error localization**: Izdvojiti validation poruke
5. **Performance**: Cache-ovati complex calculations

## ZAKLJUČAK
✅ **Mapiranje je VEĆINOM DOBRO** - sva polja su mapirana, ali postoji jedan konfuzan naziv.
🏆 **ODLIČNA IMPLEMENTACIJA** - model je vrlo sofisticiran sa bogatom funkcionalnostima.
⚠️ **MANJA POBOLJŠANJA** - potrebno preimenovati `poslednjePutovanje` za konzistentnost.
💯 **PREPORUČUJE SE** kao uzor za kompleksne modele sa JSONB poljima.