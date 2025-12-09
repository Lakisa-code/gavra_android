# 📊 Izveštaj: Logika za mesečne putnike tip "UČENIK"

**Datum analize:** 9. decembar 2025.  
**Analizirani fajlovi:**
- `lib/models/mesecni_putnik.dart`
- `lib/services/mesecni_putnik_service.dart`
- `lib/services/cena_obracun_service.dart`
- `lib/screens/mesecni_putnici_screen.dart`
- `lib/screens/mesecni_putnik_profil_screen.dart`
- `lib/widgets/mesecni_putnik_dialog.dart`
- `lib/widgets/putnik_card.dart`
- `lib/utils/mesecni_filter_fix.dart`

---

## 1. 📦 Model (`mesecni_putnik.dart`)

### Polje `tip`
- **Tip podatka:** `String`
- **Vrednost za učenike:** `'ucenik'`

### Specifična polja za učenike
| Polje | Tip | Opis |
|-------|-----|------|
| `tipSkole` | `String?` | Naziv škole/ustanove koju učenik pohađa |
| `brojTelefonaOca` | `String?` | Kontakt telefon oca |
| `brojTelefonaMajke` | `String?` | Kontakt telefon majke |

### Getter za proveru tipa
```dart
bool get isUcenik => tip == 'ucenik';  // linija 514
```

### Validacija za učenike (linija 432-434)
```dart
if (tip == 'ucenik' && (tipSkole == null || tipSkole!.isEmpty)) {
  errors['tipSkole'] = 'Tip škole je obavezan za učenike';
}
```
✅ **Ispravno:** Škola je obavezna samo za učenike

---

## 2. 💰 Cene (`cena_obracun_service.dart`)

### Default cena za učenike
| Tip putnika | Cena po danu |
|-------------|--------------|
| **Učenik**  | 600 RSD      |

### Konstanta
```dart
static const double defaultCenaUcenikPoDanu = 600.0;  // linija 17
```

### Logika određivanja cene
```dart
case 'ucenik':
case 'učenik':  // Podržava i ćirilicu
  return defaultCenaUcenikPoDanu;  // linija 34-35
```

### Korišćenje u profilu (`mesecni_putnik_profil_screen.dart`)
```dart
final cenaPoVoznji = tip == 'ucenik' ? 600.0 : 700.0;  // linije 221, 977
```

---

## 3. 🔍 Filtriranje

### `mesecni_putnici_screen.dart`
- Filter vrednost: `'ucenik'`
- Brojanje učenika:
```dart
putnici.where((p) => 
  p.tip == 'ucenik' && 
  p.aktivan && 
  !p.obrisan && 
  p.status != 'bolovanje' && 
  p.status != 'godišnje'
).length
```

### Pretraga uključuje tipSkole
```dart
p.putnikIme.toLowerCase().contains(searchLower) ||
p.tip.toLowerCase().contains(searchLower) ||
(p.tipSkole?.toLowerCase().contains(searchLower) ?? false)  // linija 383
```

---

## 4. 🎨 UI Prikaz

### Boje i ikone
| Element | Vrednost |
|---------|----------|
| Boja    | Zelena (`green.shade600`) |
| Ikona   | `Icons.school` |

### Prikaz u listi (`mesecni_putnici_screen.dart`)
- Prikazuje se ikona škole i naziv škole (tipSkole)
- Roditeljski kontakti prikazuju se sa ikonama:
  - Otac: `Icons.man` (plava)
  - Majka: `Icons.woman` (roze)

### Broj kontakata
```dart
// Ikone za dostupne kontakte
if (putnik.brojTelefona != null) Icon(Icons.person, ...),
if (putnik.brojTelefonaOca != null) Icon(Icons.man, ...),
if (putnik.brojTelefonaMajke != null) Icon(Icons.woman, ...),
```

---

## 5. ➕ Dodavanje/Uređivanje (`mesecni_putnik_dialog.dart`)

### Kondicionalni prikaz polja za učenike
Kada je `_tip == 'ucenik'`, prikazuju se dodatna polja:

1. **Škola** (obavezno polje)
```dart
if (_tip == 'ucenik') ...[
  const SizedBox(height: 24),
  _buildTextField(
    controller: _tipSkoleController,
    label: 'Škola',
    icon: Icons.school,
  ),
],
```

2. **Roditeljski kontakti** (sekcija)
```dart
if (_tip == 'ucenik') ...[
  // Container sa naslovom "Kontakt podaci roditelja"
  _buildTextField(
    controller: _brojTelefonaOcaController,
    label: 'Broj telefona oca',
    icon: Icons.man,
  ),
  _buildTextField(
    controller: _brojTelefonaMajkeController,
    label: 'Broj telefona majke',
    icon: Icons.woman,
  ),
],
```

3. **Label za telefon učenika**
```dart
label: _tip == 'ucenik' ? 'Broj telefona učenika' : 'Broj telefona',
```

