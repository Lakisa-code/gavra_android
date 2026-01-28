# 📑 KOMPLETAN INDEKS - SVEZNANJA

## 📚 DOSTUPNI VODIČI

| Vodič | Opis | Šta Sadrži |
|-------|------|-----------|
| **FUNCTION_GUIDE.md** | 🎓 Edukacija | Tipke, struktura, kategorije, vežbe |
| **FUNCTIONS_REFERENCE_TABLE.md** | 📊 Referenca | Sve funkcije po servisu sa povesima |
| **FLOW_DIAGRAMS.md** | 🗺️ Tokovi | 8 glavnih tokova u aplikaciji |
| **INTERACTIVE_RUNBOOK.md** | 🛠️ Praksa | 15 čestih taskova sa step-by-step |
| **INDEX.md** (OVO) | 📑 Početna | Kompletan pregled svega |

---

## 🚀 BRZI START (5 MINUTA)

### 1. Želite da pronađete funkciju?
**Ctrl+Shift+F** > upišite ime funkcije > Enter ✅

### 2. Želite da vidite gde se koristi?
**Ctrl+Shift+H** na funkciji > vidite sve reference ✅

### 3. Želite da vidite šta radi?
**F12** na funkciji > ide na definiciju ✅

### 4. Trebate kompletan vodič?
👉 **Čitajte FUNCTION_GUIDE.md** - ima sve tipke i trikove

---

## 🎯 TRAŽIM NEŠTO SPECIFIČNO

### "Trebam da pronađem funkciju za plaćanja"
```
1. Čitaj: FUNCTIONS_REFERENCE_TABLE.md - Sekcija 💰
2. Pronađi: azurirajPlacanjeZaMesec() ili _sacuvajPlacanjeStatic()
3. Koristi: Ctrl+P > datoteka > Ctrl+F > ime
```

### "Trebam da razumem tok dodavanja putnika"
```
1. Čitaj: FLOW_DIAGRAMS.md - Sekcija TOK 1
2. Vidiš sve korake od UI do baze
3. Koristi: F12 za svaki poziv
```

### "Trebam step-by-step uputstvo"
```
1. Čitaj: INTERACTIVE_RUNBOOK.md
2. Pronađi svoj task (15 opcija)
3. Sledi tačno kao što piše
```

### "Trebam sve funkcije u jednom mestu"
```
1. Čitaj: FUNCTIONS_REFERENCE_TABLE.md
2. Ima sve 650+ funkcija organizovane
3. Koristi Ctrl+F u dokumentu za pretragu
```

---

## 📊 STRUKTURA PROJEKTA

```
lib/
├── services/              # 61 servisa sa 350+ funkcija
│   ├── putnik_service.dart              ⭐ Glavno
│   ├── registrovani_putnik_service.dart  ⭐ Plaćanja
│   ├── vozac_service.dart
│   ├── voznje_log_service.dart
│   ├── ml_service.dart                  🤖 ML
│   ├── ml_dispatch_autonomous_service.dart 🤖
│   ├── ml_finance_autonomous_service.dart  🤖
│   ├── ml_vehicle_autonomous_service.dart  🤖
│   ├── driver_location_service.dart     📍 GPS
│   ├── here_wego_navigation_service.dart 🗺️
│   ├── realtime_notification_service.dart 📱
│   ├── weekly_reset_service.dart        🔄
│   ├── huawei_push_service.dart         📲
│   ├── auth_service.dart                🔐
│   ├── cache_service.dart               💾
│   └── ... (43 više)
│
├── widgets/               # 15+ widgeta sa 100+ funkcija
│   ├── putnik_card.dart              ⭐ Glavno (50+ funkcija)
│   ├── kombi_eta_widget.dart         📍 GPS (15+ funkcija)
│   ├── registrovani_putnik_dialog.dart
│   └── ... (12 više)
│
├── models/                # 6 modela sa 200+ funkcija
│   ├── putnik.dart
│   ├── registrovani_putnik.dart
│   ├── vozac.dart
│   ├── adresa.dart
│   ├── gps_lokacija.dart
│   └── fuel_log.dart
│
└── screens/               # Ekrani (50+ datoteka)
    ├── putnik_screen.dart
    ├── vozac_screen.dart
    └── ... (48 više)
```

