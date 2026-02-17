# TIME PICKER SINHRONIZACIJA - PUTNIK vs ADMIN

## REZIME
✅ **Time picker je SINHRONIZOVAN između putnika i admina** u većini aspekata, ali postoje ključne razlike u logici zaključavanja i mogućnostima pristupa.

---

## 1. VREMENA POLAZAKA - IDENTIČNA ✅

**Status: SINHRONIZOVANO**

### Izvora vremena
Oba (putnik i admin) koriste **identičan izvor vremena**:
- Sve vrednosti se učitavaju iz `RouteService.getVremenaPolazaka()`
- Vremena dolaze iz `RouteConfig` (hardkodovane vrednosti)
- Izbor vremenske liste zavisi od `navBarTypeNotifier.value` (globalna vrednost)

### Vremenske liste:
```
BC - Zimski:   05:00, 06:00, 07:00, 08:00, 09:00, 11:00, 12:00, 13:00, 14:00, 15:30, 18:00
BC - Letnji:   05:00, 06:00, 07:00, 08:00, 11:00, 12:00, 13:00, 14:00, 15:30, 18:00
BC - Praznici: 05:00, 06:00, 12:00, 13:00, 15:00

VS - Zimski:   06:00, 07:00, 08:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:30, 17:00, 19:00
VS - Letnji:   06:00, 07:00, 08:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:30, 18:00
VS - Praznici: 06:00, 07:00, 13:00, 14:00, 15:30
```

### Kako se koristi:
```dart
// TimePickerCell._showTimePickerDialog() - koristi za SVE
final navType = navBarTypeNotifier.value; // GLOBALNA vrednost
vremena = await RouteService.getVremenaPolazaka(grad: gradCode, sezona: sezona);
```

---

## 2. LOGIKA ZAKLJUČAVANJA - RAZLIKE IZMEĐU PUTNIKA I ADMINA

### A. Putnik (`isAdmin: false`)

**Zaključavanja koja se primenjuju:**

1. **Prošli dani** - Zaključani (ne može se pristupiti)
   ```dart
   if (dayDate.isBefore(todayOnly)) return true; // isLocked
   ```

2. **Današnji dan posle 19:00** - Zaključan
   ```dart
   if (dayDate.isAtSameMomentAs(todayOnly) && now.hour >= 19) return true;
   ```

3. **Blokada 10 minuta PRE polaska** - Ne može se menjati
   ```dart
   final lockTime = scheduledTime.subtract(const Duration(minutes: 10));
   if (now.isAfter(lockTime)) return true; // _isTimePassed()
   ```

4. **DNEVNI PUTNICI - Extra ograničenja**
   ```dart
   // SAMO tekući dan i sutrašnji dan (za rezervacije)
   if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && !isAdmin) {
     if (dayDate != null && !dayDate.isAtSameMomentAs(todayOnly) && 
         !dayDate.isAtSameMomentAs(tomorrowOnly)) {
       // BLOKIRANO
     }
   }
   ```

5. **PENDING ZAHTEVI** - Blokada (sprečavanje spama)
   ```dart
   if (isPending && !isAdmin) {
     // SnackBar: "⏳ Vaš zahtev je već u obradi..."
     return; // Blokirano
   }
   ```

6. **REJECTED ZAHTEVI** - Blokada
   ```dart
   if (isRejected && !isAdmin) {
     // SnackBar: "❌ Ovaj termin je popunjen..."
     return; // Blokirano
   }
   ```

### B. Admin (`isAdmin: true`)

**Zaključavanja koja se IGNORIŠE:**

1. ✅ Može pristupiti prošlim danima
2. ✅ Može menjati vremena čak i ako su prošla (10 min blokada se ignoriše)
3. ✅ Može menjati vremena nakon 19:00
4. ✅ Može pristupiti DNEVNIM putnicima za bilo koji dan
5. ✅ Može menjati PENDING zahteve bez čekanja
6. ✅ Može menjati REJECTED zahteve

**Kod koji omogućava ovo:**
```dart
if (locked && !isAdmin) return; // Ostali slučajevi zaključavanja
if (isPending && !isAdmin) return; // Samo za non-admin
if (isRejected && !isAdmin) return; // Samo za non-admin
if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && !isAdmin) return; // Samo za non-admin
```

---

## 3. GEJZERI I PARAMETRI - RAZLIKE

| Parametar | Putnik | Admin |
|-----------|--------|-------|
| `isAdmin` | `false` (default) | `true` (eksplicitno) |
| `tipPutnika` | Prosleđuje se (radnik, učenik, dnevni) | NIJE prosleđen (ostaje `null`) |
| `dayName` | Prosleđuje se | Prosleđuje se |
| `status` | Prosleđuje se | Prosleđuje se (pending, confirmed, null) |
| `isCancelled` | Prosleđuje se | Prosleđuje se |

### Gde se koristi:

**Putnik** - `registrovani_putnik_profil_screen.dart`:
```dart
TimePickerCell(
  value: bcDisplayVreme,
  isBC: true,
  status: bcStatus,
  dayName: dan,
  isCancelled: bcOtkazano,
  tipPutnika: tip.toString(), // ✅ ZA PROVERU DNEVNOG ZAKAZIVANJA
  tipPrikazivanja: tipPrikazivanja,
  onChanged: (newValue) => _updatePolazak(...),
  // isAdmin: false (default)
)
```

