# ⚡ QUICK LINKS - INSTANT PRISTUP

## 🎯 SKOČI NA...

### 📚 VODIČI
- 📑 **[INDEX.md](INDEX.md)** - Početna tačka, kompletan pregled
- 🎓 **[FUNCTION_GUIDE.md](FUNCTION_GUIDE.md)** - Tipke, struktura, edukacija
- 📊 **[FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md)** - Sve funkcije katalogizirane
- 🗺️ **[FLOW_DIAGRAMS.md](FLOW_DIAGRAMS.md)** - 8 glavnih tokova aplikacije
- 🛠️ **[INTERACTIVE_RUNBOOK.md](INTERACTIVE_RUNBOOK.md)** - 15 čestih taskova sa step-by-step
- 📊 **[VISUAL_CHEAT_SHEET.md](VISUAL_CHEAT_SHEET.md)** - Vizuelni pregled, brzi tips
- ⚡ **[QUICK_LINKS.md](QUICK_LINKS.md)** - Ovaj fajl!

---

## 🎯 PRONALAŽENJE - TIPKE

| Trebam da... | Tipka | Fajl |
|--------------|-------|------|
| Pronađem bilo šta | `Ctrl+Shift+F` | Svi vodiči |
| Pronađem fajl | `Ctrl+P` | FUNCTION_GUIDE.md |
| Pročitam dokumentaciju | `Ctrl+H` hovering | FUNCTION_GUIDE.md |
| Vidim sve reference | `Ctrl+Shift+H` | INTERACTIVE_RUNBOOK.md |
| Gde se koristi | `Ctrl+Shift+H` | FLOW_DIAGRAMS.md |

---

## 🔥 TOP 10 FUNKCIJA

