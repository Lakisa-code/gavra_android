# Refaktor: `registrovani_putnici` → `v2_radnici` / `v2_ucenici` / `v2_dnevni` / `v2_posiljke`

## Cilj

Potpuno prelazimo na v2_ tabele. Nema mešanja starog i novog.  
Stara tabela `registrovani_putnici` ostaje u bazi dok se refaktor ne testira.

---

## Nove tabele i kolone

| Tabela | Tip putnika | Kolone |
|---|---|---|
| `v2_radnici` | radnik | `id, ime, status, telefon, telefon_2, adresa_bc_id, adresa_vs_id, pin, email, cena_po_danu, broj_mesta, created_at, updated_at` |
| `v2_ucenici` | ucenik | `id, ime, status, telefon, telefon_oca, telefon_majke, adresa_bc_id, adresa_vs_id, pin, email, cena_po_danu, broj_mesta, created_at, updated_at` |
| `v2_dnevni` | dnevni | `id, ime, status, telefon, telefon_2, adresa_bc_id, adresa_vs_id, cena, created_at, updated_at` |
| `v2_posiljke` | posiljka | `id, ime, status, telefon, adresa_bc_id, adresa_vs_id, cena, created_at, updated_at` |

### Mapiranje starih kolona na nove

| Stara kolona | Nova kolona | Napomena |
|---|---|---|
| `putnik_ime` | `ime` | preimenovana |
| `broj_telefona` | `telefon` | preimenovana |
| `broj_telefona_2` | `telefon_2` | radnici, dnevni |
| `broj_telefona_oca` | `telefon_oca` | samo ucenici |
| `broj_telefona_majke` | `telefon_majke` | samo ucenici |
| `adresa_bela_crkva_id` | `adresa_bc_id` | preimenovana |
| `adresa_vrsac_id` | `adresa_vs_id` | preimenovana |
| `cena_po_danu` | `cena_po_danu` | radnici, ucenici |
| `cena_po_danu` | `cena` | dnevni, posiljke |
| `obrisan`, `is_duplicate` | nema | filtriranje kroz status |
| `tip` | nema | određuje se tabelom |
| `treba_racun`, `firma_*` | nema | zasad, dodati ako treba |
| `vozac_id` | nema | nije u novim tabelama |
| `datum_pocetka_meseca` | nema | nije u novim tabelama |
| `datum_kraja_meseca` | nema | nije u novim tabelama |

---

## Arhitekturalna odluka: bez VIEW-a

`v2_polasci` već ima `putnik_tabela` kolonu koja kaže u kojoj tabeli je putnik.
`v2_statistika_istorija` ima `putnik_tabela` kolonu isto.

**Pristup:**
- **Čitanje jednog putnika** → `switch(putnik_tabela)` → direktan upit na pravu tabelu
- **Čitanje svih putnika** → 4 paralelna `select` upita u Dart, spoji u kodu
- **INSERT** → znaš tip → direktno u pravu tabelu
- **UPDATE** → isti ID ne može biti u dve tabele

Nema VIEW-a, nema UNION-a, nema komplikacija.

---

## Model refaktor

### `registrovani_putnik.dart` → bez promene naziva, ali kolone se ažuriraju

| Staro polje | Novo polje | Napomena |
|---|---|---|
| `putnikIme` | `ime` | DB kolona se zove `ime` |
| `brojTelefona` | `telefon` | |
| `brojTelefona2` | `telefon2` | |
| `brojTelefonaOca` | `telefonOca` | samo ucenici |
| `brojTelefonaMajke` | `telefonMajke` | samo ucenici |
| `adresaBelaCrkvaId` | `adresaBcId` | |
| `adresaVrsacId` | `adresaVsId` | |
| `tip` | `tip` | dolazi iz tabele/VIEW |

---

## FAJLOVI ZA REFAKTOR

### FAZA 1 — Model i novi servisi po tipu

