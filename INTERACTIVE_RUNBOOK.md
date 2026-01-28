# 🛠️ INTERAKTIVNA KOMANDA RUNBOOK

## 🎯 ČESTI TASKOVI - KAKO IH REŠITI

---

## 1️⃣ PRONALAŽENJE FUNKCIJE PO IMENU

### **Scenarij: "Gde je funkcija `oznaciPokupljen`?"**

```
Korak 1: Pritisnite Ctrl+Shift+F
Korak 2: Upišite: oznaciPokupljen
Korak 3: Enter
Korak 4: Vidite sve pozicije gde se pojavljuje
```

**Alternativa (brža - ako znate datoteku):**
```
Korak 1: Ctrl+P (Go to File)
Korak 2: Upišite: putnik_service
Korak 3: Enter (otvori datoteku)
Korak 4: Ctrl+F (Find in File)
Korak 5: Upišite: oznaciPokupljen
Korak 6: Enter
```

**Result:** Direktno vas vodi na liniju definicije ✅

---

## 2️⃣ PRONALAŽENJE SVIH POZIVA FUNKCIJE

### **Scenarij: "Gde se koristi `oznaciPokupljen`?"**

```
Korak 1: Ctrl+P > putnik_service
Korak 2: Ctrl+F > oznaciPokupljen
Korak 3: Kada vidite funkciju, kliknite na nju
Korak 4: Pritisnite Ctrl+Shift+H (Find All References)
Korak 5: Vidite sve pozive u crvenom panelu
```

**Rezultat:**
```
oznaciPokupljen - 12 references
├── putnik_card.dart:245
├── putnik_card.dart:387
├── weekly_reset_service.dart:89
├── ml_dispatch_autonomous_service.dart:156
└── ... (8 više)
```

**Pronalaženje:** Kliknite na svaki rezultat da vidite kontekst ✅

---

## 3️⃣ IDE NA DEFINICIJU FUNKCIJE

### **Scenarij: "Trebam da vidim šta radi funkcija X"**

```
Korak 1: Pozicionirajte kursor na poziv funkcije
        npr: PutnikService.oznaciPokupljen(...)
        
Korak 2: Pritisnite F12 (Go to Definition)
        ili: Ctrl+Click na funkciji

Korak 3: Otvarase datoteka sa definicijom
        sa kursorom postavljenim na `function` liniju

Korak 4: Čitajte dokumentaciju i kod
```

**Primer:**
```dart
// U putnik_card.dart - poziv:
await PutnikService.instance.oznaciPokupljen(id);

// Pritisnete F12 - ide u putnik_service.dart:
Future<void> oznaciPokupljen(dynamic id, String currentDriver, ...) {
  // DEFINICIJA - telo funkcije
}
```

---

## 4️⃣ PREIMENUOVANJE FUNKCIJE

### **Scenarij: "Trebam da promenim ime funkcije sa `oznaciPokupljen` na `markAsPickedUp`"**

```
Korak 1: Pronađite funkciju: Ctrl+P > putnik_service
Korak 2: Ctrl+F > oznaciPokupljen
Korak 3: Kliknite na ime funkcije
Korak 4: Pritisnite F2 (Rename Symbol)
Korak 5: Upišite novo ime: markAsPickedUp
Korak 6: Pritisnite Enter
Korak 7: VS Code AUTOMATSKI preimenovava SVUGDE
```

**Što se automatski preimenovava:**
```
1. putnik_service.dart - definicija funkcije
2. putnik_card.dart - pozivi (linija 245, 387, itd.)
3. weekly_reset_service.dart - pozivi
4. ml_dispatch_autonomous_service.dart - pozivi
5. Sve ostale datoteke koja je koriste
```

**⚠️ VAŽNO:** Refactoring se dešava na svim 12+ lokacija automatski! ✅

---

## 5️⃣ ČITANJE CIJELOG TOKA FUNKCIJE

### **Scenarij: "Trebam da razumem šta se dešava kada korisnik klikne `Označi kao pokupljen`"**

```
KORAK 1: Otvorite putnik_card.dart
         Ctrl+P > putnik_card

KORAK 2: Pronađite _oznaciPokupljenTap()
         Ctrl+F > _oznaciPokupljenTap

KORAK 3: Pročitajte šta se dešava:
         ```dart
         Future<void> _oznaciPokupljenTap() async {
           await PutnikService.instance.oznaciPokupljen(
             putnik.id,
             currentDriver
           );
         }
         ```

KORAK 4: Pritisnite F12 na oznaciPokupljen()
         Ide u putnik_service.dart

KORAK 5: Čitajte telo funkcije:
         ```dart
         Future<void> oznaciPokupljen(...) async {
           1. Proverite da li postoji putnik
           2. Ažurirajte supabase
           3. Logujte u voznje_log
           4. Pošalite notifikaciju
           5. Osvežite stream
         }
         ```

KORAK 6: Pratite svaki poziv (F12):
         - supabase.update() -> Supabase
         - VoznjeLogService.logGeneric() -> drugom fajlu
         - sendNotificationToAllDrivers() -> drugom fajlu

KORAK 7: Koristite Alt+← za nazad između dokumenata
```

