# 📊 Analiza Nepotrebnih Kolona u Bazi

## 📋 Tabela: `mesecni_putnici`

### ✅ Kolone koje se KORISTE u kodu:
| Kolona | Koristi se u |
|--------|--------------|
| `id` | Putnik.fromMesecniPutnici |
| `putnik_ime` | Putnik.fromMesecniPutnici |
| `status` | Putnik.fromMesecniPutnici |
| `created_at` | vremeDodavanja |
| `updated_at` | statusVreme |
| `radni_dani` | dan |
| `vreme_pokupljenja` | vremePokupljenja |
| `vreme_placanja` | vremePlacanja |
| `cena` | cena, placeno |
| `vozac_id` | naplatioVozac |
| `dodali_vozaci` | dodaoVozac |
| `updated_by` | dodaoVozac fallback |
| `broj_telefona` | brojTelefona |
| `polasci_po_danu` | SMS service, polazak |
| `aktivan` | obrisan |
| `adresa_bela_crkva_id` | adresaId |
| `adresa_vrsac_id` | adresa |

### ⚠️ Kolone MOŽDA NEPOTREBNE (proveriti):
| Kolona | Vrednost u bazi | Analiza |
|--------|-----------------|---------|
| `tip` | "radnik" | Možda se koristi negde? |
| `tip_skole` | null | Verovatno legacy za đake |
| `broj_telefona_oca` | null | Legacy za đake |
| `broj_telefona_majke` | null | Legacy za đake |
| `tip_prikazivanja` | "standard" | Možda UI stvar? |
| `datum_pocetka_meseca` | datum | Čini se redundantno |
| `datum_kraja_meseca` | datum | Čini se redundantno |
| `ukupna_cena_meseca` | 14000.0 | Duplikat od `cena`? |
| `broj_putovanja` | 0 | Može se izračunati |
| `broj_otkazivanja` | 0 | Može se izračunati |
| `poslednje_putovanje` | null | Može se izračunati |
| `placeni_mesec` | 11 | Redundantno? |
| `placena_godina` | 2025 | Redundantno? |
| `pokupljen` | false | Možda legacy? |
| `statistics` | JSON | Može se izračunati |
| `obrisan` | false | Duplikat od aktivan? |
| `ruta_id` | null | Izgleda nekorišćeno |
| `vozilo_id` | null | Izgleda nekorišćeno |
| `adresa_polaska_id` | null | Izgleda nekorišćeno |
| `adresa_dolaska_id` | null | Izgleda nekorišćeno |
| `napomena` | null | Možda legacy |
| `pol_sub_bc` | null | Legacy subota polazak |
| `pol_sub_vs` | null | Legacy subota polazak |
| `pol_ned_bc` | null | Legacy nedelja polazak |
| `pol_ned_vs` | null | Legacy nedelja polazak |
| `adresa` | null | Legacy, zamenjen ID-jevima |
| `grad` | null | Legacy, izvlači se iz adrese |
| `firma` | null | Izgleda nekorišćeno |
| `ukupno_voznji` | 0 | Duplikat od broj_putovanja |
| `activan` | true | DUPLIKAT od `aktivan`! |
| `action_log` | [] | Prazan niz |
| `kreiran` | null | Duplikat od created_at |
| `azuriran` | null | Duplikat od updated_at |
| `putovanja_id` | null | Izgleda nekorišćeno |
| `user_id` | null | Izgleda nekorišćeno |
| `tip_prevoza` | null | Izgleda nekorišćeno |
| `placeno` | false | Redundantno, koristi se cena > 0 |
| `datum_placanja` | null | Duplikat od vreme_placanja? |
| `posebne_napomene` | null | Izgleda nekorišćeno |

---

## 📋 Tabela: `putovanja_istorija`