### Najvažnije
1. **[logGeneric()](FUNCTIONS_REFERENCE_TABLE.md#voznje-log-service)** - centralno logovanje (11 poziva)
2. **[streamKombinovaniPutniciFiltered()](FUNCTIONS_REFERENCE_TABLE.md#putnik-service)** - realtime (8 poziva)
3. **[oznaciPokupljen()](FUNCTIONS_REFERENCE_TABLE.md#putnik-service)** - dodavanje putnika (5 poziva)
4. **[azurirajPlacanjeZaMesec()](FUNCTIONS_REFERENCE_TABLE.md#registrovani-putnik-service)** - plaćanja (5 poziva)
5. **[sendNotificationToAllDrivers()](FUNCTIONS_REFERENCE_TABLE.md#realtime-notification-service)** - obavesti (5 poziva)
6. **[_executeWeeklyReset()](FUNCTIONS_REFERENCE_TABLE.md#scheduling)** - sedmični reset (4 poziva)
7. **[otkaziPutnika()](FUNCTIONS_REFERENCE_TABLE.md#putnik-service)** - otkazivanje (3 poziva)
8. **[_sacuvajPlacanjeStatic()](FUNCTIONS_REFERENCE_TABLE.md#putnik-card-widget)** - logovanje plaćanja (2 poziva)
9. **[build()](FUNCTIONS_REFERENCE_TABLE.md#putnik-card-widget)** - UI
10. **[_loadGpsData()](FUNCTIONS_REFERENCE_TABLE.md#kombi-eta-widget)** - GPS

---

## 🗺️ TOKOVI - DIREKTAN PRISTUP

1. **[TOK 1: Dodavanje Putnika](FLOW_DIAGRAMS.md#-tok-1-dodavanje-novog-putnika)**
   - UI → putnik_service → supabase → notifikacija
   - Tipke: `Ctrl+Shift+F > oznaciPokupljen`

2. **[TOK 2: Otkazivanje Putnika](FLOW_DIAGRAMS.md#-tok-2-otkazivanje-putnika)**
   - UI → putnik_service → vozila → logovanje
   - Tipke: `Ctrl+Shift+F > otkaziPutnika`

3. **[TOK 3: Plaćanje Putnika](FLOW_DIAGRAMS.md#-tok-3-plaćanje-putnika)**
   - Dialog → validation → voznje_log → finansije
   - Tipke: `Ctrl+Shift+F > _sacuvajPlacanjeStatic`

4. **[TOK 4: Učitavanje Putnika (ETA Widget)](FLOW_DIAGRAMS.md#-tok-4-učitavanje-putnika-u-eta-widget)**
   - Widget init → stream → supabase → realtime
   - Tipke: `Ctrl+Shift+F > _loadGpsData`

5. **[TOK 5: Streaming Putnika (Realtime)](FLOW_DIAGRAMS.md#-tok-5-streaming-putnika-realtime)**
   - putnik_service → stream controller → emitovanje
   - Tipke: `Ctrl+Shift+F > streamKombinovaniPutniciFiltered`

6. **[TOK 6: Tedenski Reset](FLOW_DIAGRAMS.md#-tok-6-tedenski-reset)**
   - weekly_reset → sve tabele → resetovanje
   - Tipke: `Ctrl+Shift+F > _executeWeeklyReset`

7. **[TOK 7: GPS Tracking](FLOW_DIAGRAMS.md#-tok-7-gps-tracking-vozača)**
   - Geolocator → HERE WeGo → Supabase → Notifikacija
   - Tipke: `Ctrl+Shift+F > _startStreamTracking`

8. **[TOK 8: Autonomous Dispatch (ML)](FLOW_DIAGRAMS.md#-tok-8-autonomous-dispatch-ml)**
   - ML autopilot → monitoring → automatska dodeljiva
   - Tipke: `Ctrl+Shift+F > toggleAutopilot`

---

## 📋 TASKOVI - 15 ČESTIH

1. **[Pronalaženje funkcije po imenu](INTERACTIVE_RUNBOOK.md#1️⃣-pronalaženje-funkcije-po-imenu)**
   - `Ctrl+Shift+F > ime > Enter`

2. **[Pronalaženje svih poziva](INTERACTIVE_RUNBOOK.md#2️⃣-pronalaženje-svih-poziva-funkcije)**
   - `Ctrl+Shift+H` na funkciji

3. **[Go to Definition](INTERACTIVE_RUNBOOK.md#3️⃣-ide-na-definiciju-funkcije)**
   - `F12` na funkciji

4. **[Preimenuovanje](INTERACTIVE_RUNBOOK.md#4️⃣-preimenuovanje-funkcije)**
   - `F2` > novo ime > Enter

5. **[Čitanje cijelog toka](INTERACTIVE_RUNBOOK.md#5️⃣-čitanje-cijelog-toka-funkcije)**
   - `F12` multiple puta, `Alt+←` za nazad

6. **[Pronalaženje async funkcija](INTERACTIVE_RUNBOOK.md#6️⃣-pronalaženje-svih-async-funkcija-u-servisu)**
   - `Ctrl+Shift+O` > "Future"

7. **[Pronalaženje grešaka](INTERACTIVE_RUNBOOK.md#7️⃣-pronalaženje-grešaka-u-funkciji)**
   - `F9` breakpoint, `F5` debug

8. **[Pronalaženje po ključnoj reči](INTERACTIVE_RUNBOOK.md#8️⃣-pronalaženje-funkcije-po-ključnoj-reči)**
   - `Ctrl+Shift+F` > ključna reč

9. **[Analiza zavisnosti](INTERACTIVE_RUNBOOK.md#9️⃣-analiza-zavisnosti-funkcije)**
   - `Ctrl+Shift+H` > analiza

10. **[Pronalaženje return-a](INTERACTIVE_RUNBOOK.md#1️⃣0️⃣-pronalaženje-svih-kraja-koda-function-returns)**
    - `Ctrl+F` > "return"

11. **[Dodavanje nove funkcije](INTERACTIVE_RUNBOOK.md#1️⃣1️⃣-dodavanje-nove-funkcije)**
    - Copy sličnu, modify, add calls

12. **[Pronalaženje dokumentacije](INTERACTIVE_RUNBOOK.md#1️⃣2️⃣-pronalaženje-dokumentacije-za-funkciju)**
    - Hover ili Ctrl+K Ctrl+I

13. **[Pronalaženje testova](INTERACTIVE_RUNBOOK.md#1️⃣3️⃣-pronalaženje-testova-za-funkciju)**
    - `Ctrl+P` > test/

14. **[Pronalaženje export-a](INTERACTIVE_RUNBOOK.md#1️⃣4️⃣-pronalaženje-koji-se-export-ujuјu-funkcije)**
    - `Ctrl+F` > "public" ili "static"

15. **[Merenje brzine](INTERACTIVE_RUNBOOK.md#1️⃣5️⃣-merenje-vremenske-kompleksnosti)**
    - Breakpoint + debug timer

---

## 📍 SERVISI - DIREKTAN PRISTUP

### PUTNIK SERVISI
- **putnik_service.dart** - [Sve funkcije](FUNCTIONS_REFERENCE_TABLE.md#-putnik-service-40-funkcija)
  - `oznaciPokupljen()` - [direktno](FUNCTIONS_REFERENCE_TABLE.md#pis-anje-podataka)
  - `otkaziPutnika()` - [direktno](FUNCTIONS_REFERENCE_TABLE.md#pis-anje-podataka)
  - `streamKombinovaniPutniciFiltered()` - [direktno](FUNCTIONS_REFERENCE_TABLE.md#čitanje-podataka)

- **registrovani_putnik_service.dart** - [Sve funkcije](FUNCTIONS_REFERENCE_TABLE.md#-registrovani-putnik-service-30-funkcija)
  - `azurirajPlacanjeZaMesec()` - [direktno](FUNCTIONS_REFERENCE_TABLE.md#pis-anje)

### VOZAČ SERVISI
- **vozac_service.dart** - [Sve funkcije](FUNCTIONS_REFERENCE_TABLE.md#-vozač-service-25-funkcija)

### ML SERVISI
- **ml_service.dart** - [Sve funkcije](FUNCTIONS_REFERENCE_TABLE.md#-ml-service-35-funkcija)
- **ml_dispatch_autonomous_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#ml_dispatch_autonomous_servicedart)
- **ml_finance_autonomous_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#ml_finance_autonomous_servicedart)
- **ml_vehicle_autonomous_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#ml_vehicle_autonomous_servicedart)

### SPECIJALNI SERVISI
- **voznje_log_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-voznje-log-service-20-funkcija)
- **driver_location_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-lokacija--navigacija)
- **here_wego_navigation_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-lokacija--navigacija)
- **realtime_notification_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-notifikacije)
- **huawei_push_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-notifikacije)
- **weekly_reset_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-resetovanje--scheduling)
- **auth_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-autentifikacija--sigurnost)
- **cache_service.dart** - [Sve](FUNCTIONS_REFERENCE_TABLE.md#-cache-upravljanje)

---

## 🎨 WIDGETI - DIREKTAN PRISTUP

- **putnik_card.dart** - [50+ funkcija](FUNCTIONS_REFERENCE_TABLE.md#-putnik-card-widget-50-funkcija)
- **kombi_eta_widget.dart** - [8 funkcija](FUNCTIONS_REFERENCE_TABLE.md#-kombi-eta-widget)
- Ostali widgeti - [reference](FUNCTIONS_REFERENCE_TABLE.md#-kompletan-indeks---sveznanja)

---

## 🗄️ BAZA PODATAKA

### Supabase Tabele (30 total)
| Tabela | Indeksi | Link |
|--------|---------|------|
| registrovani_putnici | 11 | [Info](FLOW_DIAGRAMS.md#-registrovani_putnici-11-indexes) |
| voznje_log | 5 | [Info](FLOW_DIAGRAMS.md#-voznje_log-5-indexes) |
| seat_requests | 8 | [Info](FLOW_DIAGRAMS.md#-seat_requests-8-indexes) |
| ... i 27 više | ... | Reference: FUNCTIONS_REFERENCE_TABLE.md |

---

## ⚙️ RAZVOJ & DEBUGGING

### Debugging
- **F5** - Start Debug
- **F9** - Toggle Breakpoint
- **F10** - Step Over
- **F11** - Step Into
- **Shift+F11** - Step Out

### Terminal
- `Ctrl+`` (backtick) - Otvori terminal
- `flutter run` - Run app
- `flutter analyze` - Analiza
- `pub get` - Dependencies

---

## 🎓 UČENJE - REDOSLED

### Početak (Ako ste novi)
1. Čitaj: **INDEX.md** (5 min)
2. Čitaj: **FUNCTION_GUIDE.md** (15 min)
3. Čitaj: **VISUAL_CHEAT_SHEET.md** (10 min)
4. Vežbi: **INTERACTIVE_RUNBOOK.md** (20 min)
5. Eksploriši: **FUNCTIONS_REFERENCE_TABLE.md** (30 min)
6. Razumej: **FLOW_DIAGRAMS.md** (30 min)

### Redovni Rad
- Koristite: **QUICK_LINKS.md** (ovaj fajl) za instant pristup
- Ponavljate: Tipke - `Ctrl+Shift+F`, `Ctrl+Shift+H`, `F12`, `F2`
- Referencirate: **INTERACTIVE_RUNBOOK.md** za taskove
- Čitate: **FLOW_DIAGRAMS.md** za kontext

---

## 🎯 ČESTI PROBLEM & REŠENJA

| Problem | Rešenje |
|---------|---------|
| Ne mogu da pronađem funkciju | Čitaj: [Tasku 1](INTERACTIVE_RUNBOOK.md#1️⃣-pronalaženje-funkcije-po-imenu) |
| Ne vidim sve reference | Čitaj: [Tasku 2](INTERACTIVE_RUNBOOK.md#2️⃣-pronalaženje-svih-poziva-funkcije) |
| Ne razumem šta radi | Čitaj: [Tasku 5](INTERACTIVE_RUNBOOK.md#5️⃣-čitanje-cijelog-toka-funkcije) |
| Trebam da debugujem | Čitaj: [Tasku 7](INTERACTIVE_RUNBOOK.md#7️⃣-pronalaženje-grešaka-u-funkciji) |
| Trebam da promenim | Čitaj: [Tasku 4](INTERACTIVE_RUNBOOK.md#4️⃣-preimenuovanje-funkcije) |
| Ne vidim sve async fn | Čitaj: [Tasku 6](INTERACTIVE_RUNBOOK.md#6️⃣-pronalaženje-svih-async-funkcija-u-servisu) |

---

## 📱 KATEGORIJE - BRZI PRISTUP

### Po Tipu Funkcije
- **Async** - `Ctrl+Shift+F > Future<` → [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md)
- **Stream** - `Ctrl+Shift+F > Stream<` → [FLOW_DIAGRAMS.md](FLOW_DIAGRAMS.md#-tok-5-streaming-putnika-realtime)
- **Widget** - `Ctrl+Shift+F > Widget build` → [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#-putnik-card-widget-50-funkcija)

### Po Važnosti
- **Kritične** (10 fnc) - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#po-važnosti)
- **Važne** (30 fnc) - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#po-važnosti)
- **Pomoćne** (610 fnc) - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#po-važnosti)

### Po Domeni
- **Putnici** - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#by-domain)
- **Plaćanja** - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#by-domain)
- **ML/Autonomija** - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#by-domain)
- **GPS/Lokacija** - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#by-domain)
- **UI/Widgets** - [FUNCTIONS_REFERENCE_TABLE.md](FUNCTIONS_REFERENCE_TABLE.md#by-domain)

---

## 💡 BRZI TIPS

- 💡 **Memorija:** `Ctrl+Shift+F` je osnovna tipka za sve
- 💡 **Bezbijednost:** Uvek koristi `Ctrl+Shift+H` pre nego promeniš
- 💡 **Speed:** `Ctrl+Shift+F` je brža od `Ctrl+P` + `Ctrl+F`
- 💡 **Refactor:** `F2` je sigurnija od ručnih izmena
- 💡 **Navigation:** `Alt+←` i `Alt+→` za brzo skakanje

---

## 📞 POMOĆ & PODRŠKU

**Ako zapetljaš:**
1. Pogledaj relevantni **TASKU** iz [INTERACTIVE_RUNBOOK.md](INTERACTIVE_RUNBOOK.md)
2. Koristi **Ctrl+Shift+F** za pretragu
3. Koristi **F12** da ideš u definiciju
4. Čitaj relevantni **TOK** iz [FLOW_DIAGRAMS.md](FLOW_DIAGRAMS.md)

**Ako ne razumęš:**
1. Čitaj [FUNCTION_GUIDE.md](FUNCTION_GUIDE.md)
2. Čitaj [VISUAL_CHEAT_SHEET.md](VISUAL_CHEAT_SHEET.md)
3. Radi [INTERACTIVE_RUNBOOK.md](INTERACTIVE_RUNBOOK.md)

**Ako trebas sve info:**
1. Idi na [INDEX.md](INDEX.md)
2. Koristi linkove da skipiš

---

## 📊 STATISTIKA

```
650+ Funkcija        🎯
200+ Datoteka        📁
50,000+ Linija       📝
8 Tokova             🗺️
15 Taskova           ✅
5 Vodiča             📚
100+ Stranica Docs   📖
```

---

## ✨ ZAKLJUČAK

```
Imate pristup svemu!

📑 Vodiči       → INDEX.md
📊 Funkcije     → FUNCTIONS_REFERENCE_TABLE.md
🗺️ Tokovi       → FLOW_DIAGRAMS.md
🛠️ Taskovi      → INTERACTIVE_RUNBOOK.md
⚡ Brzi Tips    → VISUAL_CHEAT_SHEET.md
🎯 Quick Links  → QUICK_LINKS.md (OVO)

Koristite QUICK_LINKS.md za instant pristup
svemu što vam trebaj!

🚀 Srećno u radu! 🎯
```

---

## 📚 MAPA LINKOVA

```
POČETAK
  ├─> INDEX.md
  │   ├─> FUNCTION_GUIDE.md
  │   ├─> FUNCTIONS_REFERENCE_TABLE.md
  │   ├─> FLOW_DIAGRAMS.md
  │   ├─> INTERACTIVE_RUNBOOK.md
  │   ├─> VISUAL_CHEAT_SHEET.md
  │   └─> QUICK_LINKS.md (OVO)
  │
  └─> BRZI START
      ├─> Ctrl+Shift+F (pronalaženje)
      ├─> Ctrl+Shift+H (reference)
      ├─> F12 (definicija)
      └─> F2 (preimenuovanje)
```

---

**Sada ste gotov! Hajde da radite! 💪**
