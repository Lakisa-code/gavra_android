# 🚀 PLAN OPTIMIZACIJE REALTIME SISTEMA

**Datum**: 18.12.2025  
**Status**: U TOKU

---

## 📊 TRENUTNO STANJE

### Problemi:
1. **9+ nezavisnih `.stream()` poziva** na tabelu `registrovani_putnici`
2. `.stream()` šalje SVE podatke pri svakoj promeni (veliki bandwidth)
3. Redundantni stream koji ništa ne radi (`home_screen.dart` linija 516)

### Pogođeni fajlovi:
- `lib/services/registrovani_putnik_service.dart` (3 stream-a)
- `lib/services/statistika_service.dart` (3 stream-a)
- `lib/services/putnik_service.dart` (2 stream-a)
- `lib/screens/home_screen.dart` (1 stream)

---

## ✅ REŠENJE: Supabase Realtime Channels

Umesto `.stream()` koristimo `channel().onPostgresChanges()`:

| `.stream()` (staro) | `onPostgresChanges()` (novo) |
|---------------------|------------------------------|
| Šalje SVE podatke | Šalje SAMO promenu (delta) |
| Veći bandwidth | Minimalan bandwidth |
| Više poruka = veća cena | Manje poruka = manja cena |

---

## ✅ PLAN IMPLEMENTACIJE

### FAZA 1: Kreiranje centralnog hub servisa ✅
- [x] Kreirati `lib/services/realtime_hub_service.dart`
- [x] Koristi `channel().onPostgresChanges()` umesto `.stream()`
- [x] Učitaj inicijalne podatke jednom, pa samo delta updates

### FAZA 2: Migracija postojećih servisa ✅
- [x] `registrovani_putnik_service.dart` - koristiti centralni hub
- [x] `statistika_service.dart` - koristiti centralni hub
- [x] `putnik_service.dart` - koristiti centralni hub

### FAZA 3: Čišćenje nepotrebnog koda ✅
- [x] Zamenjen stream listener u `home_screen.dart` sa hub-om

### FAZA 4: Inicijalizacija hub-a ✅
- [x] Dodato `RealtimeHubService.instance.initialize()` u main.dart

---

## 📈 OČEKIVANI REZULTATI

| Metrika | Pre | Posle |
|---------|-----|-------|
| Tip realtime-a | `.stream()` (svi podaci) | `onPostgresChanges()` (delta) |
| WebSocket konekcije | 9+ | 1 |
| Podaci po promeni | Svi redovi | Samo promenjeni red |
| Bandwidth | ~100% | ~5-10% |