**Rezultat:** Jasno razumete čitav tok od klik do baze podataka ✅

---

## 6️⃣ PRONALAŽENJE SVIH ASYNC FUNKCIJA U SERVISU

### **Scenarij: "Trebam da vidim sve async funkcije u `putnik_service.dart`"**

```
METODA 1 (Brža u VS Code):
- Ctrl+P > putnik_service.dart
- Ctrl+Shift+O (Outline)
- Type: "Future"
- Vidite sve Future funkcije

METODA 2 (Regex pretraga):
- Ctrl+Shift+F
- Otvori Regex: kliknite na .* dugme
- Upišite: Future<\w+>\s+\w+\s*\(
- Vidite sve async funkcije sa potpisiima
```

**Rezultat:**
```
Future<List<Putnik>> getPutniciByDayIso()
Future<void> oznaciPokupljen()
Future<void> otkaziPutnika()
Future<Putnik?> getPutnikById()
... (37 više)
```

---

## 7️⃣ PRONALAŽENJE GREŠAKA U FUNKCIJI

### **Scenarij: "Funkcija `oznaciPokupljen` baca grešku - gde je problem?"**

```
KORAK 1: Pronađite funkciju
         Ctrl+P > putnik_service
         Ctrl+F > oznaciPokupljen

KORAK 2: Čitajte redove koda u funkciji
         - Vidite try-catch blok?
         - Vidite null checks?
         - Vidite error propagation?

KORAK 3: Proverite sve koje se dešava
         Ctrl+Shift+H > vidite sve pozive
         
KORAK 4: Proverite gde se greška dešava
         - U pozivačkoj funkciji? (putnik_card.dart)
         - U samoj funkciji? (putnik_service.dart)
         - U async operacijama? (supabase, logging)

KORAK 5: Koristite Debug Print
         - Dodajte print() statements
         - Pokrenite aplikaciju
         - Vidite šta je greška

KORAK 6: Koristite VS Code Debugger
         - Postavite breakpoint (kliknite na liniju)
         - F5 za debug mode
         - Step through (F10)
         - Step into (F11)
```

**Saveti za debugging:**
```dart
// LOŠE - bez error handling:
await PutnikService.instance.oznaciPokupljen(id);

// DOBRO - sa error handling:
try {
  await PutnikService.instance.oznaciPokupljen(id);
} catch (e) {
  print('Greška pri označavanju: $e');
}
```

---

## 8️⃣ PRONALAŽENJE FUNKCIJE PO KLJUČNOJ REČI

### **Scenarij: "Trebam funkciju koja se bavi plaćanjima - gde je?"**

```
METODA 1: Pronađi po delu imena
- Ctrl+Shift+F
- Upišite: placan
- Vidite sve što sadrži "placan"

METODA 2: Pronađi po tipu servisa  
- Ctrl+P
- Upišite: financije_service
- Enter

METODA 3: Pronađi po reči u kodu
- Ctrl+Shift+F
- Upišite: "plaćanje"
- Vidite sve lokacije gde se pojavljuje

METODA 4: Koristi Semantic Search
- Cmd+Shift+P (Command Palette)
- Upišite: "Go to Symbol"
- Vidite sve simbole sa filterovanjem
```

**Rezultat:**
```
azurirajPlacanjeZaMesec() - registrovani_putnik_service
_sacuvajPlacanjeStatic() - putnik_card
recordTransaction() - financije_service
... (5 više)
```

---

## 9️⃣ ANALIZA ZAVISNOSTI FUNKCIJE

### **Scenarij: "Koju funkciju trebam da promenim ako trebam da dodam novu logiku za plaćanja?"**

```
KORAK 1: Identifikuj glavnu funkciju
         azurirajPlacanjeZaMesec() u registrovani_putnik_service

KORAK 2: Pronađi sve reference
         Ctrl+Shift+H na liniji funkcije
         
KORAK 3: Analiziraj sve pozivače:
         - _sacuvajPlacanjeStatic() (putnik_card.dart)
         - weekly_reset_service
         - financije_autonomous_service
         
KORAK 4: Pronađi sve što ova funkcija poziva:
         - Ctrl+P > registrovani_putnik_service
         - Ctrl+F > azurirajPlacanjeZaMesec
         - F12 na liniji
         - Vidite šta se poziva u telu funkcije

KORAK 5: Kreiraj map zavisnosti:
         azurirajPlacanjeZaMesec()
         ├── supabase.update()
         ├── VoznjeLogService.logGeneric()
         ├── financije_service.recordTransaction()
         └── notifikacija
```