---

## ⭐ TOP 10 NAJVAŽNIJIH FUNKCIJA

| # | Funkcija | Datoteka | Povesnost | Razlog |
|---|----------|----------|-----------|--------|
| 1 | `logGeneric()` | voznje_log_service | ⭐⭐⭐⭐ | 11 poziva |
| 2 | `streamKombinovaniPutniciFiltered()` | putnik_service | ⭐⭐⭐ | 8 poziva |
| 3 | `oznaciPokupljen()` | putnik_service | ⭐⭐⭐ | 5 poziva |
| 4 | `azurirajPlacanjeZaMesec()` | registrovani_putnik | ⭐⭐⭐ | 5 poziva |
| 5 | `sendNotificationToAllDrivers()` | realtime_notification | ⭐⭐⭐ | 5 poziva |
| 6 | `_executeWeeklyReset()` | weekly_reset | ⭐⭐ | 4 poziva |
| 7 | `otkaziPutnika()` | putnik_service | ⭐⭐ | 3 poziva |
| 8 | `_sacuvajPlacanjeStatic()` | putnik_card | ⭐⭐ | 2 poziva |
| 9 | `build()` | putnik_card | ⭐⭐⭐⭐ | UI |
| 10 | `_loadGpsData()` | kombi_eta_widget | ⭐⭐⭐ | GPS |

**Pronalaženje:** `FUNCTIONS_REFERENCE_TABLE.md` - ima sve!

---

## 🔗 GLAVNE ZAVISNOSTI

```
putnik_card.dart (UI)
  ├─> putnik_service.dart (Logika)
  ├─> registrovani_putnik_service.dart (Plaćanja)
  ├─> voznje_log_service.dart (Logovanje)
  ├─> realtime_notification_service.dart (Obavest)
  └─> supabase (Baza)

kombi_eta_widget.dart (UI)
  ├─> putnik_service.dart (Logika)
  ├─> driver_location_service.dart (GPS)
  ├─> here_wego_navigation_service.dart (Navigacija)
  └─> supabase (Baza)

putnik_service.dart (Logika)
  ├─> voznje_log_service.dart (Logovanje)
  ├─> realtime_notification_service.dart (Obavest)
  ├─> weekly_reset_service.dart (Reset)
  └─> supabase (Baza)
```

**Gde je šta:** `FLOW_DIAGRAMS.md` - ima sve tokove!

---

## 💻 TIPKE I PREČICE

### PRONALAŽENJE
| Tipka | Akcija |
|-------|--------|
| `Ctrl+F` | Pronađi u fajlu |
| `Ctrl+Shift+F` | Pronađi u svim fajlovima |
| `Ctrl+P` | Pronađi fajl |
| `Ctrl+G` | Idi na liniju |

### NAVIGACIJA
| Tipka | Akcija |
|-------|--------|
| `F12` | Go to Definition |
| `Ctrl+Shift+H` | Find All References |
| `Alt+←` | Nazad |
| `Alt+→` | Napred |
| `Ctrl+Shift+O` | Outline (funkcije u fajlu) |

### EDITING
| Tipka | Akcija |
|-------|--------|
| `F2` | Rename Symbol (svugde) |
| `Ctrl+.` | Quick Fix |
| `Ctrl+/` | Comment |
| `Ctrl+Space` | IntelliSense |

### DEBUGGING
| Tipka | Akcija |
|-------|--------|
| `F5` | Start Debug |
| `F9` | Toggle Breakpoint |
| `F10` | Step Over |
| `F11` | Step Into |
| `Shift+F11` | Step Out |

**Više:** `FUNCTION_GUIDE.md` - Sekcija "BRZE TIPKE"

---

## 📚 KATEGORIJE FUNKCIJA

### By Type
- **Stream funkcije** (realtime): 20+ funkcija
- **Async funkcije** (Future): 150+ funkcija
- **Widget funkcije** (UI): 100+ funkcija
- **Pomoćne funkcije**: 380+ funkcija

### By Importance
- **KRITIČNE** (❌ ne meniaj): 10 funkcija
- **VAŽNE** (⚠️ pazi): 30 funkcija
- **POMOĆNE** (✅ safe): 610 funkcija

