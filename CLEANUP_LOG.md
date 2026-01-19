# Cleanup Log - Stara Pending Logika

**Datum:** 19. Januar 2026

## Obrisano iz Supabase baze

### 1. Database Trigger (Glavni problem!)
```sql
DROP TRIGGER IF EXISTS trigger_process_pending ON registrovani_putnici CASCADE;
```
**Razlog:** Ovaj trigger se aktivirao na INSERT/UPDATE u `registrovani_putnici` tabeli i **INSTANT** procesirao pending zahteve bez čekanja. Ovo je bio glavni uzrok instant konfirmacija umesto dokumentovanih 5-10 minuta čekanja.

### 2. Trigger Function
```sql
DROP FUNCTION IF EXISTS process_pending_request() CASCADE;
```
**Razlog:** Funkcija koju je pozivao trigger. Radila je instant proveru kapaciteta i setovala status na `confirmed` bez čekanja.

### 3. Stara Autonomous Function
```sql
DROP FUNCTION IF EXISTS resolve_autonomous_pending_requests() CASCADE;
```
**Razlog:** Stara verzija pending resolver funkcije sa nepotpunom logikom:
- Samo 5 min za ne-dnevni, 10 min za dnevni (ne razlikuje učenik/radnik)
- Koristi zastarelu `get_occupied_seats()` umesto `count_bc_seats()`/`count_vs_seats()`
- Nema BC LOGIKA.md pravila za učenike (prvi vs drugi zahtev, rush hour)

### 4. Helper Functions (zastarele)
```sql
DROP FUNCTION IF EXISTS check_bc_kapacitet(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS check_vs_kapacitet(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_occupied_seats(TEXT, TEXT, TEXT) CASCADE;
```
**Razlog:** Bile su vezane za `process_pending_request()` i nisu se koristile nigde drugde.

## Obrisano iz Dart koda

### 1. Client-side Pending Resolution Function
**Fajl:** `lib/screens/registrovani_putnik_profil_screen.dart`

**Uklonjeno:**
- `_checkAndResolvePendingRequests()` funkcija (~154 linije koda)
- Poziv funkcije u `initState()` metodi

**Razlog:** Client-side pending resolution se pokretao pri svakom otvaranju profila i davao lažni utisak instant konfirmacije kada korisnik refresh-uje profil. Stvarao je konfuziju i nije bio sinhronizovan sa dokumentacijom (BC LOGIKA.md i VS LOGIKA.md).

## Šta je OSTALO (validna logika)

### ✅ Client-side (Dart)
- **Postavljanje pending statusa** - Kada korisnik zakaže, app postavlja `bc_status='pending'` i `bc_ceka_od=NOW()`
- **Timestamp tracking** - `bc_ceka_od` i `vs_ceka_od` se koriste za FIFO sortiranje na waiting listi
- **UI feedback** - SnackBar poruke "Vaš zahtev je primljen i trenutno je u obradi"

### ✅ Server-side (Supabase)
- **`resolve_pending_requests()`** - Glavna funkcija koja implementira BC LOGIKA.md i VS LOGIKA.md
  - Učenik: 5-10 minuta (zavisi od timing i dana)
  - Radnik: 5 minuta
  - Dnevni: 10 minuta
  - VS: 10 minuta za sve (rush hour waiting list)
  
- **`cleanup_expired_pending()`** - 15-minutni timeout za zaglavljene zahteve

- **`count_bc_seats()` / `count_vs_seats()`** - Precizno brojanje samo confirmed putnika (ne računa pending/waiting)

### ✅ Cron Jobs
- **Job #7** `resolve-pending-main` - Svaki minut (`* * * * *`)
- **Job #5** `resolve-pending-20h-ucenici` - Dnevno u 20:00 (`0 20 * * *`)
- **Job #6** `cleanup-expired-pending` - Svakih 5 minuta (`*/5 * * * *`)
- **Job #3** `send-pending-notifications` - Svaki minut
- **Job #1** `process-seat-requests` - Svakih 10 minuta

## Rezultat

**Pre čišćenja:** Korisnici dobijali instant potvrdu zbog:
1. Database trigger `trigger_process_pending` (instant processing)
2. Client-side `_checkAndResolvePendingRequests()` pri otvaranju profila
3. Konfliktne funkcije sa nekonzistentnom logikom

**Posle čišćenja:** Korisnici čekaju **tačno** prema specifikaciji:
- **UČENIK** BC: 5-10 minuta (prvi zahtev instant, ostali do 20:00h)
- **RADNIK** BC: 5 minuta
- **DNEVNI** BC: 10 minuta
- **VS (svi tipovi)**: 10 minuta

## Test Plan

1. **Test AI Radnik:** Zakaži BC polazak → Očekivano: 5 minuta čekanje
2. **Test Učenik:** Prvi zahtev za sutra do 16h → Očekivano: 5-10 minuta
3. **Test Učenik:** Promena termina posle 16h → Očekivano: Obrada u 20:00h
4. **Test Dnevni:** Zakaži za danas → Očekivano: 10 minuta čekanje
5. **Test VS:** Bilo ko zakaži Vršac → Očekivano: 10 minuta čekanje

---

**Commit:** 46cb0d2e - "Removed old client-side pending resolution logic"
**Database cleanup:** Manual SQL execution via Supabase
