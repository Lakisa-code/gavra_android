# 🗺️ MAPA POVEZANOSTI FUNKCIJA

## 🎯 GLAVNE TOKOVE U APLIKACIJI

---

## 📍 TOK 1: Dodavanje Novog Putnika

```
┌─────────────────────────────────────────────────────────┐
│ PUTNIK CARD WIDGET                                      │
│ putnik_card.dart                                        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
        ┌─────────────────────┐
        │  Korisnik klikne    │
        │  "Dodaj putnika"    │
        └────────┬────────────┘
                 │
                 ▼
    ┌──────────────────────────────────────┐
    │  _oznaciPokupljenTap() FUNCTION      │
    │  putnik_card.dart:line 245          │
    └──────────┬───────────────────────────┘
               │
               ▼
    ┌──────────────────────────────────────┐
    │  PutnikService.oznaciPokupljen()     │
    │  putnik_service.dart:line 125       │
    │                                      │
    │  - Ažurira status u supabase         │
    │  - Osvežava stream                   │
    └──────────┬───────────────────────────┘
               │
        ┌──────┴──────┬──────────┬──────────┐
        │             │          │          │
        ▼             ▼          ▼          ▼
    VoznjaLog   Vehicles   Drivers    Realtime
    logGeneric  update    update      notify
        │             │          │          │
        └──────┬──────┴──────────┴──────────┘
               │
               ▼
    ┌──────────────────────────────────────┐
    │  realtime_notification_service.dart  │
    │  sendNotificationToAllDrivers()      │
    │                                      │
    │  - Pošalje push notifikaciju         │
    │  - Osvežava sve vozače               │
    └──────────────────────────────────────┘
```

**Pronalaženje:**
```
1. Ctrl+P > putnik_card.dart
2. Ctrl+F > _oznaciPokupljenTap
3. F12 na PutnikService.oznaciPokupljen
4. Ctrl+Shift+H za sve pozive (5 referenci)
```

---

## 🎯 TOK 2: Otkazivanje Putnika

```
┌─────────────────────────────────────────┐
│ PUTNIK CARD WIDGET                      │
│ putnik_card.dart > _otkaziTap()         │
└────────────┬────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────┐
    │ putnik_service.dart                 │
    │ otkaziPutnika()                     │
    │                                     │
    │ 1. Pronađi putnika                  │
    │ 2. Ažuriraj status -> "otkazano"   │
    │ 3. Vrati vozilo u pool              │
    │ 4. Osvežava stream                  │
    └────────────┬────────────────────────┘
                 │
        ┌────────┴───────┬────────────┐
        │                │            │
        ▼                ▼            ▼
    Supabase      VoznjaLog      RealtimeNotif
    update        logGeneric()    notify
        │                │            │
        └────────┬───────┴────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────┐
    │ weekly_reset_service.dart           │
    │ - Ažurira statistiku za vozača      │
    │ - Upisuje u voznje_log              │
    └─────────────────────────────────────┘
```

**Pronalaženje:**
```
1. Ctrl+F > otkaziPutnika
2. Ctrl+Shift+H > vidi sve pozive (3 reference)
```

---

## 💰 TOK 3: Plaćanje Putnika

```
┌──────────────────────────────────────┐
│ PUTNIK CARD WIDGET                   │
│ putnik_card.dart                     │
│ > _placanjeDialog()                  │
└────────────┬─────────────────────────┘
             │
             ▼
    ┌──────────────────────────────────┐
    │ Korisnik unese iznos plaćanja     │
    │ i pritisne "Sačuvaj"             │
    └────────────┬─────────────────────┘
                 │
                 ▼
    ┌────────────────────────────────────────┐
    │ _sacuvajPlacanjeStatic()                │
    │ putnik_card.dart:line 385              │
    │                                        │
    │ 1. Validira iznos                      │
    │ 2. Kreira transaction obj              │
    │ 3. Loguje u voznje_log                 │
    └────────────┬────────────────────────────┘
                 │
        ┌────────┴───────────┬──────────┐
        │                    │          │
        ▼                    ▼          ▼
    VoznjaLog    registrovani_putnik  Supabase
    logGeneric   azurirajPlacanjeZaMesec
        │                    │          │
        └────────┬───────────┴──────────┘
                 │
                 ▼
    ┌────────────────────────────────────────┐
    │ financije_service.dart                 │
    │ recordTransaction()                    │
    │                                        │
    │ - Ažurira financije tabelu             │
    │ - Osvežava stream                      │
    └────────────────────────────────────────┘
```

**Pronalaženje:**
```
Ctrl+P > putnik_card.dart
Ctrl+F > _sacuvajPlacanjeStatic
```

---

## 📊 TOK 4: Učitavanje Putnika u ETA Widget

