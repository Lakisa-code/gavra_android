# PRONAĐENI PROBLEMI - TIME PICKER SINHRONIZACIJA

## PROBLEM 1: 🚨 ADMIN DODAJ DNEVNOG PUTNIKA - NEDOSTAJE ZAŠTITA

### Lokacija
`lib/widgets/registrovani_putnik_dialog.dart` - `TimeRow` widget (linije 1078-1138)

### Šta se dešava
Kada admin dodaje **DNEVNOG putnika**, koristi `TimeRow` sa `isAdmin: true`, ali `TimeRow` **NE prosljeđuje `tipPutnika` vrednost** ka `TimePickerCell`:

```dart
TimeRow(
  dayLabel: DayConstants.dayNamesInternal[0],
  bcController: _polazakBcControllers['pon']!,
  vsController: _polazakVsControllers['pon']!,
  bcStatus: _getStatusForDay('pon', true),
  vsStatus: _getStatusForDay('pon', false),
  dayName: 'pon',
  isAdmin: true,
  // ❌ tipPutnika NIJE prosleđen
)
```

A u `TimeRow`, `TimePickerCell` se kreira sa `tipPutnika` koji je `null`:

```dart
// time_row.dart
return TimePickerCell(
  value: currentValue,
  isBC: true,
  status: bcStatus,
  isCancelled: bcStatus == 'otkazano',
  isAdmin: isAdmin,
  dayName: dayName,
  onChanged: (newValue) { bcController.text = newValue ?? ''; },
  // ❌ tipPutnika je null (nije prosleđen)
);
```

### Problem
U `TimePickerCell`, logika zaštite za dnevne putnike proverava:

```dart
if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && !isAdmin) {
  // ZAŠTITA: Samo tekući dan i sutrašnji dan
}
```

Pošto je `tipPutnika == null`, **zaštita se ne primenjuje čak i ako je admin dodao dnevnog putnika**!

### Posledica
Admin može da:
1. Dodaj DNEVNOG putnika (tip = 'dnevni')
2. Postavi vremena za bilo koji dan u nedelji (čak i za budućnost od 2 nedeje)
3. Sačuva putnika

Putnik kasnije **NE MOŽE** da menja ta vremena jer će mu biti blokirana logika za dnevne putnike.

---

## PROBLEM 2: ⚠️ STATUS RESET NAKON ADMIN IZMENE

### Lokacija
`lib/widgets/registrovani_putnik_dialog.dart` - `_buildTimesSection()` (linije 1025-1138)

### Šta se dešava
Kada admin menja vremenske vrednosti u tekstualnim poljima, **status se ne resetuje**. Status može biti:
- `'pending'` - Čeka se admin odobrenje
- `'confirmed'` - Odobren
- `'rejected'` - Odbijen
- `null` - Nema statusа

### Problem
Ako je putnik zahtevao vreme i status je `'pending'`, a admin izmeni drugačije vreme, status **ostaje `'pending'`** umesto da bude resetovan na `null` ili `'confirmed'`.

### Primer
```
1. Putnik zahteva: BC=07:00 (status='pending')
2. Admin otvori dialog i vidi: BC=07:00 sa statusom 'pending'
3. Admin promeni: BC=08:00
4. Admin sačuva
5. Rezultat: BC=08:00 sa statusom='pending' (❌ GREŠKA - trebalo bi null ili 'confirmed')
```

---

## PROBLEM 3: ⚠️ TIPPUTNIKA NEDOSTAJE U ADMIN DIJALOGU

### Lokacija
`lib/widgets/registrovani_putnik_dialog.dart` - Sve `TimeRow` instance

### Šta se dešava
`TimeRow` widget **ne prima `tipPutnika` parametar**, što znači da `TimePickerCell` uvek dobija `tipPutnika = null`.

### Problem
Nema mogućnosti da se primeni specifična logika zavisno od tipa putnika:
- DNEVNI putnici - trebala bi zaštita (samo tekući dan + sutrašnji)
- UČENICI - trebala bi letnja/zimska verifikacija
- RADNICI - trebala bi posebna logika

