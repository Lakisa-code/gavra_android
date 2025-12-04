# 🎨 Color Cheat Sheet - Gavra Android

## Pregled

Ovaj dokument sadrži kompletnu dokumentaciju svih boja korišćenih u aplikaciji.

---

## 📇 Boje Kartica Putnika (CardColorHelper)

Centralizovana logika za boje kartica nalazi se u: `lib/utils/card_color_helper.dart`

### Prioritet stanja (od najvišeg ka najnižem)

| # | Stanje | Emoji | Uslov | Klasa |
|---|--------|-------|-------|-------|
| 1 | Odsustvo | 🟡 | `odsutan == true` | `CardState.odsustvo` |
| 2 | Otkazano | 🔴 | `otkazano == true` | `CardState.otkazano` |
| 3 | Plaćeno | 🟢 | `pokupljen == true` && (`placeno == true` \|\| `mesecna_karta == true`) | `CardState.placeno` |
| 4 | Pokupljeno | 🔵 | `pokupljen == true` | `CardState.pokupljeno` |
| 5 | Nepokupljeno | ⚪ | default | `CardState.nepokupljeno` |

---

### Pozadina Kartice

| Stanje | Boja | Hex | RGBA | Opis |
|--------|------|-----|------|------|
| 🟡 Odsustvo | Svetlo žuta | `#FFF59D` | `rgba(255, 245, 157, 1.0)` | `Colors.yellow[200]` |
| 🔴 Otkazano | Svetlo crvena | `#FFE5E5` | `rgba(255, 229, 229, 1.0)` | Custom |
| 🟢 Plaćeno | Zelena | `#388E3C` | `rgba(56, 142, 60, 1.0)` | `Colors.green[700]` |
| 🔵 Pokupljeno | Svetlo plava | `#7FB3D3` | `rgba(127, 179, 211, 1.0)` | Custom |
| ⚪ Nepokupljeno | Bela (70%) | `#FFFFFFB3` | `rgba(255, 255, 255, 0.70)` | `Colors.white70` |

---

### Gradient Pozadina

| Stanje | Start | End | Opis |
|--------|-------|-----|------|
| 🟡 Odsustvo | `#FFF59D` | `#FFEE58` | Svetlo žuta → Intenzivna žuta |
| 🔴 Otkazano | `#FFE5E5` | `#FFCCCC` | Svetlo crvena → Srednje crvena |
| 🟢 Plaćeno | `#4CAF50` | `#388E3C` | Srednje zelena → Tamna zelena |
| 🔵 Pokupljeno | `#7FB3D3` | `#5A9BBE` | Svetlo plava → Srednje plava |
| ⚪ Nepokupljeno | `#FFFFFF` | `#F5F5F5` | Bela → Svetlo siva |

---

### Boja Teksta

| Stanje | Boja | Hex | Opis |
|--------|------|-----|------|
| 🟡 Odsustvo | Orange | `#F57C00` | `Colors.orange[700]` |
| 🔴 Otkazano | Crvena | `#EF5350` | `Colors.red[400]` |
| 🟢 Plaćeno | Zelena | *iz teme* | `successPrimary` iz ColorScheme |
| 🔵 Pokupljeno | Tamno plava | `#0D47A1` | `Colors.blue[900]` |
| ⚪ Nepokupljeno | Crna | `#000000` | `Colors.black` |

---

### Sekundarna Boja Teksta

| Stanje | Boja | Hex | Opacity | Opis |
|--------|------|-----|---------|------|
| 🟡 Odsustvo | Orange | `#F57C00` | 0.7 | 70% orange |
| 🔴 Otkazano | Crvena | `#EF5350` | 0.7 | 70% crvena |
| 🟢 Plaćeno | Zelena | `#388E3C` | 0.8 | 80% tamno zelena |
| 🔵 Pokupljeno | Plava | `#0D47A1` | 0.7 | 70% tamno plava |
| ⚪ Nepokupljeno | Siva | `#757575` | 1.0 | `Colors.grey[600]` |

---

### Boja Ivice (Border)

| Stanje | Boja | Alpha | Rezultat |
|--------|------|-------|----------|
| 🟡 Odsustvo | `#FFC107` | 0.6 | Narandžasto-žuta |
| 🔴 Otkazano | Crvena | 0.25 | Bledo crvena |
| 🟢 Plaćeno | `#388E3C` | 0.4 | Srednje zelena |
| 🔵 Pokupljeno | `#7FB3D3` | 0.4 | Srednje plava |
| ⚪ Nepokupljeno | Siva | 0.10 | Vrlo bleda siva |

---

### Boja Senke (Shadow)

| Stanje | Boja | Alpha | Opis |
|--------|------|-------|------|
| 🟡 Odsustvo | `#FFC107` | 0.2 | Žućkasta senka |
| 🔴 Otkazano | Crvena | 0.08 | Bledo crvena senka |
| 🟢 Plaćeno | `#388E3C` | 0.15 | Zelenkasta senka |
| 🔵 Pokupljeno | `#7FB3D3` | 0.15 | Plavičasta senka |
| ⚪ Nepokupljeno | Crna | 0.07 | Standardna senka |

---

### Boja Ikonica

