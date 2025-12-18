# 🚀 PLAN OPTIMIZACIJE REALTIME SISTEMA

**Datum**: 18.12.2025  
**Status**: U TOKU

---

## 📊 TRENUTNO STANJE

### Problemi:
1. **9+ nezavisnih WebSocket konekcija** na tabelu `registrovani_putnici`
2. Stream-ovi bez server-side filtera (svi podaci se učitavaju pa filtriraju lokalno)
3. Redundantni stream koji ništa ne radi (`home_screen.dart` linija 516)
4. Nepotreban realtime za statistike (može biti on-demand)

### Pogođeni fajlovi:
- `lib/services/registrovani_putnik_service.dart` (3 stream-a)
- `lib/services/statistika_service.dart` (3 stream-a)
- `lib/services/putnik_service.dart` (2 stream-a)
- `lib/screens/home_screen.dart` (1 stream)

---

## ✅ PLAN IMPLEMENTACIJE

### FAZA 1: Kreiranje centralnog stream servisa
- [ ] Kreirati `lib/services/realtime_hub_service.dart`
- [ ] Singleton pattern sa jednim stream-om za `registrovani_putnici`
- [ ] Broadcast stream koji svi mogu da slušaju

### FAZA 2: Migracija postojećih servisa
- [ ] `registrovani_putnik_service.dart` - koristiti centralni stream
- [ ] `statistika_service.dart` - prebaciti na on-demand fetch
- [ ] `putnik_service.dart` - koristiti centralni stream

### FAZA 3: Čišćenje nepotrebnog koda
- [ ] Obrisati prazan stream listener u `home_screen.dart` (linija 516)
- [ ] Ukloniti duplikate stream pretplata

### FAZA 4: Dodavanje server-side filtera
- [ ] Gde je moguće, koristiti `.eq()` filtre na stream-u

---

## 📈 OČEKIVANI REZULTATI

| Metrika | Pre | Posle |
|---------|-----|-------|
| WebSocket konekcije na `registrovani_putnici` | 9+ | 1 |
| Količina podataka po refreshu | 9x sve | 1x sve |
| Realtime potrošnja | 100% | ~30% |

---

## ⚠️ NAPOMENE

- Ne menjati logiku aplikacije, samo optimizovati stream-ove
- Testirati svaki korak pre nastavka
- Backup pre većih promena
