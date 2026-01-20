# 🚌 Popravka: Dodeljivanje vozača po danu, gradu I VREMENU

## Problem
Ranije, dodeljeni putnici su bili sačuvani samo po **danu** i **gradu** (npr. `bc_vozac` ili `vs_vozac` u JSON-u).

**Zabuna:** Ako je isti vozač vozio u ponedeljak u BC u 5:00 **I** u VS u 14:00, svi putnici su bili dodeljeni istom vozaču jer sistem nije razlikovao vreme.

### Primer problema:
- Ponedeljak, BC 5:00 → Ivan vozi
- Ponedeljak, VS 14:00 → Ivan se vraća nazad

**Stara logika:** Putnici iz oba termina su bili dodeljeni Ivanu jer JSON ključ je bio samo `bc_vozac` i `vs_vozac`.

---

## Rešenje
Dodeljivanje vozača je sada **specifično po VREMENU**:

### Nova JSON struktura:
```json
{
  "pon": {
    "bc_5:00_vozac": "Ivan",    // BC 5:00 → Ivan
    "vs_14:00_vozac": "Bojan"   // VS 14:00 → Bojan (drugi vozač!)
  }
}
```

---

## Izmenjeni fajlovi

### 1. `lib/utils/registrovani_helpers.dart`
**Funkcija:** `getDodeljenVozacForDayAndPlace()`

**Promena:**
- Dodao opcioni parametar `vreme`
- Prvo proverava specifičan ključ: `bc_5:00_vozac`
- Ako ne postoji, fallback na generički: `bc_vozac`

```dart
static String? getDodeljenVozacForDayAndPlace(
  Map<String, dynamic> rawMap,
  String dayKratica,
  String place, {
  String? vreme, // 🆕 Opcioni parametar
}) {
  // ...
  if (vreme != null && vreme.isNotEmpty) {
    final vremeVozacKey = '${place}_${normalizedVreme}_vozac';
    final vremeVozac = dayData[vremeVozacKey];
    if (vremeVozac != null) return vremeVozac;
  }
  // Fallback:
  return dayData['${place}_vozac'];
}
```

---

### 2. `lib/models/putnik.dart`
**Funkcija:** `_getDodeljenVozacWithPriority()`

**Promena:**
- Prosleđuje parametar `vreme` u `getDodeljenVozacForDayAndPlace()`
- Sada čita vozača specifično za vreme polaska putnika

```dart
static String? _getDodeljenVozacWithPriority({
  required String vreme,
  // ...
}) {
  final perPutnikPerVreme = RegistrovaniHelpers.getDodeljenVozacForDayAndPlace(
    map,
    danKratica,
    place,
    vreme: vreme, // 🆕 Prosleđivanje vremena
  );
  // ...
}
```

---

### 3. `lib/services/putnik_service.dart`
**Funkcija:** `dodelPutnikaVozacuZaPravac()`

**Promena:**
- Dodao parametar `vreme`
- Sada čuva vozača sa vremenom u JSON ključu: `bc_5:00_vozac` ili `vs_14:00_vozac`

```dart
Future<void> dodelPutnikaVozacuZaPravac(
  String putnikId,
  String? noviVozac,
  String place, {
  String? vreme, // 🆕 Obavezan za specifično dodeljivanje
  String? selectedDan,
}) async {
  // ...
  if (vreme != null && vreme.isNotEmpty) {
    vozacKey = '${place}_${normalizedVreme}_vozac';
  } else {
    vozacKey = '${place}_vozac'; // Fallback
  }
  // ...
}
```

---

### 4. `lib/screens/dodeli_putnike_screen.dart`

**Promena:**
- Prosleđuje `_selectedVreme` pri pozivu `dodelPutnikaVozacuZaPravac()`
- Sada pojedinačno I bulk dodeljivanje čuvaju vreme

```dart
await _putnikService.dodelPutnikaVozacuZaPravac(
  putnik.id!,
  noviVozac,
  pravac,
  vreme: _selectedVreme, // 🆕 Prosleđivanje vremena
  selectedDan: dan,
);
```

---

## Rezultat

✅ **Ponedeljak, BC 5:00** → Putnici dodeljeni **Ivanu**  
✅ **Ponedeljak, VS 14:00** → Putnici dodeljeni **Bojanu** (ili nekom drugom)

**Nema više zabune!** Svaki termin ima svog dodeljenog vozača.

---

## Kako testirati

1. **Otvori "Dodeli Putnike" ekran**
2. **Izaberi Ponedeljak, BC, 5:00**
3. **Dodeli putnike vozaču "Ivan"**
4. **Izaberi Ponedeljak, VS, 14:00**
5. **Dodeli putnike vozaču "Bojan"**
6. **Proveri:**
   - BC 5:00 putnici su dodeljeni Ivanu ✅
   - VS 14:00 putnici su dodeljeni Bojanu ✅
   - Nema mešanja ✅

---

## Kompatibilnost

✅ **Stari JSON format (`bc_vozac`, `vs_vozac`) će i dalje raditi kao fallback.**  
✅ **Novi format (`bc_5:00_vozac`, `vs_14:00_vozac`) ima prioritet.**

To znači da postojeći podaci ostaju validni, ali novi unosi koriste preciznije vreme.

---

## Datum izmene
20. januar 2026.
