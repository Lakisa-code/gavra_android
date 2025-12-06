# 🧪 DEBUG MODE AKTIVAN

**Datum:** 6. Decembar 2025.
**Verzija:** 6.0.1

## Aktivne debug opcije:

### 1. GPS Tracking Widget - UVEK PRIKAZAN
- Fajl: `lib/screens/mesecni_putnik_profil_screen.dart`
- Linija: `const bool debugAlwaysShowTracking = true;`
- Widget se prikazuje bez obzira na vreme i dan

### 2. Simulirani polazak
- BC putnici vide: `07:00`
- VS putnici vide: `14:00`

## ⚠️ PRE PRODUKCIJE:
1. Postaviti `debugAlwaysShowTracking = false`
2. Obrisati ovaj fajl

## Testiranje:
- Ulogovati se kao mesečni putnik
- Otvoriti profil
- Na vrhu treba da se vidi "Praćenje kombija" widget
- Ako vozač nije aktivan, piše "Vozač još nije krenuo"