| Stanje | Boja | Hex | Opis |
|--------|------|-----|------|
| 🟡 Odsustvo | Amber | `#FFC107` | `Colors.amber` |
| 🔴 Otkazano | Crvena | `#EF5350` | `Colors.red[400]` |
| 🟢 Plaćeno | Zelena | `#43A047` | `Colors.green[600]` |
| 🔵 Pokupljeno | Plava | `#1976D2` | `Colors.blue[700]` |
| ⚪ Nepokupljeno | Siva | `#757575` | `Colors.grey[600]` |

---

## 🚗 Boje Vozača (VozacBoja)

Definisane u: `lib/utils/vozac_boja.dart`

### Mapping Vozač → Boja

| Vozač | Boja | Hex | RGB | Opis |
|-------|------|-----|-----|------|
| Bruda | Ljubičasta | `#7C4DFF` | `rgb(124, 77, 255)` | `Colors.deepPurpleAccent` |
| Bilevski | Narandžasta | `#FF9800` | `rgb(255, 152, 0)` | `Colors.orange` |
| Bojan | Cyan | `#00E5FF` | `rgb(0, 229, 255)` | `Colors.cyanAccent` |
| Svetlana | Pink | `#FF1493` | `rgb(255, 20, 147)` | Deep Pink |
| Vlajic | Braon | `#8B4513` | `rgb(139, 69, 19)` | Saddle Brown |

### Korišćenje

```dart
import 'package:gavra_android/utils/vozac_boja.dart';

// Dobijanje boje za vozača
Color boja = VozacBoja.dajBoju('Bilevski'); // Narandžasta

// Default boja ako vozač nije pronađen
Color defaultBoja = VozacBoja.dajBoju('Nepoznat'); // Colors.grey
```

---

## 🎨 Tema Aplikacije (theme.dart)

Definisana u: `lib/theme.dart`

### Custom ColorScheme Extensions

```dart
extension CustomColors on ColorScheme {
  Color get successPrimary => const Color(0xFF4CAF50);
  Color get warningPrimary => const Color(0xFFFFC107);
  Color get infoPrimary => const Color(0xFF2196F3);
  Color get errorSoft => const Color(0xFFFFEBEE);
  Color get successSoft => const Color(0xFFE8F5E9);
  Color get warningSoft => const Color(0xFFFFF8E1);
  Color get infoSoft => const Color(0xFFE3F2FD);
}
```

| Boja | Ime | Hex | Upotreba |
|------|-----|-----|----------|
| 🟢 | successPrimary | `#4CAF50` | Uspešne akcije, plaćeni |
| 🟡 | warningPrimary | `#FFC107` | Upozorenja, odsustva |
| 🔵 | infoPrimary | `#2196F3` | Informacije |
| 🔴 | errorSoft | `#FFEBEE` | Soft error pozadina |
| 🟢 | successSoft | `#E8F5E9` | Soft success pozadina |
| 🟡 | warningSoft | `#FFF8E1` | Soft warning pozadina |
| 🔵 | infoSoft | `#E3F2FD` | Soft info pozadina |

---

## 📱 Korišćenje u Widgetima

### PutnikCard

```dart
// Dobijanje kompletne dekoracije kartice
final decoration = CardColorHelper.getCardDecoration(putnik);

// Dobijanje boje teksta
final textColor = CardColorHelper.getTextColorWithTheme(
  putnik,
  context,
  successPrimary: Theme.of(context).colorScheme.successPrimary,
);

// Dobijanje sekundarne boje teksta
final secondaryColor = CardColorHelper.getSecondaryTextColor(putnik);

// Dobijanje boje ikonica
final iconColor = CardColorHelper.getIconColor(putnik);
```

### Vozači u PazarPoVozacimaWidget

```dart
// Lista vozača sa redosledom
final vozaciRedosled = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana', 'Vlajic'];

// Korišćenje boje
Container(
  color: VozacBoja.dajBoju(vozac),
  child: Text(vozac),
)
```

---

## 🔧 Best Practices

### ✅ DO

1. **Uvek koristi `CardColorHelper`** za boje kartica putnika
2. **Uvek koristi `VozacBoja`** za boje vozača
3. **Koristi extension metode** iz `theme.dart` za semantic boje
4. **Testiraj boje** sa `CardColorHelper.getStateDebugString(putnik)`

### ❌ DON'T

1. **Ne koristi hardkodirane hex vrednosti** u widgetima
2. **Ne dupliciraj logiku boja** - koristi centralne helper klase
3. **Ne menjaj prioritet stanja** bez ažuriranja dokumentacije
4. **Ne zaboravi alpha vrednosti** kod ivica i senki

---

## 📝 Changelog

| Datum | Promena |
|-------|---------|
| 2024-XX-XX | Kreiran CardColorHelper |
| 2024-XX-XX | Dodat Vlajic u VozacBoja |
| 2024-XX-XX | Refaktorisan PutnikCard |
| 2024-XX-XX | Kreirana dokumentacija |

---

## 🧪 Testiranje

Testovi se nalaze u: `test/utils/card_color_helper_test.dart`

Pokretanje testova:
```bash
flutter test test/utils/card_color_helper_test.dart
```
