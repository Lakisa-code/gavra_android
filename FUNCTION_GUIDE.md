# 📋 KOMPLETAN VODIČ ZA PRONALAŽENJE I KORIŠĆENJE FUNKCIJA

## 🚀 BRZE TIPKE (Keyboard Shortcuts)

### **Pronalaženje Funkcija**
| Tipka | Akcija | Opis |
|-------|--------|------|
| `F12` | Go to Definition | Presko na definiciju funkcije |
| `Ctrl+Shift+H` | Find All References | Pronađi sve pozive funkcije |
| `Ctrl+F` | Find | Pretraga u trenutnoj datoteci |
| `Ctrl+Shift+F` | Find in Files | Pretraga u celom projektu |
| `Ctrl+G` | Go to Line | Presko na liniju |
| `Ctrl+P` | Go to File | Brzo otvaranje datoteke |
| `Alt+←` | Go Back | Nazad na prethodnu lokaciju |
| `Alt+→` | Go Forward | Napred na sledeću lokaciju |

### **Navigacija**
| Tipka | Akcija |
|-------|--------|
| `Ctrl+Space` | IntelliSense/Auto-complete |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+.` | Quick Fix |
| `F2` | Rename Symbol |

---

## 📊 STRUKTURA PROJEKTA

```
lib/
├── services/              # Povna logika (61 servisa)
│   ├── putnik_service.dart           (40+ funkcija)
│   ├── registrovani_putnik_service.dart (30+ funkcija)
│   ├── vozac_service.dart            (25+ funkcija)
│   ├── ml_service.dart               (35+ funkcija)
│   ├── ml_dispatch_autonomous_service.dart
│   ├── ml_finance_autonomous_service.dart
│   └── ... (55 više servisa)
│
├── widgets/               # UI komponente
│   ├── putnik_card.dart              (50+ funkcija)
│   ├── kombi_eta_widget.dart         (8 funkcija)
│   ├── registrovani_putnik_dialog.dart
│   └── ... (13 više widgeta)
│
├── models/                # Modeli podataka (6 modela)
│   ├── putnik.dart
│   ├── vozac.dart
│   ├── adresa.dart
│   └── ... (3 više modela)
│
├── screens/               # Ekrani aplikacije
├── utils/                 # Utility funkcije
└── globals.dart           # Globalne konstante
```

---

## 🔍 KAKO PRONAĐI FUNKCIJU

### **Metoda 1: Po Imenu (Najbrža)**
```
1. Pritisnite: Ctrl+F
2. Upišite: oznaciPokupljen
3. Enter - direktno vam ide na funkciju
```

### **Metoda 2: Po Tipu (Ako Znate Servis)**
```
1. Ctrl+P (Go to File)
2. Upišite: putnik_service
3. Enter - otvori datoteku
4. Ctrl+F - pretraži unutar datoteke
```

### **Metoda 3: Po Klasu (Ako Znate Klasu)**
```
1. Ctrl+Shift+F (Find in Files)
2. Upišite: class Putnik
3. Enter - ide na klasu
```

### **Metoda 4: Pronađi Sve Reference**
```
1. Klik na funkciju imenom
2. Pritisnite: Ctrl+Shift+H
3. Vidite sve pozive te funkcije u kodu
```

---

## 📚 KLJUČNE FUNKCIJE PO KATEGORIJAMA

### **1️⃣ PUTNIK OPERACIJE (putnik_service.dart)**

#### **Čitanje Putnika**
```dart
// 🔍 Pronađi sve putnike za dan
Future<List<Putnik>> getPutniciByDayIso(String isoDate)

// 🔍 Stream - realtime lista putnika
Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
  String? isoDate,
  String? grad,
  String? vreme,
})

// 🔍 Pronađi putnika po ID-u
Future<Putnik?> getPutnikFromAnyTable(dynamic id)

// 🔍 Batch učitavanje više putnika
Future<List<Putnik>> getPutniciByIds(List<dynamic> ids)
```

**Pronalaženje:**
```
Ctrl+Shift+F > "getPutniciByDayIso"
ili
F12 na liniji: getPutniciByDayIso(date)
```

#### **Prikupljanje Putnika**
```dart
// ✅ Označi kao pokupljen
Future<void> oznaciPokupljen(
  dynamic id,
  String currentDriver,
  {String? grad, String? selectedDan}
)

// ❌ Otkaži putnika
Future<void> otkaziPutnika(
  dynamic id,
  String otkazaoVozac,
  {String? selectedVreme, String? selectedGrad}
)