```
┌───────────────────────────────────────┐
│ KOMBI ETA WIDGET                      │
│ kombi_eta_widget.dart                 │
│ > build()                             │
└────────────┬────────────────────────────┘
             │
             ▼
    ┌────────────────────────────────┐
    │ initState()                    │
    │                                │
    │ Poziva:                        │
    │ 1. _loadGpsData()              │
    │ 2. _loadPokupljenjeIzBaze()    │
    │ 3. _subscribeToRealtime()      │
    └────────────┬───────────────────┘
                 │
        ┌────────┼────────┐
        │        │        │
        ▼        ▼        ▼
    _load    _load    _subscribe
    GpsData  Pokup    ToRealtime
        │        │        │
        └────────┼────────┘
                 │
        ┌────────▼──────────────────────────┐
        │ putnik_service.dart               │
        │ getPutniciByDayIso()              │
        │ streamKombinovaniPutniciFiltered()│
        └────────┬──────────────────────────┘
                 │
                 ▼
        ┌────────────────────────────────────────┐
        │ Supabase .select() / .stream()          │
        │                                        │
        │ - SELECT * FROM putnici WHERE...       │
        │ - Real-time subscription               │
        │ - Stream ažuriranja                    │
        └────────────────────────────────────────┘
```

**Pronalaženje:**
```
1. Ctrl+P > kombi_eta_widget.dart
2. Ctrl+F > _loadGpsData
3. F12 na getPutniciByDayIso
```

---

## 🔄 TOK 5: Streaming Putnika (Realtime)

```
┌──────────────────────────────────────────┐
│ PUTNIK SERVICE                           │
│ streamKombinovaniPutniciFiltered()        │
└────────────┬───────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │ 1. Generiši _streamKey()                  │
    │    - Ključ zavisno od grad/vreme         │
    │    - npr: "day_2026-01-28_09:00_NS"      │
    └────────┬───────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │ 2. Osiguraj Global Channel               │
    │    _ensureGlobalChannel()                │
    │    - Konekcija na Supabase realtime     │
    │    - Subscription na tabelu              │
    └────────┬───────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │ 3. Kreiraj StreamController              │
    │    - Prati sve promene                   │
    │    - Emituje nove vrednosti              │
    └────────┬───────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │ 4. Subscribe na Realtime Promene         │
    │    - Realtime INSERT/UPDATE/DELETE       │
    │    - Automatski osvežavanje              │
    └────────┬───────────────────────────────────┘
             │
    ┌────────▼──────────────────────────────────┐
    │ 5. Emituj Promene                        │
    │    - _streamController.add(putniciLista) │
    │    - Svi slušaoci dobijaju update        │
    └──────────────────────────────────────────┘
```

**Pronalaženje:**
```
1. Ctrl+P > putnik_service.dart
2. Ctrl+F > streamKombinovaniPutniciFiltered
3. F12 za definiciju
```

---

## 📍 TOK 6: Tedenski Reset

```
┌─────────────────────────────────────────────┐
│ WEEKLY RESET SERVICE                        │
│ weekly_reset_service.dart                   │
│ _executeWeeklyReset()                       │
└────────────┬─────────────────────────────────┘
             │
      ┌──────┴──────┬──────────┬────────┐
      │             │          │        │
      ▼             ▼          ▼        ▼
  _reset      _reset       _reset   _reset
Schedules   Payments    Permissions  Stats
      │             │          │        │
      ▼             ▼          ▼        ▼
  putnik_    registrovani_  vozac_    voznje_
  service    putnik_service service   log
      │             │          │        │
      └──────┬──────┴──────────┴────────┘
             │
             ▼
    ┌──────────────────────────────────────┐
    │ Supabase UPDATE                      │
    │ UPDATE registrovani_putnici SET ...  │
    │ WHERE datum = TODAY                  │
    └──────────────────────────────────────┘
```

**Pronalaženje:**
```
Ctrl+P > weekly_reset_service.dart
Ctrl+F > _executeWeeklyReset
```

---

## 🚗 TOK 7: GPS Tracking Vozača

```
┌──────────────────────────────────┐
│ DRIVER LOCATION SERVICE          │
│ _startStreamTracking()           │
└────────────┬─────────────────────┘
             │
      ┌──────▼──────┬────────┐
      │             │        │
      ▼             ▼        ▼
  Geolocator   Permission  Supabase
  request GPS  check       upload
      │             │        │
      └──────┬──────┴────────┘
             │
             ▼
    ┌──────────────────────────────────┐
    │ HERE WeGo Navigation Service     │
    │ updateNavigationState()          │
    │                                  │
    │ - Ažurira GPS poziciju          │
    │ - Osvežava ETA                   │
    └──────────┬──────────────────────┘
               │
               ▼
    ┌──────────────────────────────────┐
    │ realtime_notification_service    │
    │ notifyAllListeners()             │
    │                                  │
    │ - Pošalje update na sve klijente │
    │ - Realtime GPS pozicija          │
    └──────────────────────────────────┘
```

**Pronalaženje:**
```
Ctrl+P > driver_location_service.dart
Ctrl+F > _startStreamTracking
```

---

