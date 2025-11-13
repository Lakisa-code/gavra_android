# 🔥 HOMESCREEN REALTIME STATUS

**Datum:** 12. Novembar 2025  
**Commit:** c2303fa1  
**File:** `lib/screens/home_screen.dart`

---

## ✅ REALTIME IMPLEMENTACIJA

### 🏠 **HomeScreen - Bottom Nav Bar Brojači**

**Status:** ✅ **100% REALTIME RADI**

---

## 📋 STREAM SOURCE

**Kod:**
```dart
// Line 1497
return StreamBuilder<List<Putnik>>(
  stream: _putnikService.streamKombinovaniPutnici(),
  builder: (context, snapshot) {
    // ...
  }
);
```

**Realtime Tables (Supabase):**
- `mesecni_putnici` - Mesečni putnici
- `putovanja_istorija` - Dnevni putnici (tip_putnika='dnevni')

**Service:**
```dart
// lib/services/putnik_service.dart:695
Stream<List<Putnik>> streamKombinovaniPutnici() {
  final mesecniStream = RealtimeService.instance.tableStream('mesecni_putnici');
  final putovanjaStream = RealtimeService.instance.tableStream('putovanja_istorija');
  
  return CombineLatestStream.combine2(
    mesecniStream,
    putovanjaStream,
    (mesecniData, putovanjaData) => {
      'mesecni': mesecniData,
      'putovanja': putovanjaData,
    },
  ).asyncMap((maps) async {
    // Kombinuje mesečne i dnevne putnike u jedinstvenu listu
  });
}
```

---

## 🎯 FUNKCIONALNOST

### Šta se REALTIME ažurira:

1. **Dodavanje putnika**
   - Dodaš novog putnika → Broj u Bottom Nav Bar se **odmah povećava**
   - Bez ručnog refresh-a

2. **Otkazivanje putnika**
   - Otkažeš putnika (❌ ikona) → Broj se **odmah smanjuje**
   - Kartica postaje crvena

3. **Bolovanje/Godišnji**
   - Označiš bolovanje/godišnji → Broj se **odmah smanjuje**
   - Kartica postaje žuta

4. **Pokupljanje putnika**
   - Long press na karticu → Označi pokupljen
   - Kartica postaje plava
   - **Broj OSTAJE ISTI** (i dalje aktivni putnik)

5. **Plaćanje**
   - 💰 ikona → Naplaćen
   - Kartica postaje zelena
   - **Broj OSTAJE ISTI** (i dalje aktivni putnik)

---

## 🔍 FILTER LOGIKA

### Bottom Nav Bar Brojač (Line 1713)

**Funkcija:**
```dart
int getPutnikCount(String grad, String vreme) {
  return allPutnici.where((putnik) {
    final gradMatch = GradAdresaValidator.isGradMatch(
      putnik.grad,
      putnik.adresa,
      grad,
    );
    final vremeMatch = _normalizeTime(putnik.polazak) == _normalizeTime(vreme);
    final danMatch = normalizedPutnikDan.contains(normalizedDanBaza);
    final statusOk = TextUtils.isStatusActive(putnik.status);
    
    return gradMatch && vremeMatch && danMatch && statusOk;
  }).length;
}
```

**Filteri:**
1. **Grad:** Bela Crkva / Vršac
2. **Vreme:** 5:00, 6:00, 7:00, 8:00, 9:00, 11:00, 12:00, 13:00, 14:00, 15:30, 18:00
3. **Dan:** Ponedeljak, Utorak, Sreda, Četvrtak, Petak
4. **Status:** Samo aktivni (isStatusActive)

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

**Kod:**
```dart
static bool isStatusActive(String? status) {
  if (status == null) return true;
  final normalized = normalizeText(status);

  return !otkazani.any((s) => normalizeText(s) == normalized) &&
      !bolovanjeGodisnji.any((s) => normalizeText(s) == normalized) &&
      !neaktivni.any((s) => normalizeText(s) == normalized);
}
```

---

## ✅ VERIFIKACIJA

**Test scenario:**
1. Otvori HomeScreen
2. Izaberi dan (npr. Ponedeljak)
3. Izaberi grad (Bela Crkva)
4. Izaberi vreme (6:00)
5. Bottom Nav Bar prikazuje broj putnika za to vreme

**Realtime test:**
1. Dodaj novog putnika za Ponedeljak, Bela Crkva, 6:00
2. **Proveri:** Broj u Bottom Nav Bar se **odmah povećava** ✅
3. Otkaži tog putnika
4. **Proveri:** Broj se **odmah smanjuje** ✅
5. Dodaj putnika i označi pokupljen (long press)
6. **Proveri:** Kartica postaje plava, **broj ostaje isti** ✅

---

## 🔧 TEHNIČKI DETALJI

**Dependencies:**
- `RealtimeService.instance.tableStream()` - Supabase Realtime
- `CombineLatestStream.combine2()` - RxDart stream kombinovanje
- `TextUtils.isStatusActive()` - Status validacija
- `GradAdresaValidator.isGradMatch()` - Grad/adresa matching

**Performance:**
- Single stream za oba izvora (mesečni + dnevni)
- Client-side filtering (brzo)
- Auto-refresh bez API call-ova

---

## 📝 GIT COMMIT

**c2303fa1** - 🔥 FEATURE: Add realtime stream to HomeScreen for Bottom Nav Bar

**Changes:**
```diff
- stream: Stream.fromFuture(_putnikService.getAllPutniciFromBothTables(targetDay: _selectedDay)).asBroadcastStream()
+ stream: _putnikService.streamKombinovaniPutnici()
```

**Files changed:**
- `lib/screens/home_screen.dart` (1 file, 9 lines: +3, -6)

---

## ✅ STATUS: KOMPLETNO ✅

**HomeScreen Bottom Nav Bar je 100% REALTIME.**  
Sve funkcionalnosti rade kako treba bez manual refresh-a.
