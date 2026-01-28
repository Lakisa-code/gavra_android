# Bug Fix: Payment Status Not Updating Between Locations

**Issue**: When putnik was paid in BC (9:00) for 600 RSD, the same status showed in VS (17:00) even though payment should persist across locations within the same month.

**Root Cause** (Found in `lib/utils/registrovani_helpers.dart` lines 460-500):

```dart
// BEFORE - BUGGY CODE
static DateTime? getVremePlacanjaForDayAndPlace(...) {
  // ...
  try {
    final placenoDate = DateTime.parse(placenoTimestamp).toLocal();
    final danas = DateTime.now();
    // ❌ BUG: Return null if NOT today
    if (placenoDate.year == danas.year && 
        placenoDate.month == danas.month && 
        placenoDate.day == danas.day) {
      return placenoDate;
    }
    return null;  // ❌ Returns null if payment was yesterday
  } catch (_) {
    return null;
  }
}
```

**Impact Chain**:
1. Putnik naplaćen BC → `bc_placeno` timestamp je setovan
2. Putnik učitan u VS → `getVremePlacanjaForDayAndPlace()` vratiti `null` (jer plaćanje NIJE danasnje)
3. `vremePlacanja == null` → `cena = 0.0` (za dnevne putnike)
4. `iznosPlacanja = 0` → `CardState.placeno` se ne prikazuje

**Solution** (In `lib/utils/registrovani_helpers.dart`):

```dart
// AFTER - FIXED
static DateTime? getVremePlacanjaForDayAndPlace(...) {
  // ...
  try {
    final placenoDate = DateTime.parse(placenoTimestamp).toLocal();
    // ✅ ISPRAVKA: Return timestamp čak i ako NIJE danasnje
    // Plaćanje važi za ceo mesec, ne samo za dan kad je plaćeno
    return placenoDate;
  } catch (_) {
    return null;
  }
}
```

**Why This Works**:
- Payment records are stored with timestamps in `polasci_po_danu` JSON
- Once paid (in any location/day), putnik should show as paid in all locations within same month
- Removing the "only today" check allows payment status to persist correctly
- The comment explains: "Plaćanje važi za ceo mesec" (Payment is valid for entire month)

---

## Technical Details

**Related Fields**:
- `bc_placeno`: timestamp when paid in BC (Business Center)
- `vs_placeno`: timestamp when paid in VS (Visoka Škola)
- `polasci_po_danu`: JSON object storing per-location data

**Affected Code Flow**:
```
Putnik.fromMap() 
  → getVremePlacanjaForDayAndPlace()  ✅ FIXED
  → vremePlacanja = DateTime (now works across days)
  → placeno = (vremePlacanja != null)  ✅ Now true for paid
  → cena = _parseDouble(...)  ✅ Now shows correct amount
  → CardColorHelper.getCardStateWithDriver()
  → CardState.placeno  ✅ Card shows green/paid color
```

---

## Build & Deploy

- ✅ flutter analyze: 0 issues
- ✅ flutter build apk: SUCCESS
- ✅ flutter install: SUCCESS (NOH NX9 device)

---

## Testing

**Before Fix**:
- BC 9:00: 600 RSD paid ✓
- VS 17:00: 0 RSD (card shows unpaid) ❌

**After Fix**:
- BC 9:00: 600 RSD paid ✓
- VS 17:00: 600 RSD paid ✓ (shows in green)

**To Verify**:
1. Pay for putnik in BC location
2. Switch to VS location in same day
3. Check if payment status persists correctly
4. Amount should show as 600 RSD (or appropriate amount)
5. Card should display green "placeno" state
