# 🔥 DANASSCREEN REALTIME STATUS

**Datum:** 12. Novembar 2025  
**Commit:** 62ab7a20  
**File:** `lib/screens/danas_screen.dart`

---

## ✅ REALTIME IMPLEMENTACIJA

### 📱 **DanasScreen - AppBar Kocke & Bottom Nav Bar**

**Status:** ✅ **100% REALTIME RADI**

---

## 🎯 APPBAR KOCKE (Brojači)

### 1. 🎓 **ĐAČKI BROJAČ**

**Status:** ✅ **100% REALTIME** (refaktorisano)

**Widget:** `_buildDjackiBrojacButton()` (line 489)

**Stream Source:**
```dart
StreamBuilder<Map<String, int>>(
  stream: _streamDjackieBrojevi(),
  builder: (context, snapshot) {
    // Display: ukupno_ujutro (belo) + ostalo (crveno)
  }
)
```

**Realtime Table:** `mesecni_putnici` (Supabase Realtime)

**Stream funkcija:**
```dart
// Line 247
Stream<Map<String, int>> _streamDjackieBrojevi() {
  return MesecniPutnikService.streamAktivniMesecniPutnici()
    .map((sviMesecniPutnici) {
      // Filtrira đake/učenike za današnji dan
      // Računa: ukupno_ujutro, reseni, otkazali, ostalo
    });
}
```

**Logika:**
- **ukupno_ujutro:** Svi učenici koji idu ujutro u Belu Crkvu
- **reseni:** Učenici upisani za OBA pravca (BC + VS)
- **otkazali:** Učenici koji su otkazali/bolovanje/godišnji
- **ostalo:** Učenici koji imaju samo BC polazak (nemaju VS)

**Display u AppBar:**
```
🎓 30  10
   ↑   ↑
   │   └── Ostalo (crveno) - samo BC polazak
   └────── Ukupno ujutro (belo) - svi učenici BC
```

**Dialog (klik na dugme):**
```
Đaci - Danas (15/10)

📊 Ukupno ujutro (BC): 30
   ├── ✅ Rešeni (15) - imaju BC + VS polazak
   ├── 🟠 Ostalo (10) - samo BC polazak
   └── 🔴 Otkazali (5) - otkazani/bolovanje/godišnji
```

---

### 2. 🟢 **PAZAR Kocka**

**Status:** ✅ **100% REALTIME**

**Stream Source:**
```dart
StreamBuilder<double>(
  stream: StatistikaService.streamPazarZaVozaca(
    _currentDriver ?? '',
    from: dayStart,
    to: dayEnd,
  ),
  builder: (context, pazarSnapshot) {
    final ukupnoPazarVozac = pazarSnapshot.data ?? 0.0;
    // Display: pazar za današnji dan
  }
)
```

**Realtime Tables:**
- `putovanja_istorija` (dnevni putnici)
- `mesecni_putnici` (mesečni putnici)

**Funkcionalnost:**
- Prikazuje ukupan pazar vozača za današnji dan
- Auto-refresh kada se doda/naplaći putnik

---

### 3. 🟣 **MESEČNE Kocka**

**Status:** ✅ **100% REALTIME**

**Stream Source:**
```dart
StreamBuilder<int>(
  stream: StatistikaService.streamBrojMesecnihKarataZaVozaca(
    _currentDriver ?? '',
    from: dayStart,
    to: dayEnd,
  ),
  builder: (context, mesecneSnapshot) {
    final brojMesecnih = mesecneSnapshot.data ?? 0;
    // Display: broj mesečnih karata
  }
)
```

**Realtime Table:** `mesecni_putnici`

**Funkcionalnost:**
- Prikazuje broj aktivnih mesečnih karata za vozača
- Auto-refresh kada se doda/otkaže mesečna karta

---

### 4. 🟠 **KUSUR Kocka**

**Status:** ✅ **100% REALTIME**

**Stream Source:**
```dart
StreamBuilder<double>(
  stream: SimplifiedDailyCheckInService.streamTodayAmount(
    _currentDriver ?? '',
  ),
  builder: (context, sitanSnapshot) {
    final sitanNovac = sitanSnapshot.data ?? 0.0;
    // Display: kusur za današnji dan
  }
)
```

**Realtime Table:** `daily_checkin` (ili sličan)

**Funkcionalnost:**
- Prikazuje sitan novac (kusur) za današnji dan
- Auto-refresh kada vozač unese novi kusur

---

### 5. 🔴 **DUGOVI Kocka**

**Status:** ⚠️ **Nije stream** (samo navigacija)

**Widget:**
```dart
InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => DugoviScreen(
          currentDriver: _currentDriver,
        ),
      ),
    );
  },
  // Display: ikona za navigaciju ka DugoviScreen
)
```

**Funkcionalnost:**
- Klik otvara DugoviScreen
- Nije realtime brojač (samo navigacija)

---

## 📱 BOTTOM NAVIGATION BAR

**Status:** ✅ **100% REALTIME**

**Stream Source:**
```dart
StreamBuilder<List<Putnik>>(
  stream: _putnikService.streamKombinovaniPutniciFiltered(
    isoDate: DateTime.now().toIso8601String().split('T')[0],
  ),
  builder: (context, snapshot) {
    final allPutnici = snapshot.data ?? <Putnik>[];
    // Brojanje putnika za svaki polazak
  }
)
```

**Realtime Tables:**
- `mesecni_putnici` - Mesečni putnici
- `putovanja_istorija` - Dnevni putnici

