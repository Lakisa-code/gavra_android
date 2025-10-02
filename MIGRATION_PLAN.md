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
**162 greške** nakon prvog koraka migracije!

### GLAVNI PROBLEMI:
1. **Model incompatibilnost** - novi model nema iste properties kao stari:
   - `putnikIme` → `ime` + `prezime`
   - `adresaBelaCrkva`/`adresaVrsac` → `adresaId` 
   - `status`, `cena`, `radniDani` - nedostaju u novom modelu
   - `getPolazakBelaCrkvaZaDan()` - metoda ne postoji

2. **Kreiranje novih putnika** - constructor ima različite required parametre

### SLEDEĆI KORACI:
**OPCIJA 1:** Dodati nedostajuće properties u novi model
**OPCIJA 2:** Kompletan refaktoring UI-ja za novi model
**OPCIJA 3:** Zadržati stari model i dodati samo UUID adrese

---
**Datum kreiranja:** October 2, 2025
**Status:** ✅ U TOKU - ZNAČAJAN NAPREDAK!
- **SA 162 GREŠKE NA 34** - model migracija uspešna!
- Dodana sva legacy polja za kompatibilnost
- Preostale greške su uglavnom tip comparisons i method calls