## 🤖 TOK 8: Autonomous Dispatch (ML)

```
┌────────────────────────────────────────────┐
│ ML DISPATCH AUTONOMOUS SERVICE             │
│ toggleAutopilot()                          │
└────────────┬───────────────────────────────┘
             │
             ▼
    ┌────────────────────────────────┐
    │ Start ML Autopilot Mode        │
    │                                │
    │ - Praćenje booking streama     │
    │ - Automatska dodeljiva         │
    │ - AI predviđanja               │
    └────────────┬───────────────────┘
                 │
        ┌────────┴────────┬──────────┐
        │                 │          │
        ▼                 ▼          ▼
  _subscribe      _start         _start
  ToBooking      Velocity      Integrity
  Stream         Monitoring     Check
        │                 │          │
        └────────┬────────┴──────────┘
                 │
                 ▼
    ┌────────────────────────────────────┐
    │ putnik_service.dart                │
    │ oznaciPokupljen() - automatski     │
    │                                    │
    │ - Nema manuelne akcije             │
    │ - Čisto ML algoritam               │
    └────────────────────────────────────┘
```

**Pronalaženje:**
```
Ctrl+P > ml_dispatch_autonomous_service.dart
Ctrl+F > toggleAutopilot
```

---

## 💡 KAKO ČITATI TOKOVE

```
┌─ Početak toka (widget ili korisnikova akcija)
│
▼ Strela = poziva se sledećа funkcija
│
┌─ Funkcija sa lokacijom
│  (datoteka.dart:line)
│
▼ Može biti više grana
│
├─ Grana 1
├─ Grana 2
├─ Grana 3
│
└─ Sve grane se mogu spajati
   na zajedničko mesto
```

---

## 🔗 CONNECTING FUNCTIONS

### Koja funkcija poziva koju?

**Pronalaženje:**
```
1. Stani na funkciji (npr: oznaciPokupljen)
2. Ctrl+Shift+H - vidiš sve koji je pozivaju
3. F12 - idi na definiciju
4. Ctrl+G - idi na liniju sa pozivom
```

---

## 📈 DIJAGRAM ZAVISNOSTI

```
WIDGETS (Prikazivanje)
├── putnik_card.dart
│   ├── putnik_service.dart (čita)
│   ├── registrovani_putnik_service.dart (čita)
│   └── voznje_log_service.dart (piše)
│
├── kombi_eta_widget.dart
│   ├── putnik_service.dart (stream)
│   ├── driver_location_service.dart (GPS)
│   └── here_wego_navigation_service.dart (navigacija)
│
└── registrovani_putnik_dialog.dart
    ├── registrovani_putnik_service.dart (CRUD)
    └── voznje_log_service.dart (logovanje)

SERVISI (Logika)
├── putnik_service.dart
│   ├── supabase (baza)
│   ├── voznje_log_service.dart (logovanje)
│   └── realtime_notification_service.dart (notifikacija)
│
├── registrovani_putnik_service.dart
│   ├── supabase (baza)
│   └── voznje_log_service.dart (logovanje)
│
├── voznje_log_service.dart
│   └── supabase (baza)
│
├── ml_dispatch_autonomous_service.dart
│   ├── putnik_service.dart (čita/piše)
│   └── realtime_notification_service.dart
│
├── driver_location_service.dart
│   ├── geolocator (GPS)
│   └── here_wego_navigation_service.dart
│
└── weekly_reset_service.dart
    ├── putnik_service.dart
    ├── registrovani_putnik_service.dart
    └── voznje_log_service.dart
```

---

## 🎯 QUICK LOOKUP

| Trebam da... | Funkcija | Fajl |
|--------------|----------|------|
| Dodam putnika | oznaciPokupljen() | putnik_service.dart |
| Otkažem putnika | otkaziPutnika() | putnik_service.dart |
| Snimim plaćanje | _sacuvajPlacanjeStatic() | putnik_card.dart |
| Dohvatim realtime putnika | streamKombinovaniPutniciFiltered() | putnik_service.dart |
| Učitam GPS | _loadGpsData() | kombi_eta_widget.dart |
| Pošaljem notifikaciju | sendNotificationToAllDrivers() | realtime_notification_service.dart |
| Resetujem tedenski | _executeWeeklyReset() | weekly_reset_service.dart |
| Automatski dodeljujem | toggleAutopilot() | ml_dispatch_autonomous_service.dart |

---

## 🚀 ZAKLJUČAK

**Koristi ove tokove za:**
1. Razumevanje kako funkcionira aplikacija
2. Pronalaženje gde je greška kada nešto ne radi
3. Pronalaženje funkcija koje trebam da promenim
4. Razumevanje zavisnosti između komponenti
5. Debugging aplikacije

**Pamti:**
- Ctrl+Shift+H = vidiš sve pozive
- F12 = idi na definiciju
- Alt+← = nazad
- Alt+→ = napred

**Sada znaš kako teče logika! 🎯**
