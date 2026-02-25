# Supabase Egress Optimizacija Plan

## Problem
**Egress: 7.64 / 5 GB (153%) 🔴** — Free plan prekoračen u periodu 22-25 Feb 2026 (za 3 dana).
Ostalo je OK: DB 38MB/500MB, Realtime 5/200 konekcija, 23k/2M poruka.

## Uzrok (bio)
`streamKombinovaniPutniciFiltered` svaki put radio:
1. `rpc('get_putnoci_sa_statusom')` — vraćao sve putnike za taj dan (~15-100 redova)
2. `registrovani_putnici.select(...)` — JOIN za SVE putnike
3. Sve ovo ponavljalo se na SVAKI realtime event (seat_requests, voznje_log, registrovani_putnici)
4. Stream aktivan na 5 ekrana odjednom

---

## Sve tabele u projektu — KOMPLETNA MAPA

### Tabele u bazi (24 ukupno)

| Tabela | Koristi se u kodu | Realtime listener (trenutno) | Plan za RealtimeManager |
|---|---|---|---|
| `seat_requests` | `putnik_service`, `kombi_eta_widget`, `seat_request_service` | ✅ DA | ✅ OSTAJE — core cache (`_srCache`) |
| `voznje_log` | `putnik_service`, `voznje_log_service`, `finansije_service` | ✅ DA | ✅ OSTAJE — core cache (`_vlCache`) |
| `registrovani_putnici` | `putnik_service`, `registrovani_putnik_service`, svuda | ✅ DA | ✅ OSTAJE — core cache (`_rpCache`) |
| `registrovani_putnici_svi` | `registrovani_putnik_service` | ✅ DA (virtualna) | ✅ OSTAJE — poseban view |
| `vozaci` | `vozac_service` | ✅ DA | ✅ OSTAJE — `_vozaciCache` |
| `vozila` | `vozila_service` | ✅ DA | ✅ OSTAJE — `_vozilaCache` |
| `kapacitet_polazaka` | `kapacitet_service` | ✅ DA | ✅ OSTAJE — `_kapacitetCache` |
| `app_settings` | `app_settings_service` | ✅ DA | ✅ OSTAJE — `_settingsCache` |
| `pin_zahtevi` | `pin_zahtev_service`, `registrovani_putnik_service` | ✅ DA | ✅ OSTAJE — `_pinCache` |
| `vozac_lokacije` | `kombi_eta_widget` | ✅ DA | ✅ OSTAJE — `_lokacijeCache` |
| `adrese` | `adresa_supabase_service` | ❌ NE | ➕ DODATI — `_adreseCache` (statično, load jednom) |
| `vozac_raspored` | `vozac_raspored_service` | ❌ NE | ➕ DODATI — `_rasporedCache` |
| `vozac_putnik` | `vozac_putnik_service` | ❌ NE | ➕ DODATI — `_vozacPutnikCache` |
| `finansije_troskovi` | `finansije_service` | ❌ NE (stream direktno) | ➕ DODATI — `_troskoviCache` |
| `daily_reports` | `realtime_manager.dart` (u listi, ne subscribe) | ❌ NE | ➕ DODATI — `_dailyReportsCache` |
| `pumpa_config` | `gorivo_service` | ❌ NE | ➕ DODATI — `_pumpaConfigCache` (statično) |
| `pumpa_punjenja` | `gorivo_service` | ❌ NE | ➕ DODATI — `_pumpaPunjenja` |
| `pumpa_tocenja` | `gorivo_service` | ❌ NE | ➕ DODATI — `_pumpaTocenja` |
| `fuel_logs` | ne koristi se direktno | ❌ NE | ⏸️ ČEKATI — ispitati |
| `push_tokens` | `push_token_service`, `realtime_notification_service` | ❌ NE | ⏸️ PRESKOČITI — write-only, nema read potrebe |
| `racun_sequence` | `racun_service` | ❌ NE | ⏸️ PRESKOČITI — samo atomski counter |
| `server_secrets` | ne koristi se direktno | ❌ NE | 🚫 NIKAD — sigurnosno osjetljivo |
| `vozila_istorija` | `vozila_service` (INSERT only) | ❌ NE | ⏸️ PRESKOČITI — write-only log |
| `weather_alerts_log` | `weather_alert_service` | ❌ NE | ⏸️ PRESKOČITI — write-only log |

---

## Arhitektura — Nova (FAZA 6)

### Princip
**RealtimeManager = jedini izvor istine za SVE podatke u aplikaciji.**

