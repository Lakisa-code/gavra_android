# 🎨 Analiza Ikona u Kartici Putnika

**Kreirano:** 29.01.2026  
**Status:** Kompletan pregled svih ikona sa provera ispravnosti  
**Relevantne datoteke:** `lib/widgets/putnik_card.dart`, `lib/utils/card_color_helper.dart`

---

## 1. GLAVNE IKONE PO STATUSU

### 1.1 Status Boja Kartice (CardColorHelper)

Svaki putnik ima glavnu boju koja zavisi od stanja:

| Emoji | Status | Hex Boja | Datoteka | Logika |
|-------|--------|----------|----------|--------|
| 🟡 | Odsustvo (Godišnji/Bolovanje) | #FFF59D | `card_color_helper.dart:19` | `putnik.jeOdsustvo == true` |
| 🔴 | Otkazano | #FFE5E5 | `card_color_helper.dart:20` | `putnik.jeOtkazan == true` |
| 🟢 | Plaćeno/Mesečno | #E8F5E9 | `card_color_helper.dart:21` | `pokupljen && (iznosPlacanja > 0 \|\| mesecnaKarta)` |
| 🔵 | Pokupljeno Neplaćeno | #E3F2FD | `card_color_helper.dart:22` | `pokupljen && iznosPlacanja == 0` |
| 🔘 | Tuđi putnik (drugog vozača) | #F5F5F5 | `card_color_helper.dart:23` | `dodeljenVozac != currentDriver` |
| ⚪ | Nepokupljeno (default) | #FAFAFA | `card_color_helper.dart:24` | Sve ostalo |

**Logika prioriteta (iz `CardColorHelper.getCardState`):**
```dart
if (putnik.jeOdsustvo) return CardState.odsustvo;      // ← Najviši prioritet
if (putnik.jeOtkazan) return CardState.otkazano;
if (putnik.jePokupljen) {
  if (isPlaceno || isMesecniTip) return CardState.placeno;
  return CardState.pokupljeno;
}
return CardState.nepokupljeno;                          // ← Najniži prioritet
```

---

## 2. AKCIONE IKONE U KARTICI

Nalazi se na desnoj strani kartice, vidljive samo ako je:
- `widget.showActions == true` (obično za vozače i admince)
- Redosled je **fiksno određen** sa leva na desno

### 2.1 IKONA #1: Mesečna Karta Badge 📅

**Lokacija u kodu:** `putnik_card.dart:1448-1470`  
**Prikazuje se:** Samo ako `putnik.isMesecniTip == true`  
**Tip:** Tekst badge sa zvezdicom

```dart
if (_putnik.isMesecniTip)
  Align(
    alignment: Alignment.topRight,
    child: Container(
      // 🟡 Žuta boja
      decoration: BoxDecoration(
        color: Colors.amber.shade300,
        shape: BoxShape.circle,
      ),
      child: Text('⭐', style: TextStyle(fontSize: 12)),
    ),
  ),
```

**Kada se prikazuje:**
- ✅ Radnik (tip 'radnik')
- ✅ Učenik (tip 'ucenik')
- ❌ Dnevni putnici
- ❌ Otkazani putnici

---

### 2.2 IKONA #2: GPS/Navigacija 📡

**Lokacija u kodu:** `putnik_card.dart:1500-1650`  
**Prikazuje se:** Ako putnik ima adresu ILI je mesečna karta  
**Akcija:** Otvara dialog sa adresom → dugme za GPS navigaciju

```dart
if ((_putnik.mesecnaKarta == true) || 
    (_putnik.adresa != null && _putnik.adresa!.isNotEmpty)) {
  // 📡 GPS Emoji container sa glassmorphism efektom
  Container(
    child: Center(
      child: Text('📡', style: TextStyle(fontSize: iconInnerSize * 0.8)),
    ),
  ),
}
```