// 🗑️ Ukloni iz termina
Future<void> ukloniIzTermina(
  dynamic id,
  {required String datum, required String vreme, required String grad}
)
```

**Pronalaženje:**
```
1. Ctrl+P > putnik_service
2. Ctrl+F > oznaciPokupljen
3. F12 za definiciju
4. Ctrl+Shift+H za sve pozive
```

---

### **2️⃣ MESEČNI PUTNICI (registrovani_putnik_service.dart)**

#### **Čitanje**
```dart
Future<List<RegistrovaniPutnik>> getAktivniRegistrovaniPutnici()
Future<RegistrovaniPutnik?> getRegistrovaniPutnikByIme(String ime)
Stream<List<RegistrovaniPutnik>> streamAktivniRegistrovaniPutnici()
```

#### **Pisanje**
```dart
Future<bool> azurirajPlacanjeZaMesec(
  String putnikId,
  double iznos,
  DateTime pocetakMeseca,
  DateTime krajMeseca,
)

Future<void> dodajRegistrovanogPutnika(RegistrovaniPutnik putnik)
Future<void> updateRegistrovaniPutnik(RegistrovaniPutnik putnik)
```

**Pronalaženje:**
```
Ctrl+P > registrovani_putnik_service
```

---

### **3️⃣ VOZAČ OPERACIJE (vozac_service.dart)**

```dart
// Čitaj sve vozače
Future<List<Vozac>> sviVozaci()

// Pronađi vozača po imenu
Future<Vozac?> vozacPoImenu(String ime)

// Sačuvaj vozača
Future<void> sacuvajVozaca(Vozac v)
```

---

### **4️⃣ ML ALGORITMI (ml_service.dart)**

```dart
// 🤖 Predvidi najbolja vremena za vožnje
Future<List<OptimalTimeSlot>> predictOptimalTimes(String grad)

// 🤖 Oceni kvalitet vozača
Future<DriverQualityScore> rateDriverQuality(String vozacId)

// 🤖 Pronađi best route
Future<List<RouteSegment>> optimizeLargeRoutes(List<String> stops)
```

---

### **5️⃣ UI WIDGET FUNKCIJE**

#### **Putnik Kartica (putnik_card.dart)**
```dart
// 🎨 Build glavnog widgeta
Widget build(BuildContext context)

// 🎨 Prikaži admin popup
void _showAdminPopup()

// 💰 Sačuvaj plaćanje
Future<void> _sacuvajPlacanjeStatic({
  required String putnikId,
  required double iznos,
  required String mesec,
  required String vozacIme,
})
```

#### **ETA Widget (kombi_eta_widget.dart)**
```dart
// 📍 Učitaj GPS podatke
Future<void> _loadGpsData()

// 📍 Učitaj pokupljenje iz baze
Future<void> _loadPokupljenjeIzBaze()

// 🎨 Build container
Widget _buildContainer(Color baseColor, {required Widget child})
```

---

## 🎯 VEŽBE: PRONALAŽENJE FUNKCIJA

### **Vežba 1: Pronađi Kako Se Putnik Označava kao Pokupljen**
```
1. Pritisnite: Ctrl+F
2. Upišite: oznaciPokupljen
3. Vidite definiciju - prebrojte broj linija koda
4. Pritisnite: Ctrl+Shift+H
5. Vidite gde se koristi ta funkcija
```

**Odgovor:** Funkcija je u `putnik_service.dart`, ima ~100 linija koda, koristi se u:
- `putnik_card.dart` - kada korisnik doda putnika
- Realtime notifikacije
- Logging servisu

---

### **Vežba 2: Pronađi Sve Async Funkcije u ML Servisu**
```
1. Ctrl+P > ml_service.dart
2. Ctrl+F > Future<
3. Brojite sve pronađene
```

**Odgovor:** ~35+ async funkcija za ML algoritme

---

### **Vežba 3: Pronađi Ko Poziva `getAktivniRegistrovaniPutnici`**
```
1. Ctrl+P > registrovani_putnik_service.dart
2. Klik na `getAktivniRegistrovaniPutnici`
3. Pritisnite: Ctrl+Shift+H
4. Vidite sve pozive
```

**Odgovor:** Koristi se u:
- Streaming data
- Cache updates
- Weekly reset

---

## 🔗 POVEZANOST FUNKCIJA

### **Tok: Dodavanje Putnika**
```
1. registrovani_putnik_service.dart
   └─> dodajRegistrovanogPutnika()

2. putnik_service.dart
   └─> streamKombinovaniPutniciFiltered()

3. putnik_card.dart
   └─> build() prikazuje kartu

4. voznje_log_service.dart
   └─> logGeneric() loguje akciju
