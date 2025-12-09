# 📊 Izveštaj: Logika za mesečne putnike tip "RADNIK"

**Datum analize:** 9. decembar 2025.  
**Analizirani fajlovi:**
- `lib/models/mesecni_putnik.dart`
- `lib/services/mesecni_putnik_service.dart`
- `lib/services/improved_mesecni_putnik_service.dart`
- `lib/services/cena_obracun_service.dart`
- `lib/screens/mesecni_putnici_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/mesecni_putnik_dialog.dart`
- `lib/utils/mesecni_filter_fix.dart`

---

## 1. 📦 Model (`mesecni_putnik.dart`)

### Polje `tip`
- **Tip podatka:** `String`
- **Validne vrednosti:** `'radnik'`, `'ucenik'`, `'dnevni'`
- **Default vrednost:** `'radnik'` (pri parsiranju iz baze, linija 78)

### Getteri za proveru tipa
```dart
bool get isRadnik => tip == 'radnik';  // linija 517
bool get isUcenik => tip == 'ucenik';  // linija 514
```

### ⚠️ PROBLEM U VALIDACIJI (linija 428)
```dart
if (tip.isEmpty || !['radnik', 'ucenik'].contains(tip)) {
  errors['tip'] = 'Tip mora biti "radnik" ili "ucenik"';
}
```
**Problem:** Tip `'dnevni'` nije uključen u validaciju! Ovo može blokirati čuvanje dnevnih putnika.

---

## 2. 💰 Cene (`cena_obracun_service.dart`)

### Default cene po danu
| Tip putnika | Cena po danu |
|-------------|--------------|
| **Radnik**  | 700 RSD      |
| **Učenik**  | 600 RSD      |
| **Dnevni**  | 0 RSD (mora imati custom cenu) |

### Logika obračuna
```dart
static double getCenaPoDanu(MesecniPutnik putnik) {
  // Ako ima custom cenu, koristi je
  if (putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0) {
    return putnik.cenaPoDanu!;
  }
  // Inače koristi default na osnovu tipa
  return _getDefaultCenaPoDanu(putnik.tip);
}
```

### Obračun mesečne cene
- Formula: `broj_dana_sa_pokupljenjima × cena_po_danu`
- Podaci se uzimaju iz tabele `putovanja_istorija`
- Broje se UNIKATNI dani (više pokupljenja u istom danu = 1 dan)

---

## 3. 🔍 Filtriranje

### `mesecni_putnici_screen.dart`
- Filter varijabla: `_selectedFilter` (vrednosti: `'svi'`, `'radnik'`, `'ucenik'`, `'dnevni'`)
- Logika filtriranja:
```dart
if (filterType != 'svi') {
  filtered = filtered.where((p) => p.tip == filterType).toList();
}
```

### Brojanje radnika (za statistiku)
```dart
putnici.where((p) => 
  p.tip == 'radnik' && 
  p.aktivan && 
  !p.obrisan && 
  p.status != 'bolovanje' && 
  p.status != 'godišnje'
).length
```

### `mesecni_filter_fix.dart`
- Centralizovana logika filtriranja
- Provera tipa: `if (tip != filterType) return false;`

---

## 4. 🎨 UI Prikaz

### Boje i ikone po tipu
| Tip      | Boja                  | Ikona              |
|----------|-----------------------|--------------------|
| Radnik   | Plava (`blue.shade600`) | `Icons.engineering` |
| Učenik   | Zelena (`green.shade600`) | `Icons.school`    |
| Dnevni   | Narandžasta (`orange.shade600`) | `Icons.today` |

### Lokacije u kodu
- `home_screen.dart`: linije 776-892
- `mesecni_putnici_screen.dart`: linije 988-1004

---

## 5. ➕ Dodavanje/Uređivanje (`mesecni_putnik_dialog.dart`)

### Dropdown za tip
```dart
_buildDropdown(
  value: _tip,
  label: 'Tip putnika',
  icon: Icons.category,
  items: const ['radnik', 'ucenik', 'dnevni'],
  onChanged: (value) => setState(() => _tip = value ?? 'radnik'),
)
```

### Inicijalna vrednost
- Default: `String _tip = 'radnik';` (linija 57)

### Cena po danu (opciono polje)
- Prikazuje se za sve tipove
- Tekst pomoći: "Radnik: 700 RSD po danu, Učenik: 600 RSD po danu, Dnevni: po dogovoru"

---

## 6. 📊 Statistike (`improved_mesecni_putnik_service.dart`)

```dart
if (tip == 'radnik') {
  stats['radnici'] = (stats['radnici'] ?? 0) + 1;
}
```

---

## 7. ⚠️ Pronađeni problemi

### Problem 1: Validacija ne uključuje 'dnevni'
**Lokacija:** `lib/models/mesecni_putnik.dart`, linija 428  
**Opis:** Metoda `validateFull()` ne prepoznaje `'dnevni'` kao validan tip  
**Uticaj:** Validacija može da blokira čuvanje dnevnih putnika  
**Preporučena ispravka:**
```dart
if (tip.isEmpty || !['radnik', 'ucenik', 'dnevni'].contains(tip)) {
  errors['tip'] = 'Tip mora biti "radnik", "ucenik" ili "dnevni"';
}
```

### Problem 2: Cena za dnevne putnike je 0
**Lokacija:** `lib/services/cena_obracun_service.dart`, linija 18  
**Opis:** Default cena za dnevne je 0, što zahteva obaveznu custom cenu  
**Status:** Ovo je namerno ponašanje (po dogovoru), ali može izazvati probleme ako korisnik zaboravi da postavi cenu

---

## 8. ✅ Šta radi ispravno

1. ✅ Filtriranje po tipu "radnik" funkcioniše korektno
2. ✅ Cena od 700 RSD po danu se pravilno primenjuje
3. ✅ UI prikazuje ispravne boje i ikone za radnike
4. ✅ Statistike ispravno broje radnike
5. ✅ Dropdown u dialogu omogućava izbor sva tri tipa
6. ✅ Stream za realtime update radi sa filterom po tipu
7. ✅ Custom cena ima prioritet nad default cenom

---

## 9. 📋 Preporuke za dalje akcije

1. **[KRITIČNO]** Ispraviti validaciju da uključi `'dnevni'` tip
2. **[OPCIONO]** Dodati upozorenje ako dnevni putnik nema postavljenu custom cenu
3. **[OPCIONO]** Razmotriti dodavanje validacije da dnevni putnici moraju imati `cenaPoDanu > 0`

---

*Izveštaj generisan automatski od strane analize koda.*