Pri startu: jedan load po tabeli → sve u memoriju.
Na svaki realtime event: ažuriraj memoriju direktno iz `newRecord` → 0 upita u bazu.
Sve RPC funkcije — **eliminisane potpuno**.

### Cache mapa (sve tabele u RealtimeManager)
```
_srCache       : Map<id, row>  — seat_requests       (WHERE dan = danas, reload dnevno)
_vlCache       : Map<id, row>  — voznje_log           (WHERE datum = danas, reload dnevno)
_rpCache       : Map<id, row>  — registrovani_putnici (WHERE aktivan = true)
_vozaciCache   : Map<id, row>  — vozaci               (statično, load jednom)
_vozilaCache   : Map<id, row>  — vozila               (statično, load jednom)
_kapacitetCache: Map<id, row>  — kapacitet_polazaka   (statično, load jednom)
_settingsCache : Map<id, row>  — app_settings         (statično, load jednom)
_pinCache      : Map<id, row>  — pin_zahtevi          (aktivni zahtjevi)
_lokacijeCache : Map<id, row>  — vozac_lokacije       (aktivne lokacije)
_adreseCache   : Map<id, row>  — adrese               (statično, load jednom)
_rasporedCache : Map<id, row>  — vozac_raspored       (tjedni raspored)
_vozacPutnikCache: Map<id, row>— vozac_putnik         (mapiranje vozač↔putnik)
_troskoviCache : Map<id, row>  — finansije_troskovi   (aktivni troškovi)
_dailyReportsCache: Map<id,row>— daily_reports        (dnevni izvještaji)
_pumpaConfigCache: Map<id,row> — pumpa_config         (statično, load jednom)
_pumpaPunjenjaCache: Map<id,row>— pumpa_punjenja      (punjenja goriva)
_pumpaTocenjaCache: Map<id,row>— pumpa_tocenja        (točenja goriva)
```

### Realtime tok podataka
```
START:
  Sve tabele (17 cache-a) → load jednom u memoriju

REALTIME event (bilo koja tabela):
  newRecord → ažuriraj odgovarajući cache[id] → emituj na stream → 0 upita

APP RESUME (novi dan):
  _loadedDate != danas → reinitialize()
  → reload: _srCache, _vlCache (dnevne tabele)
  → ostale cache-ovi ostaju (statični podaci)
```

### Egress poređenje
| Situacija | Staro | Novo |
|-----------|-------|------|
| Svaki realtime event (~50/dan) | 15 redova × 50 = 750 | **0 redova** |
| Inicijalni load dnevno | višestruko | **~1000 redova jednom** |
| Ukupno dnevno | 750+ redova ponavljajuće | **~1000 redova jednom** |

---

## Status faza

| Faza | Opis | Status |
|------|------|--------|
| 1 | select kolone (putnik_service + registrovani_putnik_service) | ✅ DONE (25.02.2026) |
| 2 | Debounce refresh 600ms | ✅ DONE (25.02.2026) |
| 3 | Dispose neaktivnih streamova | ✅ OK — push route-i, dispose automatski |
| 4 | RPC server-side filter po vozaču (p_vozac_id) | ✅ DONE (25.02.2026) |
| 5 | Patch single putnik na realtime event (bez full refresh) | ✅ DONE (25.02.2026) |
| 6 | **RealtimeManager in-memory cache + eliminacija RPC** | ⏳ TODO |

---

## Sve RPC funkcije u projektu — KOMPLETNA LISTA

| RPC funkcija | Fajl | Linija | Tip | Plan |
|---|---|---|---|---|
| `get_putnoci_sa_statusom` | `putnik_service.dart` | L99, L161, L341, L473, L501, L526, L557 | Read — JOIN 3 tabele | ✂️ IZBACITI — zamjena cache-om |
| `obradi_sve_pending_zahteve` | `seat_request_service.dart` | L159 | Write — batch obrada | ✂️ IZBACITI — direktni SQL UPDATE |
| `dispecer_cron_obrada` | `seat_request_service.dart` | L164 | Write — legacy fallback | ✂️ IZBACITI — isti direktni SQL |
| `get_next_racun_broj` | `racun_service.dart` | L43 | Write — atomski counter | ✂️ IZBACITI — direktni `racun_sequence` UPDATE + SELECT |
| `get_full_finance_report` | `finansije_service.dart` | L150 | Read — agregatni izvještaj | ✂️ IZBACITI — direktni upiti voznje_log + finansije_troskovi |
| `get_custom_finance_report` | `finansije_service.dart` | L237 | Read — izvještaj po periodu | ✂️ IZBACITI — direktni upit sa WHERE datum BETWEEN |
| `update_putnik_polazak_v2` | `registrovani_putnik_profil_screen.dart` | L1663 | Write — update seat_requests | ✂️ IZBACITI — direktni `seat_requests` UPDATE |

