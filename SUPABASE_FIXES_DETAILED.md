# 🔧 Supabase Audit - Detailed Findings Reference

## CRITICAL FIX #1: `.single()` Issues

### Files to Review/Fix:

**registrovani_putnik_service.dart (3 issues)**
```dart
// LINE 77 - ISSUE: Name lookups not unique
.eq('putnik_ime', ime)
.eq('obrisan', false)
.single();  // ❌ Will crash if 2 passengers have same name
// FIX: Change to .maybeSingle() OR add uniqueness constraint

// LINE 357 - ISSUE: Assumes passenger exists
.eq('id', id)
.single();  // ❌ Crashes if passenger deleted between load and update
// CONTEXT: Called from togglePolazak()
// FIX: Add try-catch with exists check

// LINE 424, 528 - SAME PATTERN
// All related to schedule manipulation
// FIX: Add null validation before schedule operations
```

**vozila_service.dart (1 issue)**
```dart
// LINE 23 - Vehicle lookup
.eq('id', id)
.single();  // ❌ Will crash if vehicle deleted
// FIX: Use .maybeSingle() with null check
```

**local_notification_service.dart (2 issues)**
```dart
// LINE 686, 931 - Passenger type lookup
.eq('id', putnikId)
.single();  // ❌ Crashes if passenger doesn't exist
// CONTEXT: Notification routing
// FIX: Add error handling, use maybeSingle()
```

---

## CRITICAL FIX #2: Missing `.limit()` on Unbounded Queries

### voznje_log_service.dart
```dart
// LINE 35 - Get rides for date (NO LIMIT!)
final rides = await _supabase.from('voznje_log')
  .select('tip, iznos')
  .eq('vozac_id', vozacUuid)
  .eq('datum', datumStr);  // Could return 100+ rows
// FIX: Add .limit(100) before select

// LINE 187 - SAME ISSUE
// FIX: Add .limit(100)

// LINE 216 - Filter by list (NO LIMIT!)
.select('id, tip')
.inFilter('id', potencijalniDuznici);  // Could return 500+ rows
// FIX: Add .limit(500)
```

### registrovani_putnik_service.dart
```dart
// LINE 188 - Get all non-deleted passengers (NO LIMIT!)
await _supabase.from('registrovani_putnici')
  .select()
  .eq('obrisan', false)
  .eq('is_duplicate', false);  // Returns ALL passengers
// FIX: Add .limit(1000) or implement pagination
```

---

## CRITICAL FIX #3: N+1 Query Pattern

### voznje_log_service.dart (lines 215-220)
```dart
// CURRENT (BAD) - Makes 1+N queries
final vozaci = await _supabase.from('registrovani_putnici')
  .select('id, tip')
  .inFilter('id', potencijalniDuznici);

for (var vozac in vozaci) {
  // This query runs for EACH vozac (N queries!)
  final rides = await _supabase.from('voznje_log')
    .select('iznos')
    .eq('putnik_id', vozac['id']);
}

// FIXED (GOOD) - Makes 2 queries
final vozaci = await _supabase.from('registrovani_putnici')
  .select('id, tip')
  .inFilter('id', potencijalniDuznici)
  .limit(500);

// Get all rides for ALL vozaci in one query
final rides = await _supabase.from('voznje_log')
  .select('putnik_id, iznos')
  .inFilter('putnik_id', vozaci.map((v) => v['id']).toList());

// Now join in memory
Map<String, List> ridesByPutnik = {};
for (var ride in rides) {
  ridesByPutnik.putIfAbsent(ride['putnik_id'], () => []).add(ride);
}
```

---

## CRITICAL FIX #4: Race Condition - Schedule Updates

### registrovani_putnik_service.dart (lines 357-370)

**Current (UNSAFE)**:
```dart
// Step 1: Get current schedule
final scheduleData = await _supabase.from('registrovani_putnici')
  .select('polasci_po_danu')
  .eq('id', id)
  .single();

// Step 2-3: Modify in memory (RACE CONDITION HERE!)
List<dynamic> polasci = jsonDecode(scheduleData['polasci_po_danu']);
polasci.add(noviPolazak);

// Step 4: Write back (IF ANOTHER USER EDITED BETWEEN STEPS 1-4, DATA LOSS!)
await _supabase.from('registrovani_putnici')
  .update({'polasci_po_danu': jsonEncode(polasci)})
  .eq('id', id);
```

**Solution**: Create Supabase RPC Function

```sql
-- In Supabase: SQL Editor
CREATE OR REPLACE FUNCTION add_polazak(
  putnik_id UUID,
  novi_polazak JSONB
)
RETURNS JSONB AS $$
DECLARE
  current_schedule JSONB;
  new_schedule JSONB;
BEGIN
  -- Get with row lock
  SELECT polasci_po_danu INTO current_schedule
  FROM registrovani_putnici
  WHERE id = putnik_id
  FOR UPDATE;
  
  IF current_schedule IS NULL THEN
    RAISE EXCEPTION 'Passenger not found';
  END IF;
  
  -- Add new polazak
  new_schedule := current_schedule || jsonb_build_array(novi_polazak);
  
  -- Update atomically
  UPDATE registrovani_putnici
  SET polasci_po_danu = new_schedule
  WHERE id = putnik_id;
  
  RETURN new_schedule;
END;
$$ LANGUAGE plpgsql;
```

**Then in Dart**:
```dart
final response = await _supabase.rpc('add_polazak', params: {
  'putnik_id': id,
  'novi_polazak': noviPolazak,
});
```

---

## CRITICAL FIX #5: Transaction - PIN Request Approval

### pin_zahtev_service.dart (lines 105-115)