**Rezultat:** Znate tačno šta trebate da promenite i šta će biti uticaj ✅

---

## 🔟 PRONALAŽENJE SVIH KRAJA KODA (FUNCTION RETURNS)

### **Scenarij: "Šta sve vraća funkcija `getPutniciByDayIso`?"**

```
KORAK 1: Pronađite funkciju
         Ctrl+P > putnik_service
         Ctrl+F > getPutniciByDayIso

KORAK 2: Čitajte return type
         Future<List<Putnik>> getPutniciByDayIso()
         
KORAK 3: Pronađite sve `return` iskaze
         Ctrl+F (u istoj datoteci) > return
         
KORAK 4: Analizirajte šta se vraća:
         ```dart
         return putnici;        // List<Putnik>
         return [];             // Empty list
         return null;           // Null (ako je nullable)
         ```

KORAK 5: Razumete sve mogućnosti
         - Šta se vraća u success case
         - Šta se vraća ako nema podataka
         - Šta se vraća ako je greška
```

---

## 1️⃣1️⃣ DODAVANJE NOVE FUNKCIJE

### **Scenarij: "Trebam da dodam novu funkciju `markAsCompleted`"**

```
KORAK 1: Pronađite gdje da je dodate
         Ctrl+P > putnik_service
         
KORAK 2: Nađite sličnu funkciju (npr: oznaciPokupljen)
         Ctrl+F > oznaciPokupljen
         
KORAK 3: Kopira njeno telo kao template
         Ctrl+C
         
KORAK 4: Locite mesto za novu funkciju
         - Obično posle sličnih funkcija
         - Grupiši po funkcionalnosti
         
KORAK 5: Paste i izmeni
         - Promenite ime
         - Promenite logiku
         - Promenite return type
         
KORAK 6: Dodajte na nova poziva
         Ctrl+P > putnik_card
         Ctrl+F > oznaciPokupljen
         Dodajte slično za vašu novu funkciju
```

**Struktura nove funkcije:**
```dart
Future<void> markAsCompleted(
  dynamic id,
  String completedBy,
  {String? grad, String? selectedDan}
) async {
  try {
    // 1. Validiraj ulaz
    if (id == null) throw 'Invalid ID';
    
    // 2. Ažuriraj bazu
    await supabase
        .from('putnici')
        .update({'status': 'zavrseno'})
        .eq('id', id);
    
    // 3. Loguj
    await VoznjeLogService.instance.logGeneric(
      type: 'completion',
      putnikId: id,
      vozacIme: completedBy,
    );
    
    // 4. Osvežи stream
    _refreshAllStreams();
  } catch (e) {
    print('Error: $e');
    rethrow;
  }
}
```

---

## 1️⃣2️⃣ PRONALAŽENJE DOKUMENTACIJE ZA FUNKCIJU

### **Scenarij: "Trebam da razumem šta radi `getPutniciByDayIso`"**

```
KORAK 1: Pronađite funkciju
         Ctrl+P > putnik_service
         Ctrl+F > getPutniciByDayIso

KORAK 2: Proverite dokumentaciju
         - Vidite li /// comments gore?
         - Vidite li parameter descriptions?

KORAK 3: Čitajte dokumentaciju
         ```dart
         /// Pronalazi sve putnike za dati dan
         /// 
         /// Parametri:
         /// - [isoDate] Format: "2026-01-28"
         /// 
         /// Vraća:
         /// - List<Putnik> sa putnicima za dan
         /// 
         /// Primer:
         /// var putnici = await getPutniciByDayIso('2026-01-28');
         ```

KORAK 4: Koristite Hover (ako nema dokumentacije)
         - Ctrl+Space na funkciji
         - Vidite tip i parametre
         
KORAK 5: Proverite signatura funkcije
         Future<List<Putnik>> getPutniciByDayIso(String isoDate)
         - Future = async
         - List<Putnik> = vraća listu putnika
         - String isoDate = ulaz je datum kao string
```

---

## 1️⃣3️⃣ PRONALAŽENJE TESTOVA ZA FUNKCIJU

### **Scenarij: "Postoji li test za `oznaciPokupljen`?"**