### By Domain
- **Putnici**: 40+ funkcija
- **Vozači**: 25+ funkcija
- **Plaćanja**: 30+ funkcija
- **ML/Autonomy**: 50+ funkcija
- **Lokacija/Navigacija**: 25+ funkcija
- **Notifikacije**: 20+ funkcija
- **UI/Widgets**: 100+ funkcija

**Sve:** `FUNCTIONS_REFERENCE_TABLE.md`

---

## 🛠️ ČESTI TASKOVI

| # | Tasku | Fajl | Tipke |
|---|-------|------|-------|
| 1 | Pronađi funkciju | INTERACTIVE_RUNBOOK | Ctrl+Shift+F |
| 2 | Vidi sve reference | INTERACTIVE_RUNBOOK | Ctrl+Shift+H |
| 3 | Idi na definiciju | INTERACTIVE_RUNBOOK | F12 |
| 4 | Preimenujem | INTERACTIVE_RUNBOOK | F2 |
| 5 | Čitaj ceo tok | INTERACTIVE_RUNBOOK | F12 multiple |
| 6 | Pronađi async fn | INTERACTIVE_RUNBOOK | Ctrl+Shift+O |
| 7 | Debug funkciju | INTERACTIVE_RUNBOOK | F9, F5 |
| 8 | Dodaj funkciju | INTERACTIVE_RUNBOOK | Copy + Modify |
| 9 | Pronađi dokumentaciju | INTERACTIVE_RUNBOOK | Hover |
| 10 | Pronađi testove | INTERACTIVE_RUNBOOK | Ctrl+P test/ |
| 11 | Merenje brzine | INTERACTIVE_RUNBOOK | Breakpoint |
| 12 | Pronađi export-e | INTERACTIVE_RUNBOOK | Ctrl+F public |
| 13 | Dodaj error handling | INTERACTIVE_RUNBOOK | Try-catch |
| 14 | Pronađi sve return-e | INTERACTIVE_RUNBOOK | Ctrl+F return |
| 15 | Optimizuj query | INTERACTIVE_RUNBOOK | Profiling |

**Step-by-step:** `INTERACTIVE_RUNBOOK.md`

---

## 🎓 KAKO POČETI

### FAZA 1: Upoznavanje (15 minuta)
```
1. Čitaj: FUNCTION_GUIDE.md - dobij pregled
2. Vidite sve tipke i alate
3. Razumete strukturu
```

### FAZA 2: Referenca (20 minuta)
```
1. Čitaj: FUNCTIONS_REFERENCE_TABLE.md
2. Pronađi funkcije koje vas zanimaju
3. Kopiraj putanju do funkcije
```

### FAZA 3: Tokovi (20 minuta)
```
1. Čitaj: FLOW_DIAGRAMS.md
2. Razumi kako se sve povezuje
3. Prati tokove sa F12
```

### FAZA 4: Praksa (korisno)
```
1. Čitaj: INTERACTIVE_RUNBOOK.md
2. Sledi taškove koje trebate
3. Vežbaj pronalaženje
```

---

## 🚀 ČESTA PITANJA

### P: "Gde je funkcija X?"
**O:** 
```
1. Koristi: Ctrl+Shift+F > upišite ime
2. Ili: Čitaj FUNCTIONS_REFERENCE_TABLE.md
3. Ili: Čitaj FLOW_DIAGRAMS.md za kontekst
```

### P: "Kako se koristi funkcija X?"
**O:**
```
1. Ctrl+Shift+H na funkciji > vidi sve pozive
2. Ili: Čitaj FLOW_DIAGRAMS.md > vidi tokove
3. Ili: Pronađi test u test/ fajlu
```

### P: "Šta se dešava kada kliknem na X?"
**O:**
```
1. Čitaj FLOW_DIAGRAMS.md
2. Pronađi tvoj tasku (8 tokova dostupno)
3. Sledi diagram sa F12 na svakom pozovu
```