### Cena po danu sekcija
- Prikazuje informaciju: "Učenik: 600 RSD po danu"
- Opciono polje za custom cenu

---

## 6. 📱 SMS Funkcionalnost za učenike (`putnik_card.dart`)

### Automatski SMS roditeljima za plaćanje
Ova funkcionalnost je **ekskluzivna za učenike**:

```dart
// Automatsko SMS roditeljima za plaćanje (samo za mesečne putnike učenike)
if (_putnik.mesecnaKarta == true &&
    mesecniPutnik != null &&
    mesecniPutnik.tip == 'ucenik' &&
    ((mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) ||
        (mesecniPutnik.brojTelefonaMajke != null && mesecniPutnik.brojTelefonaMajke!.isNotEmpty))) {
  // Prikaži opciju "💰 SMS Roditeljima - Plaćanje"
}
```

### Opcije kontakta za učenike
1. **SMS Roditeljima - Plaćanje** (automatska poruka)
2. **Pozovi oca** / **SMS otac**
3. **Pozovi majku** / **SMS majka**
4. **Pozovi putnika** / **SMS putnik** (glavni broj)

### Format SMS poruke za plaćanje
```
🚌 GAVRA PREVOZ 🚌

Podsetnik za plaćanje mesečne karte:

👤 Putnik: [Ime učenika]
📅 Mesec: [Mesec] [Godina]
💰 Iznos: [Iznos] RSD ([Broj dana] dana x [Cena] RSD)

📞 Kontakt: Bojan - Gavra 013

Hvala na razumevanju! 🚌
---
Automatska poruka.
```

---

## 7. 📊 Statistike

### `improved_mesecni_putnik_service.dart`
```dart
} else if (tip == 'ucenik') {
  stats['ucenici'] = (stats['ucenici'] ?? 0) + 1;
}
```

### Cache za brzi pristup
```dart
int _cachedBrojUcenika = 0;  // mesecni_putnici_screen.dart
```

---

## 8. ✅ Šta radi ispravno

1. ✅ Filtriranje po tipu "ucenik" funkcioniše korektno
2. ✅ Cena od 600 RSD po danu se pravilno primenjuje
3. ✅ UI prikazuje zelenu boju i ikonu škole
4. ✅ Škola je obavezno polje samo za učenike
5. ✅ Roditeljski kontakti se prikazuju samo za učenike
6. ✅ SMS roditeljima za plaćanje radi samo za učenike
7. ✅ Pretraga uključuje i naziv škole
8. ✅ Statistike ispravno broje učenike
9. ✅ Custom cena ima prioritet nad default cenom od 600 RSD

---

## 9. ⚠️ Potencijalni problemi

### Problem 1: Roditeljski kontakti se čuvaju i za radnike
**Opis:** Polja `brojTelefonaOca` i `brojTelefonaMajke` postoje u modelu za sve tipove, ali se u UI prikazuju samo za učenike. Ako se tip promeni sa "ucenik" na "radnik", podaci roditelja ostaju u bazi.  
**Status:** Nije kritično - podaci se ignorišu u UI za radnike  
**Preporuka:** Razmotriti čišćenje roditeljskih kontakata pri promeni tipa

### Problem 2: Cena hardkodirana na dva mesta
**Lokacije:**
1. `cena_obracun_service.dart` - `defaultCenaUcenikPoDanu = 600.0`
2. `mesecni_putnik_profil_screen.dart` - `cenaPoVoznji = tip == 'ucenik' ? 600.0 : 700.0`

**Preporuka:** Koristiti samo `CenaObracunService.getCenaPoDanu()` za konzistentnost

### Problem 3: Validacija ne uključuje 'dnevni' tip
**Lokacija:** `lib/models/mesecni_putnik.dart`, linija 428  
**Napomena:** Ovo je isti problem kao u izveštaju za radnike

---

## 10. 📋 Razlike između učenika i radnika

| Aspekt | Učenik | Radnik |
|--------|--------|--------|
| Cena po danu | 600 RSD | 700 RSD |
| Boja | Zelena | Plava |
| Ikona | `Icons.school` | `Icons.engineering` |
| Škola/Ustanova | Obavezno | Ne koristi se |
| Kontakt roditelja | Da (otac, majka) | Ne |
| SMS roditeljima | Da | Ne |
| Label telefona | "Broj telefona učenika" | "Broj telefona" |

---

## 11. 📋 Preporuke za dalje akcije

1. **[OPCIONO]** Centralizovati cene - koristiti samo `CenaObracunService`
2. **[OPCIONO]** Dodati validaciju da učenici moraju imati bar jedan roditeljski kontakt
3. **[OPCIONO]** Čistiti roditeljske kontakte pri promeni tipa sa učenik na radnik/dnevni
4. **[INFO]** SMS funkcionalnost za roditelje radi samo za učenike - namerno ponašanje

---

*Izveštaj generisan automatski od strane analize koda.*
