# V2 Master Realtime Manager — jedini koji sluša Supabase

## Cilj
`V2MasterRealtimeManager` otvara WebSocket za SVE tabele odmah pri startu.  
Svi ostali servisi i screeni čitaju iz `rm.*Cache` i primaju notifikacije od `rm`.  
Niko drugi ne otvara vlastite WebSocket kanale niti radi DB read upite za cacheable podatke.

---

## Može li se uraditi?

**DA.** Arhitektura to podržava. rm već ima:
- sve cache-ove za sve tabele
- `subscribe(tabela)` / `unsubscribe(tabela)` pattern
- `upsertToCache` / `removeFromCache` koji se pozivaju automatski na svaki event

Nedostaje samo: **`subscribeAll()`** — metoda koja u `initialize()` otvori kanal za sve tabele odmah.

---

## Trenutno stanje — šta još sluša Supabase direktno

### 1. `VozacCache` (lib/utils/v2_vozac_cache.dart)
- `initialize()` → poziva `V2VozacService().getAllVozaci()` → direktan DB upit
- `refresh()` → isti DB upit
- **Može biti zamijenjen:** čitati iz `rm.vozaciCache` direktno

### 2. `V2VozacService.streamAllVozaci()` (lib/services/v2_vozac_service.dart)
- Otvara vlastiti WebSocket stream za `v2_vozaci` tabelu
- Poziva se iz `main.dart` i `v2_firebase_background_handler.dart`
- **main.dart poziv:** `V2VozacService().streamAllVozaci().listen((_) {})` — samo da "krene stream"
- **Može biti zamijenjen:** rm već sluša `v2_vozaci` kada neko subscribe-uje

### 3. `V2KapacitetService` (lib/services/v2_kapacitet_service.dart)
- `initializeKapacitetCache()` → direktan DB upit za `v2_kapacitet_polazaka`
- `streamKapacitet()` → već delegira na `rm.subscribe('v2_kapacitet_polazaka')` ✅
- **Može biti zamijenjen:** `initializeKapacitetCache()` čita iz `rm.kapacitetCache`

### 4. `V2AppSettingsService` (lib/services/v2_app_settings_service.dart)
- `initialize()` → već delegira na `rm.subscribe('v2_app_settings')` ✅
- Ali otvara vlastitu pretplatu — `rm` drži kanal samo dok ovo sluša

### 5. `V2StatistikaIstorijaService` (lib/services/v2_statistika_istorija_service.dart)
- `.stream(primaryKey: ['id'])` → vlastiti Supabase `.stream()` WebSocket
- Koristi se u finansijama — historijat koji nije u rm.cache (paginovan)
- **Djelimično:** za today statistiku → `rm.statistikaCache`; za historijat → DB ostaje

### 6. `V2FinansijeService` (lib/services/v2_finansije_service.dart)
- `.stream(primaryKey: ['id'])` na `v2_statistika_istorija` i `v2_finansije_troskovi`
- Finansije su historijski izvještaji — ne mogu u static cache
- **`v2_finansije_troskovi`** → već u `rm.troskoviCache` ✅, stream nepotreban

---

## Plan refaktora

### Faza 1 — `rm.subscribeAll()` u `initialize()`
Dodati u `V2MasterRealtimeManager.initialize()`:
```dart
void _subscribeAll() {
  for (final table in _tableToCache.keys) {
    subscribe(table); // otvori kanal odmah, ne čekaj screen
  }
}
```
Pozvati na kraju `initialize()`. Od tog trenutka rm sluša sve tabele cijelo vrijeme.

### Faza 2 — `VozacCache` čita iz `rm.vozaciCache`
- `VozacCache.initialize()` → ne radi DB upit, čita iz `rm.vozaciCache.values`
- `VozacCache.refresh()` → isti pattern
- Ukloniti `V2VozacService().streamAllVozaci().listen()` iz `main.dart`

### Faza 3 — `V2KapacitetService.initializeKapacitetCache()` iz rm
- Čita iz `rm.kapacitetCache` umjesto DB upita
- `stopGlobalRealtimeListener()` u `dispose()` → nepotrebno (rm drži kanal)

### Faza 4 — `main.dart` cleanup
Ukloniti:
- `VozacCache.initialize()` → rm to rješava
- `V2KapacitetService.initializeKapacitetCache()` → rm to rješava  
- `V2VozacService().streamAllVozaci().listen((_){})` → bespotrebno

---

## Što OSTAJE na direktnom DB-u (opravdano)

| Servis | Razlog |
|---|---|
| `V2StatistikaIstorijaService` historijat | paginovani historijski upiti, ne cache |
| `V2FinansijeService` izvještaji | kompleksni agregati, ne cache |
| Svi `.insert/.update/.delete` | write operacije — uvijek direktno |
| `v2_vozac_action_log_screen` historijat | paginovano čitanje loga |
| `v2_putnik_profil_screen` statistika | per-putnik historijat |

---

## Rezultat nakon refaktora

- **1 WebSocket po tabeli** (u rm), ne N WebSocket-ova
- `main.dart` inicijalizacija: samo `rm.initialize()` → sve ostalo automatski
- `VozacCache`, `V2KapacitetService` → čitaju iz rm, nema vlastitih DB upita
- Screeni i servisi → `rm.subscribe()` za notifikacije, `rm.*Cache` za podatke