### P: "Mogu li da promenim funkciju X?"
**O:**
```
1. Pronađi sve reference: Ctrl+Shift+H
2. Ako ima 10+ referenci = KRITIČNA (ne meniaj)
3. Ako ima 3-5 = VAŽNA (pazi)
4. Ako ima 0-2 = SAFE (meniaj slobodno)
```

### P: "Kako da debugujem problem?"
**O:**
```
1. Čitaj INTERACTIVE_RUNBOOK.md - Tasku #7
2. Koristi breakpoint (F9)
3. Koristi Debug mode (F5)
4. Step through (F10/F11)
```

---

## 📊 STATISTIKA

### Codebase
- **Fajlova**: 200+ datoteka
- **Redova koda**: 50,000+ linija
- **Funkcija**: 650+ funkcija
- **Servisa**: 61 servis
- **Modela**: 6 modela
- **Widgeta**: 15+ widgeta

### Dokumentacija
- **Vodiča**: 5 vodiča
- **Tokova**: 8 glavnih tokova
- **Taskova**: 15 čestih taskova
- **Tabela**: 20+ referentnih tabela

---

## 🎯 SLEDEĆI KORACI

### Trebam da...

**Razumem kako radi aplikacija:**
→ Čitaj `FLOW_DIAGRAMS.md` (8 tokova)

**Pronađem nešto u kodu:**
→ Koristi `Ctrl+Shift+F` + `FUNCTIONS_REFERENCE_TABLE.md`

**Razumem jednu funkciju:**
→ Čitaj `INTERACTIVE_RUNBOOK.md` + koristi `F12`

**Dodam novu funkciju:**
→ Čitaj `INTERACTIVE_RUNBOOK.md` Tasku #11

**Debugujem problem:**
→ Čitaj `INTERACTIVE_RUNBOOK.md` Tasku #7

**Proverim sve reference:**
→ Koristi `Ctrl+Shift+H` + `INTERACTIVE_RUNBOOK.md` Tasku #2

---

## 📞 HELP & SUPPORT

### If You Get Stuck

```
1. Čitaj FUNCTION_GUIDE.md - odgovore
2. Koristi Ctrl+Shift+F za pretragu
3. Koristi F12 za preskakanje između funkcija
4. Koristi Ctrl+Shift+H za sve reference
```

### Most Common Searches

```
azuciPokupljen - dodavanje putnika
otkaziPutnika - otkazivanje putnika
azurirajPlacanjeZaMesec - plaćanja
logGeneric - logovanje
sendNotificationToAllDrivers - obavesti
_executeWeeklyReset - reset
streamKombinovaniPutniciFiltered - realtime
build() - UI
```

---

## ✨ ZAKLJUČAK

**Imate sada:**
✅ 5 detaljnih vodiča
✅ 650+ funkcija katalogizovano
✅ 8 tokova aplikacije
✅ 15 taskova sa step-by-step
✅ Quick reference tipke
✅ Sve što trebate!

**Sada možete:**
✅ Brzo pronći bilo šta
✅ Razumeti bilo šta
✅ Izmeniti bilo šta
✅ Debugovati bilo šta
✅ Dodati bilo šta

**Zapamtite:**
- `Ctrl+Shift+F` = pronađi funkciju
- `Ctrl+Shift+H` = sve reference
- `F12` = idi na definiciju
- Ovaj dokument je početna tačka!

🚀 **Happy Coding! 🎯**

---

## 📑 KOMPLETAN INDEKS VODIČA

| Vodič | Sadržaj | Početna |
|-------|---------|---------|
| 📑 **INDEX.md** (OVO) | Početna tačka, Quick Links, FAQ | **POČNI OVDE** |
| 🎓 **FUNCTION_GUIDE.md** | Tipke, struktura, vežbe | Faza 1 |
| 📊 **FUNCTIONS_REFERENCE_TABLE.md** | Sve funkcije, referenca | Faza 2 |
| 🗺️ **FLOW_DIAGRAMS.md** | 8 tokova, zavisnosti | Faza 3 |
| 🛠️ **INTERACTIVE_RUNBOOK.md** | 15 taskova, step-by-step | Faza 4 |

**Ukupno:** 100+ stranica dokumentacije, 650+ funkcija, 8 tokova, 15 taskova

**Status:** ✅ Kompletan i pripremljen za upotrebu!

