# PLAN MIGRACIJE NA NOVE TABELE

## 🎯 CILJ
Migracija sa starih modela na nove normalizovane tabele:
- `mesecni_putnici` sa UUID reference na `adrese` tabelu
- Odvojeni `ime` i `prezime` umesto `putnik_ime`
- Korišćenje `MesecniPutnikServiceNovi` umesto starog servisa

## 📋 FAZE MIGRACIJE

### FAZA 1: MODEL I SERVIS ✅
1. **Zameniti stari `MesecniPutnikService` sa `MesecniPutnikServiceNovi`**
   - Preusmeriti sve import-e
   - Ažurirati method signature-e

2. **Ažurirati `PutnikService`**
   - Prilagoditi mapiranje za novi model
   - Ispraviti query-je za nove kolone

### FAZA 2: UI KOMPONENTE
3. **Ažurirati `mesecni_putnici_screen.dart`**
   - Zameniti stari model sa novim
   - Prilagoditi forme za `ime`/`prezime` umesto `putnik_ime`
   - Implementirati logiku za adrese tabelu

4. **Ažurirati ostale screen-ove**
   - `danas_screen.dart`
   - Sve komponente koje koriste mesečne putnike

### FAZA 3: ADRESE LOGIKA
5. **Implementirati `AdreseService`**
   - CRUD operacije za `adrese` tabelu
   - Auto-complete funkcionalnost
   - Validacija adresa

6. **Integracija sa UI**
   - Dropdown/autocomplete za adrese
   - Kreiranje novih adresa "on-the-fly"

### FAZA 4: TESTIRANJE I FINALIZACIJA
7. **Testiranje**
   - Kreiranje mesečnih putnika
   - Učitavanje i prikaz
   - CRUD operacije

8. **Cleanup**
   - Obrisati stari `MesecniPutnikService`
   - Obrisati stari `mesecni_putnik.dart` model
   - Cleanup legacy kod

## 🔄 MAPIRANJE PROMENA

### STARO → NOVO
```dart
// STARO
'putnik_ime' → 'ime' + 'prezime'
'adresa_bela_crkva' → adresa_polaska_id (UUID)
'adresa_vrsac' → adresa_dolaska_id (UUID)

// NOVO
MesecniPutnik.fromMap() → koristi adresa_id reference
toMap() → koristi normalizovane kolone
```

## ⚠️ POTENCIJALNI PROBLEMI
1. **Postojeći podaci** - možda treba migracija podataka
2. **UI testiranje** - potrebno testirati sve forme
3. **Adrese kreiranje** - implementirati logiku za nove adrese

## 📅 PRIORITET IZVRŠAVANJA
1. Model i servis (HITNO)
2. Glavni screen (KRITIČNO)
3. Adrese logika (VAŽNO)
4. Ostali screen-ovi (NORMALNO)
5. Cleanup (NA KRAJU)

## 🚨 TRENUTNO STANJE
**0 grešaka** u screen fajlu! 🎉

### IZVRŠENI RADOVI:
1. **Model compatibility layer** ✅
   - Dodana sva legacy polja u novi model
   - Enhanced fromMap() i toMap() metode
   - Dodane legacy helper metode (getPolazakBelaCrkvaZaDan)
   - Popravljeno čuvanje adresa u bazi

2. **Service method fixes** ✅
   - Popravljen return tip za toggleAktivnost (void → bool)
   - Popravljen return tip za azurirajMesecnogPutnika (void → MesecniPutnik?)
   - Popravljen return tip za obrisiMesecniPutnik (void → bool)
   - Popravljen return tip za sinhronizujBrojPutovanjaSaIstorijom (void → bool)
   - Dodane missing legacy metode

3. **Screen fixes** ✅
   - Service replacement izvršen
   - Type comparison fixes (putnik.tip.value)
   - Popravljena struktura klase (uklonjene višak zagrade)
   - Uklonjen unused import
   - Uklonjena unused varijabla
   - Komentar za MesecniPutnikDetaljiScreen (treba novi model)

### TRENUTNI PROBLEMI:
1. **MesecniPutnikDetaljiScreen** - koristi stari model, treba migracija
2. **Testiranje** - potrebno testirati funkcionalnost aplikacije

### SLEDEĆI KORACI:
**PRIORITET 1:** Testirati aplikaciju sa novim modelom
**PRIORITET 2:** Migrirati MesecniPutnikDetaljiScreen na novi model
**PRIORITET 3:** Testirati ostale screen-ove

---
**Datum poslednjeg ažuriranja:** October 2, 2025
**Status:** ✅ ZAVRŠENA GLAVNA MIGRACIJA! (od 162 na 0 grešaka)
3. **Try/catch disconnection** - neki try blokovi su van metoda

### UZROK PROBLEMA:
Brisanje nepotrebne metode je verovatno uklonilo ključnu zatvorenu zagradu, što je dovelo do strukturalnog kvarenja klase.

### SLEDEĆI KORACI:
**PRIORITET 1:** Popraviti strukturalne probleme u screen fajlu
**PRIORITET 2:** Testirati funkcionalnost aplikacije
**PRIORITET 3:** Kompletirati ostatak migracije

---
**Datum kreiranja:** October 2, 2025
**Status:** ⚠️ U TOKU - STRUKTURALNI PROBLEM!
- **Napredak:** Model i service layer funkcionalni
- **Problem:** Screen fajl ima ozbiljan strukturalni kvar
- **Rešenje:** Potrebno je pažljivo vratiti strukturu klase