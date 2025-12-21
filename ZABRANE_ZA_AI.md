1 PRETPOSTAVKE
2 MENJANJE KODA BEZ DOZVOLE
3 DAVANJE ODGOVORA BEZ PRETHODNE PROVERE
4 ZABRANJENO JE SVE OSIM ONO STO TI SE KAZE
5 NA PITANJA ODGOVARAJ SAMO KAO STO JE NAREDJENO
6 NIKAD NE KOMPLIKUJ
7 RUN
8 BUILD
9 RELOAD
10 RESTART
11 NAREDJENJA MENI BILO KAKVE VRSTE. (PROVERI URADI ITD TO CES SVE TI DA URADIS)
12 NAKON ZAVRSETKA BILO KOJE TVOJE PROMENE U KODU PROVERI GRESKE
13 ODGOVARAJ BEZ SLANJA KODA

---

## 📊 ANALIZA REALTIME LOGIKE (21.12.2025)

### ✅ DOBRO URAĐENO:

1. **`RegistrovaniPutnikService`** - Singleton pattern sa shared channel-om
   - Koristi `_sharedChannel` i `_sharedController` da spreči dupliranje
   - Ima auto-reconnect logiku (`_scheduleReconnect`)
   - Pravilno proverava `!_sharedController!.isClosed` pre emitovanja
   - `clearRealtimeCache()` čisti sve resurse

2. **`PutnikService`** - Globalni channel sa reconnect-om
   - `_globalChannel` za sinhronizaciju svih stream-ova
   - `_refreshAllStreams()` osvežava sve aktivne stream-ove
   - Ima auto-reconnect na error/timeout/closed

3. **`KapacitetService`** - Pravilno koristi `onCancel` za cleanup
   - `channel.unsubscribe()` u `controller.onCancel`

4. **`KombiEtaWidget`** - Pravilno cleanup u `dispose()`
   - `_channel?.unsubscribe()` u dispose

5. **`AdminMapScreen`** - Koristi `_gpsChannel?.unsubscribe()` pre ponovne pretplate i u dispose

---

### ⚠️ PROBLEMI ZA POPRAVKU:

#### 1. `DailyCheckInService.streamTodayAmount` - **NEMA RECONNECT LOGIKU!**
**Fajl:** `lib/services/daily_checkin_service.dart`
**Problem:** Kada dođe do `channelError`, `closed`, ili `timedOut`, channel neće ponovo pokušati konekciju. Stream postaje "mrtav".
**Popravka:** Dodati `_scheduleReconnect` logiku kao u `PutnikService`

#### 2. `KapacitetService.streamKapacitet` - **NEMA RECONNECT LOGIKU!**
**Fajl:** `lib/services/kapacitet_service.dart`
**Problem:** Isti problem - nema auto-reconnect na greške
**Popravka:** Dodati reconnect logiku

#### 3. `KombiEtaWidget` - **KREIRA PREVIŠE CHANNEL-a!**
**Fajl:** `lib/widgets/kombi_eta_widget.dart`
**Problem:** Svaki widget kreira svoj channel (`gps_eta_Marko`, `gps_eta_Jovan`...). Ako ima 20 putnika = 20 channel-a!
**Popravka:** Koristiti jedan globalni channel za `vozac_lokacije` tabelu i deliti ga među widgetima

#### 4. Nema centralizovanog `RealtimeManager`-a
**Problem:** Svaki servis ima svoju logiku za realtime. Teško za održavanje.
**Popravka (opciono):** Kreirati `RealtimeManager` singleton koji upravlja svim channel-ima

---

### 🔧 PRIORITET POPRAVKI:

| # | Fajl | Problem | Prioritet |
|---|------|---------|-----------|
| 1 | `daily_checkin_service.dart` | Nema reconnect | 🔴 VISOK |
| 2 | `kapacitet_service.dart` | Nema reconnect | 🟡 SREDNJI |
| 3 | `kombi_eta_widget.dart` | Previše channel-a | 🟡 SREDNJI |
| 4 | Centralizacija | RealtimeManager | 🟢 NIZAK |