**Current (UNSAFE)**:
```dart
// If step 3 fails, passenger has PIN but request not marked as approved!
final zahtev = await _supabase.from('pin_zahtevi')
  .select('putnik_id')
  .eq('id', zahtevId)
  .single();

await _supabase.from('registrovani_putnici')
  .update({'pin': pin})
  .eq('id', putnikId);

// ❌ If this fails, inconsistent state!
await _supabase.from('pin_zahtevi')
  .update({'status': 'odobren'})
  .eq('id', zahtevId);
```

**Solution**: Create Supabase RPC
```sql
CREATE OR REPLACE FUNCTION approve_pin_request(
  zahtev_id UUID,
  pin_code TEXT
)
RETURNS VOID AS $$
BEGIN
  -- Get request + lock it
  UPDATE pin_zahtevi
  SET status = 'odobren'
  WHERE id = zahtev_id
  RETURNING putnik_id INTO putnik_id;
  
  -- Update passenger with new PIN
  UPDATE registrovani_putnici
  SET pin = pin_code
  WHERE id = (SELECT putnik_id FROM pin_zahtevi WHERE id = zahtev_id);
  
  -- Both succeed or both fail (transaction)
END;
$$ LANGUAGE plpgsql;
```

---

## PERFORMANCE FIX #1: Missing Indexes

**Add These to Supabase SQL Editor**:
```sql
-- Ride lookups by passenger
CREATE INDEX idx_voznje_log_putnik_id 
ON voznje_log(putnik_id);

-- Ride lookups by passenger and date
CREATE INDEX idx_voznje_log_putnik_datum 
ON voznje_log(putnik_id, datum DESC);

-- Passenger name lookups
CREATE INDEX idx_putnici_ime 
ON registrovani_putnici(putnik_ime);

-- Active passenger lookups
CREATE INDEX idx_putnici_obrisan 
ON registrovani_putnici(obrisan);

-- Driver location lookups
CREATE INDEX idx_vozac_lokacije_vozac 
ON vozac_lokacije(vozac_id);

-- Push token lookups
CREATE INDEX idx_push_tokens_user_id 
ON push_tokens(user_id);

-- Schedule lookups
CREATE INDEX idx_putnici_id 
ON registrovani_putnici(id);

-- Ride date lookups
CREATE INDEX idx_voznje_log_datum 
ON voznje_log(datum);
```

---

## SAFETY IMPROVEMENTS

### Auto-Safe Patterns to Implement

**Pattern 1: Safe Single with Validation**
```dart
Future<T?> safeSingle<T>(PostgrestFilterBuilder<PostgrestList> query) async {
  try {
    final result = await query.maybeSingle();
    return result;
  } catch (e) {
    debugPrint('🔴 [safeSingle] Query error: $e');
    return null;
  }
}

// Usage
final vozilo = await safeSingle(
  _supabase.from('vozila').select().eq('id', id)
);
if (vozilo == null) return;
```

**Pattern 2: Safe Update with Rollback**
```dart
Future<bool> safeUpdate(
  String table,
  Map<String, dynamic> updates,
  String filterColumn,
  dynamic filterValue,
) async {
  try {
    final response = await _supabase
      .from(table)
      .update(updates)
      .eq(filterColumn, filterValue);
    return true;
  } catch (e) {
    debugPrint('🔴 [safeUpdate] Update failed: $e');
    return false;
  }
}

// Usage
final success = await safeUpdate(
  'registrovani_putnici',
  {'pin': newPin},
  'id',
  putnikId,
);
if (!success) return;
```

**Pattern 3: Batch Query**
```dart
Future<List<T>> batchQueries<T>(
  List<Future<List<T>>> queries,
) async {
  try {
    final results = await Future.wait(queries);
    return results.expand((list) => list).toList();
  } catch (e) {
    debugPrint('🔴 [batchQueries] Batch failed: $e');
    return [];
  }
}

// Usage
final results = await batchQueries([
  _supabase.from('registrovani_putnici').select(),
  _supabase.from('vozaci').select(),
  _supabase.from('vozila').select(),
]);
```

---

## TESTING VERIFICATION

### After Each Fix, Run:
```bash
# 1. Analyze
flutter analyze --no-fatal-infos

# 2. Build
flutter build apk --debug

# 3. Install
flutter install --debug

# 4. Test Specific Screen
# Navigate to registrovani_putnici_screen
# Verify: No crashes, smooth loading
```

### Manual Testing Checklist:
- [ ] Add passenger with duplicate name (should not crash)
- [ ] Delete passenger, try to edit their schedule (should handle gracefully)
- [ ] Edit same schedule from 2 devices simultaneously (no data loss)
- [ ] Approve PIN request for non-existent passenger (should handle)
- [ ] Load registrovani_putnici screen (measure load time)
- [ ] Check device logs: `adb logcat | grep -i "gavra\|error"`

---

## Estimated Implementation Time

| Fix | Effort | Priority |
|-----|--------|----------|
| Add `.limit()` to 5 queries | 15 min | 🔴 CRITICAL |
| Replace `.single()` with `.maybeSingle()` | 20 min | 🔴 CRITICAL |
| Create `add_polazak` RPC | 30 min | 🔴 CRITICAL |
| Create `approve_pin_request` RPC | 20 min | 🔴 CRITICAL |
| Fix N+1 voznje_log queries | 30 min | 🔴 CRITICAL |
| Add missing indexes | 10 min | 🟡 HIGH |
| Verify all fixes | 30 min | ✅ DONE |

**Total**: ~2.5 hours for all critical fixes

---

**Reference**: SUPABASE_AUDIT_2026-01-28.md