**Ukupno: 13 poziva, 7 RPC funkcija — SVE IZBACITI.**

---

## FAZA 6 — Zadaci

### 6a. `RealtimeManager` — dodati in-memory store
- `_srCache`: `Map<String, Map<String, dynamic>>` — seat_requests po `id`
- `_vlCache`: `Map<String, Map<String, dynamic>>` — voznje_log po `id`
- `_rpCache`: `Map<String, Map<String, dynamic>>` — registrovani_putnici po `id`
- `_loadedDate`: String — datum za koji je cache učitan
- `initialize()` — učitava sve 3 tabele, subscribuje realtime
- `reinitialize()` — briše cache, ponovo učitava (novi dan)
- `AppLifecycleObserver` — detektuje resume, provjerava datum

### 6b. `putnik_service.dart` — refaktor svih 7 metoda (RPC `get_putnoci_sa_statusom`)
Sve metode koje pozivaju RPC zamjeniti čitanjem iz `RealtimeManager` memorije:
- `_doFetchForStream` → filtrira `_srCache` + `_vlCache` + `_rpCache` po `dan+grad+vreme`
- `getPutniciByDayIso` → filtrira po `dan`
- `getPutnikByName` → filtrira po imenu iz `_rpCache`
- `getPutnikFromAnyTable` → filtrira po `putnik_id`
- `getPutniciByIds` → filtrira po listi ID-eva
- `getAllPutnici` → vraća sve iz cache-a
- `_patchPutnikByIdInStreams` → čita direktno iz `newRecord`, ne ide u bazu

### 6c. JOIN logika u Dart-u
Nova helper metoda `_buildPutnik(srRow, vlRows, rpRow)`:
- Prima 1 red iz `seat_requests`, sve redove iz `voznje_log` za tog putnika, profil iz `registrovani_putnici`
- Izračunava: `je_placen`, `iznos`, `vozac_ime`, `naplatioVozac`, `otkazaoVozac`
- Vraća `Putnik` objekat
- Zamjenjuje `_rpcToPutnikMap()` + `Putnik.fromSeatRequest()`

### 6d. Novi dan / app resume
- `WidgetsBindingObserver` u `main.dart` ili `RealtimeManager`
- Na `resumed`: provjeri `_loadedDate == danas`
- Ako nije → `reinitialize()`

### 6e. `seat_request_service.dart` — RPC `obradi_sve_pending_zahteve` + `dispecer_cron_obrada`
- Zamjena: direktan `seat_requests` UPDATE WHERE `status = 'pending'`
- Logika obrade prebaciti u Dart (ili zadržati kao SQL u `execute()`, bez RPC wrappera)

### 6f. `racun_service.dart` — RPC `get_next_racun_broj`
- Zamjena: direktan `racun_sequence` UPDATE + SELECT (atomski via PostgreSQL transaction ili `upsert`)
- Tablica `racun_sequence` već postoji — RPC je samo wrapper oko nje

### 6g. `finansije_service.dart` — RPC `get_full_finance_report` + `get_custom_finance_report`
- `get_full_finance_report`: Zamjena direktnim upitima `voznje_log` + `finansije_troskovi` grupisanim po periodu (nedelja/mesec/godina) — agregatne SUM/COUNT funkcije direktno u Dart-u
- `get_custom_finance_report`: Zamjena direktnim `voznje_log.select().gte('datum', from).lte('datum', to)`

### 6h. `registrovani_putnik_profil_screen.dart` — RPC `update_putnik_polazak_v2`
- Zamjena: direktan `seat_requests` UPDATE s istim parametrima (`dan`, `grad`, `vreme`, `status`)
- Provjeriti šta tačno radi `update_putnik_polazak_v2` u bazi (može imati strani side-effect)

---

## Napomene
- Realtime connections (5/200) su OK — ne zatvarati streamove
- Free plan limit: 5 GB egress/mj
- Pro plan: $25/mj, 250 GB egress — opcija ako optimizacija nije dovoljna

---

CELA APLIKACIJA REALTIME
SVE FUNKCIJE I AKCIJE PUTNIKA I VOZACA
SVI EKRANI
SVE SVE SVE
DAN+GRAD+VREME