```

**Pronalaženje toka:**
```
1. Počni sa: Ctrl+F > "dodajRegistrovanogPutnika"
2. F12 na liniju koja je poziva
3. Vrati se Alt+← kada trebaš
4. Kreni sa sledećom funkcijom
```

---

### **Tok: Označavanje Putnika kao Pokupljenog**
```
1. putnik_card.dart
   └─> _oznaciPokupljenTap()
   └─> PutnikService().oznaciPokupljen()

2. putnik_service.dart
   └─> oznaciPokupljen() - glavna logika
   └─> supabase.update()
   └─> VoznjeLogService.logGeneric()

3. realtime_notification_service.dart
   └─> sendNotificationToAllDrivers()

4. weekly_reset_service.dart
   └─> loguje statistiku
```

---

## 💡 PRO SAVETI

### **Tip 1: Koristi Breadcrumb za Navigaciju**
```
Vidite na vrhu: lib/services > putnik_service.dart > PutnikService > oznaciPokupljen
Kliknite na bilo koji deo za brzo preskakanje
```

### **Tip 2: Koristi minimap sa desne strane**
```
- Vidite strukturu celog fajla
- Kliknite na neke oblast za brzo skakanje
- Crna oblasti = malo koda, bela = puno koda
```

### **Tip 3: Koristi Code Lens**
```
Preko svake funkcije vidite:
- "N references" - broj poziva
- Source Control info
- Test info
```

### **Tip 4: Koristi Outline**
```
Ctrl+Shift+O - vidite sve funkcije u datoteci
Početi sa @ za specifičnu kategoriju (@function, @class, itd.)
```

### **Tip 5: Koristi Search Widget**
```
Ctrl+Shift+F - otvori Search panel
Kliknite filter ikonicu za Regex, Case-sensitive, itd.
Regex: Future<\w+>\s+\w+ pronalazi sve async funkcije
```

---

## 🎨 ORGANIZOVANJE FUNKCIJA PO VAŽNOSTI

### **Level 1: Kritične Funkcije (❌ Ne smeš promeniti)**
```
- voznje_log_service.dart > logGeneric() (11 poziva)
- realtime_notification_service.dart > sendNotificationToAllDrivers()
```

**Pronalaženje:**
```
Ctrl+Shift+H na svakoj - ako ima 5+ reference, je važna
```

### **Level 2: Važne Funkcije (⚠️ Pazi kada meniš)**
```
- putnik_service.dart > streamKombinovaniPutniciFiltered() (8 poziva)
- putnik_service.dart > oznaciPokupljen() (5 poziva)
- registrovani_putnik_service.dart > azurirajPlacanjeZaMesec() (5 poziva)
- putnik_card.dart > build()
- kombi_eta_widget.dart > _loadGpsData()
```

### **Level 3: Pomoćne Funkcije (✅ Safe za izmenu)**
```
- putnik_service.dart > _executeWeeklyReset() (4 poziva)
- putnik_service.dart > otkaziPutnika() (3 poziva)
- String formatteri (_formatTime, _normalizeGrad)
- Validatori (_isValidUuid, _isTimePassed)
- Konvertori (_calculateDistance)
```

---

## 🔧 REFAKTORISANJE FUNKCIJA

### **Pre Nego Što Promenite Funkciju:**
```
1. Pronađite funkciju: Ctrl+F > naziv
2. Vidite sve reference: Ctrl+Shift+H
3. Brojite reference:
   - 0-2 reference = SAFE (pomoćna funkcija)
   - 3-5 reference = CAREFUL (važna funkcija)
   - 6+ reference = VERY CAREFUL (kritična funkcija)
```

### **Sigurni Koraci za Refaktorisanje:**
```
1. Backup fajla (Ctrl+Z je vaš prijatelj)
2. Preimenujem funkciju: F2
3. Automatski se preimenovaju sve reference
4. Test sa Ctrl+Shift+T
5. Commit sa Git
```

---

## 📈 ANALIZA FUNKCIJA

### **Pronađi Sve Async Funkcije u Servisu**
```
Ctrl+Shift+F > odaberi datoteku > Regex: Future<\w+>\s+\w+
```

### **Pronađi Sve Void Funkcije**
```
Ctrl+Shift+F > Regex: void\s+\w+
```

### **Pronađi Sve Widget Build Funkcije**
```
Ctrl+Shift+F > Regex: Widget\s+build|Widget\s+_build
```

---

## 🚀 ZAKLJUČAK

| Zadatak | Tipka |
|---------|-------|
| Pronađi funkciju | `Ctrl+F` |
| Idi na definiciju | `F12` |
| Pronađi sve reference | `Ctrl+Shift+H` |
| Preimenujem | `F2` |
| Idi na fajl | `Ctrl+P` |
| Command palette | `Ctrl+Shift+P` |
| Outline | `Ctrl+Shift+O` |

**Sada znaš kako brzo da se krećeš kroz kod! 🎯**