**Filter Logika:**
```dart
int getPutnikCount(String grad, String vreme) {
  return allPutnici.where((putnik) {
    final gradMatch = GradAdresaValidator.isGradMatch(
      putnik.grad,
      putnik.adresa,
      grad,
    );
    final vremeMatch = _normalizeTime(putnik.polazak) == _normalizeTime(vreme);
    final danMatch = targetDayMatch; // Današnji dan
    final statusOk = TextUtils.isStatusActive(putnik.status);
    
    return gradMatch && vremeMatch && danMatch && statusOk;
  }).length;
}
```

**Filteri:**
1. **Grad:** Bela Crkva / Vršac
2. **Vreme:** 5:00, 6:00, 7:00, 8:00, 9:00, 11:00, 12:00, 13:00, 14:00, 15:30, 18:00 (BC)
   + 6:00, 7:00, 8:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:30, 17:00, 19:00 (VS)
3. **Dan:** Današnji dan (ISO datum)
4. **Status:** Samo aktivni (isStatusActive)

**Zimski/Letnji Raspored:**
- `BottomNavBarZimski` - Za zimski raspored
- `BottomNavBarLetnji` - Za letnji raspored

**Funkcionalnost:**
- Auto-refresh kada se dodaj/otkaže putnik
- Resetovanje pokupljenja (long press na slot)

---

## 📊 STATUS LOGIKA

### TextUtils.isStatusActive() (lib/utils/text_utils.dart:39)

**Broji se kao AKTIVAN:**
- ⚪ Nepokupljen
- 🔵 Pokupljen
- 🟢 Naplaćen

**NE broji se (neaktivan):**
- 🔴 Otkazan
- 🟡 Bolovanje
- 🟡 Godišnji
- ⚫ Obrisan

---

## 🔧 TEHNIČKI DETALJI

**Dependencies:**
- `RealtimeService.instance.tableStream()` - Supabase Realtime
- `MesecniPutnikService.streamAktivniMesecniPutnici()` - Stream mesečnih putnika
- `StatistikaService.streamPazarZaVozaca()` - Stream pazar statistike
- `StatistikaService.streamBrojMesecnihKarataZaVozaca()` - Stream broj mesečnih
- `SimplifiedDailyCheckInService.streamTodayAmount()` - Stream kusur
- `TextUtils.isStatusActive()` - Status validacija
- `GradAdresaValidator.isGradMatch()` - Grad/adresa matching

**Performance:**
- Single stream za svaku komponentu
- Client-side filtering (brzo)
- Auto-refresh bez API call-ova

---

## ✅ VERIFIKACIJA

**Test scenario - Đački Brojač:**
1. Otvori DanasScreen
2. Klikni na 🎓 dugme u AppBar-u
3. Vidi trenutno stanje: Ukupno ujutro, Rešeni, Ostalo, Otkazali
4. Otkaži jednog učenika (promeni status)
5. **Proveri:** Brojač se **odmah ažurira** ✅

**Test scenario - Bottom Nav Bar:**
1. Otvori DanasScreen
2. Izaberi polazak (npr. Bela Crkva 6:00)
3. Dodaj novog putnika za taj polazak
4. **Proveri:** Broj u Bottom Nav Bar se **odmah povećava** ✅
5. Otkaži tog putnika
6. **Proveri:** Broj se **odmah smanjuje** ✅

**Test scenario - Pazar:**
1. Otvori DanasScreen
2. Vidi trenutni pazar u 🟢 kocki
3. Naplati putnika (💰 ikona)
4. **Proveri:** Pazar se **odmah ažurira** ✅

---

## 📝 GIT COMMIT

**62ab7a20** - 🔥 FEATURE: Realtime đački brojač (AppBar) u DanasScreen - StreamBuilder umesto FutureBuilder

**Changes:**
```diff
- Widget _buildDjackiBrojacButton() {
-   return FutureBuilder<Map<String, int>>(
-     future: _calculateDjackieBrojeviAsync(),

+ Widget _buildDjackiBrojacButton() {
+   return StreamBuilder<Map<String, int>>(
+     stream: _streamDjackieBrojevi(),
```

**Files changed:**
- `lib/screens/danas_screen.dart` (1 file, +104/-77 lines)

---

## 🎯 KOMPLETAN REALTIME STATUS

| Komponenta | Realtime Status | Stream Source |
|------------|----------------|---------------|
| 🎓 Đački Brojač (AppBar) | ✅ **100% REALTIME** | `MesecniPutnikService.streamAktivniMesecniPutnici()` |
| 🟢 Pazar (AppBar) | ✅ **100% REALTIME** | `StatistikaService.streamPazarZaVozaca()` |
| 🟣 Mesečne (AppBar) | ✅ **100% REALTIME** | `StatistikaService.streamBrojMesecnihKarataZaVozaca()` |
| 🟠 Kusur (AppBar) | ✅ **100% REALTIME** | `SimplifiedDailyCheckInService.streamTodayAmount()` |
| 🔴 Dugovi (AppBar) | ⚠️ **Navigacija** | InkWell → DugoviScreen |
| 📱 Bottom Nav Bar | ✅ **100% REALTIME** | `_putnikService.streamKombinovaniPutniciFiltered()` |

---

## ✅ STATUS: KOMPLETNO ✅

**DanasScreen AppBar i Bottom Nav Bar su 100% REALTIME.**  
Sve kocke (osim Dugovi navigacije) rade realtime bez manual refresh-a.

**Đački Brojač posebno istaknuto:**
- Refaktorisan iz `FutureBuilder` → `StreamBuilder`
- Koristi `MesecniPutnikService.streamAktivniMesecniPutnici()` za realtime
- Auto-refresh kada se promeni status učenika (otkazan/bolovanje/aktivan)