### Rešenje
Trebalo bi da `TimeRow` bude spreman da prima `tipPutnika`:

```dart
class TimeRow extends StatelessWidget {
  final String? tipPutnika; // 🆕 Dodati
  
  const TimeRow({
    // ...
    this.tipPutnika, // 🆕 Dodati
  });
  
  return TimePickerCell(
    // ...
    tipPutnika: tipPutnika, // 🆕 Prosleđiti
  );
}
```

---

## PROBLEM 4: ⚠️ DIALOG ČEKANJE ZA ADMIN - PODE BITI BRŽE

### Lokacija
`lib/widgets/registrovani_putnik_dialog.dart` - `_buildTimesSection()` linije ~1100

### Šta se dešava
Kada admin menja vremenske vrednosti, tekstualna polja se ažuriraju, ali ne postoji vizuelna povratna informacija o tome da li će izmena biti sačuvana.

### Nije baš problem, ali BO je povećati UX

---

## PRIORITET PROBLEMA

| # | Problem | Prioritet | Uticaj | Rešenje |
|---|---------|-----------|--------|---------|
| 1 | Admin dodaj dnevnog putnika - nedostaje zaštita | 🔴 VISOK | Admin može pogrešno konfigurirati dnevne putnike | Dodati `tipPutnika` u `TimeRow` |
| 2 | Status reset nakon admin izmene | 🟡 SREDNJI | Ostatak stari status, zbunjujuće putnicima | Resetovati status na `null` pri admin izmeni |
| 3 | Nedostaje `tipPutnika` u TimeRow | 🟡 SREDNJI | Nema specifične logike po tipu putnika | Dodati parametar |
| 4 | UX povratna informacija | 🟢 MALI | Nije jasno da se izmena čuva | Dodati loading state |

---

## PREPORUKE

### 1. HITNA ISPRAVKA
```dart
// time_row.dart - Dodati tipPutnika
class TimeRow extends StatelessWidget {
  final String? tipPutnika; // 🆕
  
  const TimeRow({
    // ... ostali parametri
    this.tipPutnika,
  });
  
  @override
  Widget build(BuildContext context) {
    return TimePickerCell(
      // ... ostali parametri
      tipPutnika: tipPutnika, // 🆕 Prosleđiti
    );
  }
}

// registrovani_putnik_dialog.dart - Prosleđiti tipPutnika
TimeRow(
  dayLabel: DayConstants.dayNamesInternal[0],
  bcController: _polazakBcControllers['pon']!,
  vsController: _polazakVsControllers['pon']!,
  bcStatus: _getStatusForDay('pon', true),
  vsStatus: _getStatusForDay('pon', false),
  dayName: 'pon',
  isAdmin: true,
  tipPutnika: widget.existingPutnik?.tip, // 🆕 PROSLEĐITI TIP
)
```

### 2. STATUS RESET
```dart
// registrovani_putnik_dialog.dart - Pri sačuvavanju
// Resetovati sve statuse ako je admin promenio vremenske vrednosti
if (widget.isEditing && vrednostPromenjena) {
  polasci[dan]['${place}_status'] = null; // Reset na null
}
```

### 3. VALIDACIJA
```dart
// timePickerCell - Dodati proveru
if (tipPutnika == 'dnevni' && !isAdmin) {
  // Primeni zaštitu čak i ako je dodat kroz admin
}
```

---

## ZAKLJUČAK

**Vremenske vrednosti JE sinhronizovane**, ali postoji **OPASNOST** u admin dijalogu gde se dnevni putnici mogu pogrešno konfigurirati. Trebalo bi dodati `tipPutnika` parametar u `TimeRow` da bi se zaštitila specifična logika po tipu putnika.

**Preporuka: Ažurirati `TimeRow` i `RegistrovaniPutnikDialog` da prosleđuju `tipPutnika`.**