| Fajl | Akcija | Status |
|---|---|:---:|
| `lib/models/registrovani_putnik.dart` | Ažuriraj fromMap/toMap na nove kolone | ⬜ |
| `v2_posiljka_service.dart` | Novi servis za v2_posiljke ✅ kreiran | ✅ |
| `v2_dnevni_service.dart` | Novi servis za v2_dnevni | ⬜ |
| `v2_radnik_service.dart` | Novi servis za v2_radnici | ⬜ |
| `v2_ucenik_service.dart` | Novi servis za v2_ucenici | ⬜ |
| `v2_putnik_service.dart` | Agregat servis — poziva sva 4 servisa | ⬜ |

### FAZA 2 — Servisi (ne-Sekcija 3)

| Fajl | Šta se menja | Status |
|---|---|:---:|
| `v2_seat_request_service.dart` | JOIN `registrovani_putnici` → direktan upit po `putnik_tabela` | ⬜ |
| `v2_pin_zahtev_service.dart` | `registrovani_putnici` → tabela po tipu (pin/email update) | ⬜ |
| `v2_finansije_service.dart` | `registrovani_putnici` → 4 tabele paralelno | ⬜ |
| `realtime_manager.dart` | `_loadRpCache` → 4 tabele paralelno | ⬜ |

### FAZA 3 — Servisi (složeni)

| Fajl | Šta se menja | Status |
|---|---|:---:|
| `putnik_service.dart` | `registrovani_putnici` → 4 tabele paralelno, `seat_requests` → `v2_polasci`, `voznje_log` → `v2_statistika_istorija` | ⬜ |
| `local_notification_service.dart` | `registrovani_putnici` → tabela po tipu, import refaktor | ⬜ |
| `notification_navigation_service.dart` | `registrovani_putnici` → tabela po tipu | ⬜ |
| `putnik_push_service.dart` | `registrovani_putnici` → tabela po tipu | ⬜ |

### FAZA 4 — Screeni i widgeti

| Fajl | Šta se menja | Status |
|---|---|:---:|
| `registrovani_putnik_login_screen.dart` | `registrovani_putnici` → tabela po tipu (pin login) | ⬜ |
| `registrovani_putnik_profil_screen.dart` | `registrovani_putnici` → tabela po tipu | ⬜ |
| `registrovani_putnici_screen.dart` | `registrovani_putnici` → 4 tabele paralelno | ⬜ |
| `vozac_action_log_screen.dart` | `registrovani_putnici` → tabela po tipu | ⬜ |
| `pin_zahtevi_screen.dart` | JOIN key `registrovani_putnici` → `v2_putnici` | ⬜ |
| `registrovani_putnik_dialog.dart` | `registrovani_putnici` → tabele po tipu | ⬜ |
| `putnik_card.dart` | komentari, logika | ⬜ |
| `pin_dialog.dart` | `registrovani_putnici` → tabela po tipu | ⬜ |

---

## REDOSLED IZVRŠAVANJA

```
1. Model: registrovani_putnik.dart             ⬜
2. v2_putnik_service.dart (novi servis)        ⬜
3. realtime_manager.dart (_loadRpCache)        ⬜
4. v2_seat_request_service.dart (JOIN fix)     ⬜
5. v2_pin_zahtev_service.dart (pin/email)      ⬜
6. v2_finansije_service.dart                   ⬜
7. putnik_service.dart                         ⬜
8. local_notification_service.dart             ⬜
9. notification_navigation_service.dart        ⬜
10. putnik_push_service.dart                   ⬜
11. Screeni (4 fajla)                          ⬜
12. Widgeti (3 fajla)                          ⬜
```

---

## Napomene

- `putnik_ime` → `ime` je najveća promena — koristiće se svuda
- `v2_putnici` VIEW je ključan — većina koda ne treba da zna tip tabele
- Za INSERT/UPDATE mora da se zna tip → ide u konkretnu tabelu
- `v2_polasci.putnik_id` referenciše ID koji postoji u jednoj od 4 tabele (UUID prostor je zajednički)
- `v2_statistika_istorija.putnik_id` — isto
- `status` kolona ostaje ista: `aktivan`, `neaktivan`, `bolovanje`, `godisnji`
- Stara tabela `registrovani_putnici` ostaje dok se ne testira sve

