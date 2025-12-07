# 📊 ANALIZA MODELA - gavra_android

**Datum:** 7. decembar 2025  
**Folder:** `lib/models/`  
**Ukupno modela:** 14

---

## LISTA MODELA:

| # | Model | Importa | Status |
|---|-------|---------|--------|
| 1 | `action_log.dart` | ✅ | AKTIVAN - koristi ga mesecni_putnik_service |
| 2 | `adresa.dart` | ✅ | AKTIVAN - koristi se |
| 3 | `daily_checkin.dart` | **0** | ✅ OBRISANO |
| 4 | `dnevni_putnik.dart` | 0 | ✅ OBRISANO |
| 5 | `gps_lokacija.dart` | 1 | ✅ AKTIVAN - admin_map_screen |
| 6 | `mesecni_putnik.dart` | ✅ | AKTIVAN - mnogo importa |
| 7 | `putnik.dart` | ✅ | AKTIVAN - mnogo importa |
| 8 | `putovanja_istorija.dart` | 2 | ✅ AKTIVAN - service + screen |
| 9 | `realtime_route_data.dart` | 0 | ✅ OBRISANO |
| 10 | `ruta.dart` | 0 | ✅ OBRISANO |
| 11 | `turn_by_turn_instruction.dart` | ✅ | AKTIVAN - navigation widget |
| 12 | `vozac.dart` | ✅ | AKTIVAN - vozac_boja |
| 13 | `vozilo.dart` | 0 | ✅ OBRISANO |
| 14 | `zakazana_voznja.dart` | 0 | ✅ OBRISANO |

---

## 🗑️ ZA BRISANJE (5 modela):

| # | Model | Razlog |
|---|-------|--------|
| 1 | `daily_checkin.dart` | 0 importa |
| 2 | `dnevni_putnik.dart` | 0 importa, dnevni_putnik_service obrisan |
| 3 | `realtime_route_data.dart` | 0 importa |
| 4 | `ruta.dart` | samo dnevni_putnik ga koristi (koji se briše) |
| 5 | `vozilo.dart` | 0 importa, vozilo_service obrisan |
| 6 | `zakazana_voznja.dart` | 0 importa, zakazana_voznja_service obrisan |

---

## ✅ ZA ZADRŽAVANJE (8 modela):

| # | Model | Razlog |
|---|-------|--------|
| 1 | `action_log.dart` | koristi ga mesecni_putnik_service |
| 2 | `adresa.dart` | koristi se |
| 3 | `gps_lokacija.dart` | koristi ga admin_map_screen |
| 4 | `mesecni_putnik.dart` | mnogo importa |
| 5 | `putnik.dart` | mnogo importa |
| 6 | `putovanja_istorija.dart` | koristi ga service + screen |
| 7 | `turn_by_turn_instruction.dart` | koristi ga navigation widget |
| 8 | `vozac.dart` | koristi ga vozac_boja |

---

## ⏳ ČEKAM TVOJU ODLUKU:

Kreni sa brojem modela za brisanje (1-6) ili reci "BRIŠI SVE".