**Admin** - `registrovani_putnik_dialog.dart` (preko `TimeRow`):
```dart
TimeRow(
  dayLabel: DayConstants.dayNamesInternal[0],
  bcController: _polazakBcControllers['pon']!,
  vsController: _polazakVsControllers['pon']!,
  bcStatus: _getStatusForDay('pon', true),
  vsStatus: _getStatusForDay('pon', false),
  dayName: 'pon',
  isAdmin: true, // ✅ EKSPLICITNO
)
```

U `TimeRow` se koristi:
```dart
TimePickerCell(
  value: currentValue,
  isBC: true,
  status: bcStatus,
  isCancelled: bcStatus == 'otkazano',
  isAdmin: isAdmin, // true
  dayName: dayName,
  onChanged: (newValue) { bcController.text = newValue ?? ''; },
  // tipPutnika NIJE prosleđen (ostaje null)
)
```

---

## 4. VIZUELNE RAZLIKE - BOJE I IKONICE ✅

Obe strane koriste **identične boje i ikonice**:

| Stanje | Boja | Ikonica |
|--------|------|--------|
| Otkazano | 🔴 Crvena | `Icons.cancel` |
| Odbijeno | ❌ Narandžasto-crvena | `Icons.error_outline` |
| Zaključano | ⬜ Siva | (bez ikonice, sivorz tekst) |
| Approved/Confirmed | 🟢 Zelena | `Icons.check_circle` |
| Pending | 🟠 Narandžasta | `Icons.hourglass_empty` |
| Ima vremena | 🟢 Zelena | `Icons.check_circle` |
| Prazno | 🕐 Bela | `Icons.access_time` |

---

## 5. KLJUČNE PROMENLJIVKE - GLOBALNE ✅

Obe strane koriste **istu globalnu vrednost** za sezonu:

```dart
// globals.dart
final ValueNotifier<String> navBarTypeNotifier = ValueNotifier<String>('letnji');
```

**Korišćenje:**
```dart
// TimePickerCell._showTimePickerDialog()
final navType = navBarTypeNotifier.value; // Ista vrednost za sve
```

---

## 6. SAŽETAK SINHRONIZACIJE

### ✅ SINHRONIZOVANO:
- ✅ Vremena polazaka (identična lista)
- ✅ Globalna sezona (`navBarTypeNotifier`)
- ✅ Vizuelne boje i ikonice
- ✅ Struktura dialoga
- ✅ Logika zaključavanja (`isLocked`)
- ✅ Logika za dnevne putnike

### ⚠️ KONTROLIRANE RAZLIKE:
- ⚠️ Admin ignoriše zaključavanja (namerno)
- ⚠️ Admin nema `tipPutnika` provere (jer upravlja svim tipovima)
- ⚠️ Admin može menjati zahteve u bilo kom stanju

### ❓ POTENCIJALNI PROBLEMI:

1. **Admin TimeRow** - nema `tipPutnika` vrednosti
   ```dart
   // TimeRow NE prosljeđuje tipPutnika u TimePickerCell
   // To znači da DNEVNI putnici koji se dodaju kroz admin dijelog
   // NEĆE imati zaštitu od "samo tekući dan i sutrašnji dan"
   ```
   
   **Mogućnost**: Ako admin dodaje DNEVNOG putnika, mogu se postaviti vremena za budućne nedelje što putnik kasnije ne može promeniti.

2. **Status provera** - Status se ne čuva tokom admin izmene
   ```dart
   // Admin menja vrednosti direktno u TextEditingController
   // Status ostaje stari (pending, confirmed, null)
   // Nema eksplicitnog resetovanja statusa
   ```

---

## 7. KONEKCIJE IZMEĐU KOMPONENTI

```
┌─────────────────────────────────────────────────────┐
│          Globalna vrednost                          │
│  navBarTypeNotifier = 'zimski|letnji|praznici'      │
│  (iz app_settings tabele u Supabase)                │
└─────────────────────────┬───────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         │                                 │
    ┌────▼──────────┐            ┌────────▼────────┐
    │   PUTNIK      │            │    ADMIN        │
    │   (profil)    │            │   (dijelog)     │
    └────┬──────────┘            └────────┬────────┘
         │                                │
    ┌────▼──────────────────────────────────▼────┐
    │    TimePickerCell ili TimeRow              │
    │  (isAdmin: false | true)                   │
    └────┬──────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────┐
    │    _showTimePickerDialog()                │
    │  RouteService.getVremenaPolazaka()        │
    │  sezona = navBarTypeNotifier.value        │
    └────┬──────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────┐
    │  Ista vremenska lista za SVE              │
    │  (BC/VS, Zimski/Letnji/Praznici)          │
    └───────────────────────────────────────────┘
```

---

## ZAKLJUČAK

**Vremenske liste su potpuno sinhronizovane** jer oba (putnik i admin) čitaju iz:
1. **Istog izvora**: `RouteService` → `RouteConfig`
2. **Istog parametra sezone**: `navBarTypeNotifier.value` (globalna)
3. **Istih vremena**: Hardkodovane vrednosti iz `RouteConfig`

Jedina kontrolirana razlika je što **admin može pristupiti vremima** koja su putnicima zaključana, što je namerno dizajnirano ponašanje.

✅ **ZAKLJUČAK: Vremenske vrednosti su 100% sinhronizovane između putnika i admina.**