```
KORAK 1: Pronađite test folder
         - Obično u test/
         - Pretraživanjem: Ctrl+P > test/
         
KORAK 2: Pronađite test za servis
         Ctrl+P > putnik_service_test
         
KORAK 3: Pronađite test za funkciju
         Ctrl+F > oznaciPokupljen
         
KORAK 4: Čitajte test da razumete kako se koristi
         ```dart
         test('oznaciPokupljen marks putnik as picked', () async {
           // Setup
           var putnik = createTestPutnik();
           
           // Execute
           await PutnikService.instance.oznaciPokupljen(putnik.id, 'testDriver');
           
           // Verify
           expect(putnik.status, 'pokupljen');
         });
         ```

KORAK 5: Koristite test kao dokumentaciju
         - Test pokazuje kako koristiti funkciju
         - Test pokazuje šta se očekuje
         - Test pokazuje edge cases
```

---

## 1️⃣4️⃣ PRONALAŽENJE KOJI SE EXPORT-UJU FUNKCIJE

### **Scenarij: "Koje funkcije iz `putnik_service` se koriste van servisa?"**

```
KORAK 1: Pronađite datoteku
         Ctrl+P > putnik_service
         
KORAK 2: Pronađite klasu/export
         Ctrl+F > class PutnikService
         
KORAK 3: Čitajte šta je dostupno
         - Static methods = dostupno svugde
         - Public methods = dostupno svugde
         - Private methods (_) = samo u datoteci
         
KORAK 4: Pronađite sve reference za svaki public
         Ctrl+Shift+H na metodama
```

---

## 1️⃣5️⃣ MERENJE VREMENSKE KOMPLEKSNOSTI

### **Scenarij: "Da li je funkcija `streamKombinovaniPutniciFiltered` brza?"**

```
KORAK 1: Pronađite funkciju
         Ctrl+P > putnik_service
         Ctrl+F > streamKombinovaniPutniciFiltered

KORAK 2: Analizirajte šta radi:
         - Koliko filtera se primenjuje?
         - Da li ima loop-a?
         - Da li ima nested loop-a?

KORAK 3: Proverite Supabase query
         - Koja je query complexity?
         - Koliko redova se prenosi?

KORAK 4: Postavite breakpoint
         - Kliknite na liniju
         - Debug i vidite vreme izvršavanja
```

**Saveti za optimizaciju:**
```dart
// LOŠE - učitava sve pa filtrira:
var all = await supabase.from('putnici').select();
var filtered = all.where((p) => p.grad == 'NS').toList();

// DOBRO - filtrira na bazi:
var filtered = await supabase
    .from('putnici')
    .select()
    .eq('grad', 'NS');
```

---

## 📋 QUICK REFERENCE TIPKE

| Akcija | Tipka |
|--------|-------|
| Pronađi funkciju | `Ctrl+Shift+F` |
| Pronađi u fajlu | `Ctrl+F` |
| Go to Definition | `F12` |
| Find All References | `Ctrl+Shift+H` |
| Go to File | `Ctrl+P` |
| Go to Line | `Ctrl+G` |
| Outline | `Ctrl+Shift+O` |
| Rename | `F2` |
| Quick Fix | `Ctrl+.` |
| IntelliSense | `Ctrl+Space` |
| Navigate back | `Alt+←` |
| Navigate forward | `Alt+→` |
| Hover (doc) | `Ctrl+K Ctrl+I` |
| Terminal | ``Ctrl+` `` |
| Debug | `F5` |
| Breakpoint | `F9` |
| Step into | `F11` |
| Step over | `F10` |

---

## 🎯 ČESTI PROBLEMI & REŠENJA

### Problem 1: "Ne mogu da pronađem funkciju"
```
Rešenje: 
1. Proverite ime (case-sensitive)
2. Koristite Ctrl+Shift+F umesto Ctrl+F
3. Proverite da li je u drugoj datoteci
```

### Problem 2: "F12 ne ide na definiciju"
```
Rešenje:
1. Postavite kursor NA reč
2. Probajte Ctrl+Click
3. Čekajte da se index učita (prvi put je sporo)
```

### Problem 3: "Ctrl+Shift+H ne pokazuje sve reference"
```
Rešenje:
1. Kliknite na funkciji (je ona selected?)
2. Probajte ponovo
3. Proverite settings - možda su referencе skrivene
```

### Problem 4: "Promenjeno jednom kada trebalo svugde"
```
Rešenje:
1. Koristite F2 (Rename) umesto manuelne izmene
2. F2 automatski ažurira SVE reference
```

---

## 🚀 ZAKLJUČAK

**Sada možete:**
1. ✅ Brzo pronći bilo koju funkciju
2. ✅ Videti sve reference
3. ✅ Razumeti ceo tok
4. ✅ Bezbedno menjati kod
5. ✅ Debugovati probleme
6. ✅ Dodavati nove funkcije

**Zapamtite:** `Ctrl+Shift+F` i `Ctrl+Shift+H` su vaši najbliži prijatelji! 🎯