### ✅ Kolone koje se KORISTE:
| Kolona | Koristi se u |
|--------|--------------|
| `id` | Putnik.fromPutovanjaIstorija |
| `mesecni_putnik_id` | detekcija tabele |
| `datum_putovanja` | datum, dan |
| `vreme_polaska` | polazak |
| `status` | pokupljen, status |
| `vozac_id` | naplatioVozac, vozac |
| `napomene` | - |
| `obrisan` | obrisan |
| `created_at` | vremeDodavanja |
| `updated_at` | statusVreme |
| `cena` | cena, placeno |
| `tip_putnika` | mesecnaKarta |
| `putnik_ime` | ime |
| `created_by` | dodaoVozac |
| `action_log` | cancelled_by, vremeOtkazivanja |
| `adresa_id` | adresaId |

### ⚠️ Kolone MOŽDA NEPOTREBNE:
| Kolona | Vrednost | Analiza |
|--------|----------|---------|
| `ruta_id` | null | Izgleda nekorišćeno |
| `vozilo_id` | null | Izgleda nekorišćeno |
| `grad` | null | Čita se ali uvek null |
| `broj_telefona` | null | Čita se ali uvek null |

---

## 📋 Tabela: `vozaci`

### ✅ Kolone koje se KORISTE:
| Kolona | Koristi se |
|--------|------------|
| `id` | svuda |
| `ime` | svuda |
| `email` | settings |
| `telefon` | - |
| `aktivan` | filtriranje |
| `created_at` | - |
| `updated_at` | - |
| `kusur` | - |
| `obrisan` | soft delete |
| `deleted_at` | soft delete |
| `status` | - |

### ⚠️ Kolone koje NEDOSTAJU (treba dodati):
| Kolona | Potrebno za |
|--------|-------------|
| `boja` | VozacBoja dinamičko učitavanje |
| `sifra` | null u bazi, možda legacy? |

---

## 🔴 DEFINITIVNO NEPOTREBNE - KANDIDATI ZA BRISANJE

### `mesecni_putnici`:
```sql
-- DUPLIKATI (ista stvar pod drugim imenom):
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS activan;        -- duplikat od aktivan
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS kreiran;        -- duplikat od created_at
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS azuriran;       -- duplikat od updated_at
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ukupno_voznji;  -- duplikat od broj_putovanja

-- LEGACY KOLONE (više se ne koriste):
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_bc;     -- polasci su u polasci_po_danu JSON
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_sub_vs;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_bc;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS pol_ned_vs;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa;         -- zamenjeno adresa_*_id
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS grad;           -- izvlači se iz adrese

-- NIKAD POPUNJENE:
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS vozilo_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_polaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS adresa_dolaska_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS putovanja_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS user_id;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS tip_prevoza;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS posebne_napomene;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS firma;

-- ĐAK-SPECIFIČNE (ako nema đaka):
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS tip_skole;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS broj_telefona_oca;
ALTER TABLE mesecni_putnici DROP COLUMN IF EXISTS broj_telefona_majke;
```

### `putovanja_istorija`:
```sql
-- NIKAD POPUNJENE:
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS ruta_id;
ALTER TABLE putovanja_istorija DROP COLUMN IF EXISTS vozilo_id;
```

---

## ⚠️ OPREZ - PROVERITI PRE BRISANJA

Ove kolone mogu izgledati nepotrebne ali treba proveriti:

1. **`statistics`** - Možda se koristi za keširanje?
2. **`placeni_mesec` / `placena_godina`** - Možda za izveštaje?
3. **`tip_prikazivanja`** - Možda UI razlikovanje?
4. **`tip`** - Možda za filtriranje radnik/đak?
5. **`action_log`** - U mesecni_putnici je prazan, ali možda treba?

---

## 📌 PREPORUKA

### Faza 1 - Sigurno brisanje (0 rizik):
- `activan` (duplikat)
- `kreiran` (duplikat)  
- `azuriran` (duplikat)
- `ukupno_voznji` (duplikat)

### Faza 2 - Legacy cleanup (nizak rizik):
- `pol_sub_bc`, `pol_sub_vs`, `pol_ned_bc`, `pol_ned_vs`
- `adresa`, `grad`

### Faza 3 - Nekorišćene reference (srednji rizik):
- `ruta_id`, `vozilo_id`, `putovanja_id`, `user_id`

### Faza 4 - Đak-specifične (proveri prvo):
- `tip_skole`, `broj_telefona_oca`, `broj_telefona_majke`
