# Status Testiranja Funkcionalnosti

## Datum: 13. Decembar 2025

---

## ✅ RADI ISPRAVNO

### Danas Screen
- [x] **Dugme "Ruta"** - radi savršeno ispravno
  - DOKAZ: "Lista Reorderovana (1/10)" - prikazuje se nakon klika
  - DOKAZ: "Optimizovana ruta: 10 putnika" - potvrda optimizacije
  - DOKAZ: "SLEDEĆI: Nesa Carea" - prvi putnik na optimizovanoj listi
  - **LOGIKA**: 11 waypointa, 10 putnika - ISPRAVNO
    - Zadnji waypoint = suprotan grad od polaska (ne računa se kao putnik)
    - Ovo je za bolju optimizaciju rute
- [x] **Dugme "NAV"** - radi ispravno
  - Klik otvara popup "Navigacija"
  - Popup preuzima redosled putnika od dugmeta "Ruta" (optimizovani redosled)
  - **Opcije u popup-u**:
    - "Sledeći putnik" - Nesa Carea - Mihajla Pupina 62
    - "Svi putnici (10)" - Prvih 10 kao waypoints, ostali posle
  - ✅ **ISPRAVLJENO**: Sada prikazuje "Svi putnici (10)" umesto "(11)"
  - **FAJL**: `danas_screen.dart` i `vozac_screen.dart`
  - **FIX**: Koristi isti filter kao "Lista Reorderovana" - broji samo aktivne nepokupljene putnike
- [x] **BC/VS termini** - prikaz vremena sa brojem putnika/slobodnih mesta radi ispravno
  - PRIMER: BC 6:00 selektovano - prikazuje 10 putnika od 14 slobodnih mesta (10/14)

---

## ❌ NE RADI / PROBLEMI

(prazno za sada)

---

## ⚠️ DELIMIČNO RADI

(prazno za sada)

---

## 📝 NAPOMENE

(dodaj napomene ovde)