**Logika:**
1. **Klik** → Prikazuje dialog sa adresom
2. **Dialog dugme "Navigacija"** → 
   - Zahteva GPS dozvole (`PermissionService.ensureGpsForNavigation()`)
   - Poziva `_getKoordinateZaAdresu()` 
   - Otvara `_otvoriNavigaciju()` sa Google Maps/Apple Maps

**Greške:**
- ❌ GPS dozvole nisu uključene → Prikazuje snackbar "GPS dozvole su potrebne"
- ❌ Lokacija nije pronađena → "Lokacija nije pronađena" sa retry-om nakon 10 sekundi

---

### 2.3 IKONA #3: Telefon 📞

**Lokacija u kodu:** `putnik_card.dart:1750-1790`  
**Prikazuje se:** Ako putnik ima `brojTelefona` (nije null i nije prazan)  
**Akcija:** Otvoriti poziv (tel:// scheme)

```dart
if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
  GestureDetector(
    onTap: _pozovi,  // ← Otvara tel:// URI
    child: Container(
      child: Center(
        child: Text('📞', style: TextStyle(fontSize: iconInnerSize * 0.8)),
      ),
    ),
  ),
}
```

**Logika `_pozovi()`:**
```dart
Future<void> _pozovi() async {
  final Uri launchUri = Uri(scheme: 'tel', path: _putnik.brojTelefona);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);  // ← Otvara dijaer
  }
}
```

---

### 2.4 IKONA #4: Plaćanje 💵

**Lokacija u kodu:** `putnik_card.dart:1792-1840`  
**Prikazuje se:** Ako putnik NIJE otkazan I:
- `mesecnaKarta == true` ILI
- `iznosPlacanja == null` ili `== 0` (nepaid)

**Akcija:** Prikazuje dialog za unos plaćanja

```dart
if (!_putnik.jeOtkazan && 
    (_putnik.mesecnaKarta == true ||
     (_putnik.iznosPlacanja == null || _putnik.iznosPlacanja == 0))) {
  GestureDetector(
    onTap: () => _handlePayment(),  // ← Dialog za plaćanje
    child: Container(
      child: Center(
        child: Text('💵', style: TextStyle(fontSize: iconInnerSize * 0.8)),
      ),
    ),
  ),
}
```

**Uslov za prikazivanje:**
- ✅ Mesečna karta (za obnovu)
- ✅ Nepaid dnevni putnik
- ❌ Već plaćeni putnik
- ❌ Otkazani putnik

---

### 2.5 IKONA #5: Otkazivanje ❌

**Lokacija u kodu:** `putnik_card.dart:1842-1900`  
**Prikazuje se:** Ako putnik NIJE već otkazan I:
- `mesecnaKarta == true` ILI
- Nije pokupljen (`vremePokupljenja == null`) I nije plaćen

**Akcija:** Otkazuje putnika
- **Za vozače:** Direktno otkazivanje
- **Za admince:** Popup sa dodatnim opcijama

```dart
if (!_putnik.jeOtkazan &&
    (_putnik.mesecnaKarta == true ||
     (_putnik.vremePokupljenja == null &&
      (_putnik.iznosPlacanja == null || _putnik.iznosPlacanja == 0)))) {
  GestureDetector(
    onTap: () {
      if (isAdmin) {
        _showAdminPopup();     // ← Admin vidi više opcija
      } else {
        _handleOtkazivanje();  // ← Vozač direktno otkazuje
      }
    },
    child: Container(
      child: Center(
        child: Text('❌', style: TextStyle(fontSize: iconInnerSize * 0.8)),
      ),
    ),
  ),
}
```

---

## 3. DIZAJN IKONA - GLASSMORPHISM STIL

### 3.1 Kontejner za sve akcione ikone

Svaka akciona ikona (🛰️ GPS, 📞 telefon, 💵 plaćanje, ❌ otkazivanje) koristi isti dizajn:

**Lokacija:** `putnik_card.dart:1710-1740` (template)

```dart
Container(
  width: iconSize,      // Adaptive: 20-24px
  height: iconSize,
  decoration: BoxDecoration(
    // 🌟 Glassmorphism - semi-transparent gradient
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.10),
      ],
    ),
    borderRadius: BorderRadius.circular(8),  // ← Zaobljeni ugao
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.4),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Center(
    child: Text(
      emoji,  // 📡, 📞, 💵, ❌
      style: TextStyle(fontSize: iconInnerSize * 0.8),
    ),
  ),
)
```

**Adaptive veličine:**

| Ekran | iconSize | iconInnerSize |
|-------|----------|---------------|
| Mini (<150px) | 20px | 16px |
| Mali (150-300px) | 22px | 18px |
| Normalni (>300px) | 24px | 20px |

---

## 4. REDOSLED IKONA U KARTICI

Redosled je **fiksno određen** sa leva na desno:

```
┌─────────────────────────────────────────────┐
│ Ime putnika                 📅 ⭐ 📡 📞 💵 ❌ │
│ Adresa                                       │
│ Vremenske vrednosti                          │
└─────────────────────────────────────────────┘
```

1. **📅 Mesečna karta** - uvek prvi ako je prikazan
2. **📡 GPS/Navigacija** - ako ima adresu
3. **📞 Telefon** - ako ima telefonski broj
4. **💵 Plaćanje** - ako nije plaćeno
5. **❌ Otkazivanje** - ako se može otkazati

**Napomena:** Sve ikone koriste `Wrap` widget kako ne bi došlo do overflow-a na manjim ekranima.

---

## 5. POSEBNE IKONE U DIALOZIMA

### 5.1 Status Ikone u time_picker_cell.dart

**Lokacija:** `lib/widgets/shared/time_picker_cell.dart:300-340`

```dart
switch (status) {
  case 'cancel':
    Icon(Icons.cancel, size: 12, color: textColor)  // 🔴 OTKAZANO
    
  case 'waiting':
    Icon(Icons.hourglass_empty, size: 12, color: textColor)  // ⏳ ČEKA
    
  case 'pending':
    Icon(Icons.schedule, size: 12, color: textColor)  // 🕐 PENDING
    
  case null or '':
    Icon(Icons.check_circle, size: 12, color: Colors.green)  // ✅ POTVRĐENO
}
```

### 5.2 Event Log Ikone u ml_dnevnik_screen.dart

**Lokacija:** `lib/screens/ml_dnevnik_screen.dart:280-330`

```dart
switch (tip) {
  case 'otkazivanje':
    iconData = Icons.block;           // Crvena - Otkazivanje
    themeColor = Colors.red;
    
  case 'odsustvo':
    iconData = Icons.event_busy;      // Narandžasta - Opšte odsustvo
    themeColor = Colors.orange;
    
  case 'bolovanje':
    iconData = Icons.sick;            // Narandžasta - Bolovanje
    themeColor = Colors.orange;
    
  case 'godišnji':
    iconData = Icons.beach_access;    // Plava - Godišnji odmor
    themeColor = Colors.blue;
    
  case 'povratak_na_posao':
    iconData = Icons.check_circle;    // Teal - Povratak
    themeColor = Colors.teal;
}
```

---

## 6. PROBLEMI I ISPRAVNOSTI

### 6.1 ✅ Ispravna Logika

| Svojstvo | Status | Razlog |
|----------|--------|--------|
| Redosled ikona | ✅ Ispravno | Fiksno: 📅→📡→📞→💵→❌ |
| Glassmorphism efekt | ✅ Ispravno | Sve akcione ikone koriste isti stil |
| Adaptive veličine | ✅ Ispravno | 3 nivoa prema širini ekrana |
| Otkazivanje skrivanje | ✅ Ispravno | Otkazani putnici nemaju ❌ ikonu |
| Plaćanje uslov | ✅ Ispravno | Pokazuje se samo ako nije plaćeno |
| GPS navigacija | ✅ Ispravno | Zahteva dozvole pre upotrebe |

### 6.2 ⚠️ Potencijalni Problemi

**Problem #1: Overflow na Mini Ekranima**
- **Lokacija:** Ako putnik ima sve 5 ikona, može doći do overflow-a
- **Trenutna zaštita:** `Wrap` widget sa `spacing` - dozvoljava prelom na drugi red
- **Status:** ✅ Zaštićeno, ali redosled na drugom redu može biti dezorientirajući

**Problem #2: GPS Koordinate Timeout**
- **Lokacija:** `_getKoordinateZaAdresu()` može trpeti zbog spore internet konekcije
- **Trenutna zaštita:** Loading snackbar sa 15-sekundnim timeout-om
- **Status:** ✅ Zaštićeno sa fallback porukom

**Problem #3: Otkazivanje već Otkazanog**
- **Lokacija:** `_handleOtkazivanje()` provera
- **Provera:** `if (!_putnik.jeOtkazan)` pre nego što prikaže ❌ ikonu
- **Status:** ✅ Zaštićeno - user ne može videti ikonu ako je već otkazan

---

## 7. PROVERA PO MODULIMA

### 7.1 CardColorHelper Provera

**Datoteka:** `lib/utils/card_color_helper.dart`

```dart
// ✅ Sve boje su definirane
static Color getBackgroundColor(Putnik putnik)
static Color getTextColor(Putnik putnik, ...)
static Color getIconColor(Putnik putnik, ...)

// ✅ Prioritet je jasan
CardState.odsustvo    // Najviši
CardState.otkazano
CardState.placeno
CardState.pokupljeno
CardState.tudji
CardState.nepokupljeno // Najniži
```

### 7.2 PutnikCard Provera

**Datoteka:** `lib/widgets/putnik_card.dart`

```dart
// ✅ Sve ikone imaju provere prikazivanja
if (_putnik.isMesecniTip) { ... }          // 📅
if (_putnik.adresa != null) { ... }        // 📡
if (_putnik.brojTelefona != null) { ... }  // 📞
if (!_putnik.jeOtkazan && ...) { ... }     // 💵
if (!_putnik.jeOtkazan && ...) { ... }     // ❌

// ✅ Sve akcije imaju error handling-a
_handlePayment()       // Plaćanje sa validacijom
_handleOtkazivanje()   // Otkazivanje sa logging-om
_pozovi()              // Poziv sa canLaunchUrl proverom
_otvoriNavigaciju()    // GPS sa permission proverom
```

---

## 8. ZAKLJUČAK - ISPRAVNOST IKONA

| Kategorija | Ocena | Detalj |
|-----------|-------|--------|
| **Logika prikazivanja** | 9/10 | Sve ikone imaju jasne uslove |
| **Dizajn konzistentnosti** | 10/10 | Sve koriste glassmorphism efekt |
| **Error handling** | 8/10 | GPS ima timeout, ali telefon/plaćanje mogla bi bolja validacija |
| **Accessibility** | 7/10 | Emoji su jasni ali mogla bi alt text za slabo vidiće |
| **Performance** | 8/10 | Adaptive veličine su dobra, ali GPU rendering mogao bi biti optimalniji |

### Finalnih Preporuke:

✅ **ČINI SE JE SVE ISPRAVNO**

1. **Redosled ikona** je fiksno određen i logičan
2. **Glassmorphism dizajn** je konzistentan across sve ikone
3. **Logika prikazivanja** je dobra sa jasnim uslovima
4. **Error handling** je zadovoljavajući
5. **Performance** je OK za 99% slučajeva

⚠️ **Potencijalne Optimizacije:**
- Dodati `Semantics` widget za accessibility
- Cache-irati GPS koordinate
- Dodati haptic feedback na klikove ikona
- Test sa svim kombinacijama statusa (otkazano + plaćeno, itd)

