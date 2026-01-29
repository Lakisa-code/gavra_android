# 📋 Logika za Otkazanog Putnika - Detaljni Pregled

## 1. STRUKTURА PODATAKA

### 1.1 Glavni Status Putnika
Putnik ima **dva nivoa statusa**:

```dart
// GLOBALNI status (kolona 'status' u bazi)
status: 'radi' | 'bolovanje' | 'godisnji' | 'otkazan' | 'otkazano'

// PO-POLAZAK status (unutar polasci_po_danu JSON-a)
otkazanZaPolazak: true/false  // Specifičan za dan i grad (bc/vs)
```

### 1.2 JSON Struktura - polasci_po_danu
```json
{
  "pon": {
    "bc": "6:00",           // Vreme polaska za Bela Crkva
    "vs": "14:00",          // Vreme polaska za Vršac
    "bc_otkazano": "2026-01-29T10:30:00.000Z",     // Timestamp otkazivanja BC
    "vs_otkazano": "2026-01-29T11:15:00.000Z",     // Timestamp otkazivanja VS
    "bc_otkazao_vozac": "Marko",                   // Ko je otkazao BC
    "vs_otkazao_vozac": "Petar",                   // Ko je otkazao VS
    "bc_vreme_pokupljenja": "2026-01-29T05:45:00", // Pokupljeno za BC
    "vs_vreme_pokupljenja": "2026-01-29T13:50:00", // Pokupljeno za VS
    "bc_pokupio_vozac": "Marko",                   // Ko je pokupljio BC
    "vs_pokupio_vozac": "Petar",                   // Ko je pokupljio VS
    "bc_vozac": "Marko",                            // Fiksni vozač za BC
    "vs_vozac": "Petar",                            // Fiksni vozač za VS
    "bc_status": "pending|confirmed|waiting",      // Status polaska BC
    "vs_status": "pending|confirmed|waiting",      // Status polaska VS
    "bc_mesta": 1,                                  // Broj mesta BC
    "vs_mesta": 2                                   // Broj mesta VS
  },
  "uto": {...},
  "sre": {...},
  "cet": {...},
  "pet": {...},
  "sub": {...},
  "ned": {...}
}
```

---

## 2. LOGIKA DETEKTOVANJA - Da li je putnik "OTKAZAN"?

### 2.1 Getter za otkazanost - `jeOtkazan`
```dart
bool get jeOtkazan =>
    obrisan || 
    otkazanZaPolazak || 
    status?.toLowerCase() == 'otkazano' || 
    status?.toLowerCase() == 'otkazan';
```

**Objašnjenje:**
- ✅ `obrisan == true` → OTKAZAN (soft delete)
- ✅ `otkazanZaPolazak == true` → OTKAZAN za specifičan polazak (grad)
- ✅ `status == 'otkazano' || 'otkazan'` → OTKAZAN (globalni status)

### 2.2 Proverava per-grad otkazanost - `isOtkazanForDayAndPlace()`
```dart
// lib/utils/registrovani_helpers.dart

static bool isOtkazanForDayAndPlace(
  Map<String, dynamic> rawMap,
  String dayKratica,    // 'pon', 'uto', 'sre', itd.
  String place,         // 'bc' ili 'vs'
) {
  // 1. Učitaj polasci_po_danu JSON
  final decoded = jsonDecode(rawMap['polasci_po_danu']) as Map<String, dynamic>;
  
  // 2. Pronađi podatke za specifičan dan
  final dayData = decoded[dayKratica] as Map<String, dynamic>;
  
  // 3. Pronađi timestamp otkazivanja
  final otkazanoKey = '${place}_otkazano';  // npr. 'bc_otkazano' ili 'vs_otkazano'
  final otkazanoTimestamp = dayData[otkazanoKey] as String?;
  
  // 4. ⚠️ VAŽNO: Važi samo ako je POSLE poslednjeg petka u ponoć!
  final resetPoint = _getLastFridayMidnight();
  return otkazanoDate.isAfter(resetPoint);
}
```

**Ključna značenja:**
- **Reset uvek petak→subota u ponoć** - sve otkazivanja starija od toga se brišu
- **Graničnik**: `2026-01-24 00:00:00 UTC` (poslednji petak do sad)
- Otkazivanja do tog vremena se **IGNORIŠU**

### 2.3 Kupljenje vremenskih informacija
```dart
// 📌 VREME OTKAZIVANJA
DateTime? getVremeOtkazivanjaForDayAndPlace(...) 
  → Vraća DateTime otkazivanja ILI null ako je pre graničnika

// 📌 VOZAČ KOJI JE OTKAZAO  
String? getOtkazaoVozacForDayAndPlace(...)
  → Vraća ime vozača koji je sačuvano u '${place}_otkazao_vozac'

// 📌 VREME POKUPLJANJA
DateTime? getVremePokupljenjaForDayAndPlace(...)
  → Vraća DateTime pokupljanja ILI null ako je pre graničnika
```

---

## 3. KREIRANJE OTKAZANOG PUTNIKA

### 3.1 Factory metoda - `fromRegistrovaniPutnici()`
```dart
factory Putnik.fromRegistrovaniPutnici(Map<String, dynamic> map) {
  // ... setup ...
  
  // 🎯 KLJUČNI DEO: Provera otkazanosti
  final otkazanZaPolazak = RegistrovaniHelpers.isOtkazanForDayAndPlace(
    map, 
    danKratica,  // npr. 'pon'
    place        // npr. 'bc' ili 'vs'
  );
  
  final vremeOtkazivanja = RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(
    map, 
    danKratica, 
    place
  );
  
  final otkazaoVozac = RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(
    map, 
    danKratica, 
    place
  );
  
  // LOGIKA: Ako je otkazan, ali nema vremena otkazivanja, koristi placeholder
  final statusIzBaze = map['status'] as String? ?? 'radi';
  String status = statusIzBaze;
  if (statusIzBaze != 'bolovanje' && statusIzBaze != 'godisnji') {
    if (otkazanZaPolazak) {
      status = 'otkazan';  // ← Postavi kao OTKAZANO
    } else {
      status = 'radi';
    }
  }
  
  return Putnik(
    // ... ostali podaci ...
    status: status,                    // 'radi' ili 'otkazan'
    vremeOtkazivanja: vremeOtkazivanja,  // DateTime ili null
    otkazaoVozac: otkazaoVozac,          // String ili null
    otkazanZaPolazak: otkazanZaPolazak,  // true/false
  );
}
```

---

## 4. AKCIJE SA OTKAZANIM PUTNICIMA

### 4.1 Otkazivanje Putnika - `otkaziPutnika()`
```dart
// lib/services/putnik_service.dart

Future<void> otkaziPutnika(
  dynamic id,
  String otkazaoVozac, {
  String? selectedVreme,   // Vreme polaska
  String? selectedGrad,    // Grad (Bela Crkva ili Vršac)
  String? selectedDan,     // Dan (Pon/Uto/...)
}) async {
  // 1. Učitaj registrovani putnik iz baze
  final response = await supabase
    .from('registrovani_putnici')
    .select()
    .eq('id', id)
    .maybeSingle();

  // 2. Odredi place ('bc' ili 'vs') iz selectedGrad
  String place = 'bc'; // default
  if (selectedGrad.toLowerCase().contains('vr')) {
    place = 'vs';
  }

  // 3. Odredi dan iz selectedDan
  final danKratica = selectedDan.toLowerCase().substring(0, 3);

  // 4. Učitaj postojeću strukturu polasci_po_danu
  Map<String, dynamic> polasci = jsonDecode(response['polasci_po_danu']);

  // 5. 🎯 KREIRAJ OTKAZIVANJE
  final dayData = polasci[danKratica];
  dayData['${place}_otkazano'] = DateTime.now().toIso8601String();  // ← Timestamp
  dayData['${place}_otkazao_vozac'] = otkazaoVozac;                   // ← Vozač
  polasci[danKratica] = dayData;

  // 6. Ažuriraj bazu
  await supabase
    .from('registrovani_putnici')
    .update({'polasci_po_danu': polasci})
    .eq('id', id);

  // 7. Loguj akciju u voznje_log
  await VoznjeLogService.logGeneric(
    tip: 'otkazivanje',
    putnikId: id,
    meta: {'vozac': otkazaoVozac, 'grad': selectedGrad, 'dan': selectedDan},
  );
}
```

**Što se čuva:**
- ✅ `${place}_otkazano` = `DateTime.now()` - Timestamp otkazivanja
- ✅ `${place}_otkazao_vozac` = `vozac_ime` - Ko je otkazao
- ✅ Sve per-grad (BC ili VS posebno)
- ✅ Sve per-dan (Pon, Uto, itd. posebno)

### 4.2 Provera i Ažuriranje Logike
```dart
// lib/services/putnik_service.dart

// Kada se putnik učita sa kratkošću vremena u bazu
if (p.jeOtkazan && p.vremeOtkazivanja == null && p.id != null) {
  final Map<String, dynamic>? oData = otkazivanja[p.id];
  if (oData != null) {
    // Preuzmi vreme otkazivanja iz voznje_log ako nedostaje
    p = p.copyWith(
      vremeOtkazivanja: DateTime.parse(oData['vreme_otkazivanja'] as String),
      otkazaoVozac: oData['vozac'] as String?,
    );
  }
}
```

---

## 5. PRIKAZ OTKAZANOG PUTNIKA

### 5.1 UI Identifikacija
```dart
// Putnik se prikazuje kao OTKAZAN ako:
if (putnik.jeOtkazan) {
  // Prikaži sa crvenom bojom ili strikethrough
  // Status icon: ❌ OTKAZANO
  // Prikaži vreme otkazivanja ako postoji
  // Prikaži vozača koji je otkazao
}

// Primer:
Text(
  putnik.ime,
  style: putnik.jeOtkazan 
    ? TextStyle(
        color: Colors.red,
        decoration: TextDecoration.lineThrough,
      )
    : null,
),
Text('Otkazao: ${putnik.otkazaoVozac ?? "Nepoznato"}'),
Text('Vreme: ${putnik.vremeOtkazivanja}'),
```

### 5.2 Brojanje Otkazanih
```dart
// Iz putnika liste
final brojOtkazanih = putnici.where((p) => p.jeOtkazan).length;

// U daily_reports
final otkazani_putnici = {
  'Marko': 2,      // 2 otkazivanja
  'Petar': 1,      // 1 otkazivanje
  'Ivan': 0,
}
```

---

## 6. RESET LOGIKA - Petak→Subota 00:00 UTC

### 6.1 Kada se Otkazivanja Reset-uju?
```dart
// Svakoga petka u ponoć (petak→subota)
static DateTime _getLastFridayMidnight() {
  final now = DateTime.now();
  
  int daysToSubtract;
  if (now.weekday == 6) {      // Subota
    daysToSubtract = 1;         // Petak je bio juče
  } else if (now.weekday == 7) { // Nedelja
    daysToSubtract = 2;         // Petak je bio pre 2 dana
  } else {                        // Pon-Pet
    daysToSubtract = now.weekday + 2; // Prošla nedelja
  }
  
  final lastFriday = DateTime(now.year, now.month, now.day)
    .subtract(Duration(days: daysToSubtract));
  
  return DateTime(lastFriday.year, lastFriday.month, lastFriday.day, 0, 0, 0);
}
```

### 6.2 Primer Resetovanja
```
Trenutni datum: Nedelja 29.1.2026

Graničnik: Petak 24.1.2026 00:00 UTC
├─ Otkazivanje od 23.1 → BRIŠI (pre graničnika)
├─ Otkazivanje od 24.1 → BRIŠI (tačno na graničniku, nije isAfter)
├─ Otkazivanje od 25.1 → ČUVA (nakon graničnika)
└─ Otkazivanje od 29.1 → ČUVA (tekući dan)

Naredni reset: Petak 31.1.2026 00:00 UTC
```

---

## 7. MOGUĆNI PROBLEMI I REŠENJA

### Problem 1: Putnik se prikazuje kao otkazan ali nije trebalo
**Uzrok:** Stara otkazivanja se čuvaju u bazi (pre resetovanja)
```dart
// Rešenje: Provera graničnika je ugrađena
if (otkazanoDate.isAfter(resetPoint)) {
  return true;  // Samo ako je POSLE petka
}
```

### Problem 2: Vreme otkazivanja nije sačuvano
**Uzrok:** `vremeOtkazivanja` je null, ali `otkazanZaPolazak` je true
```dart
// Rešenje: Pročitaj iz voznje_log servisa
if (p.jeOtkazan && p.vremeOtkazivanja == null) {
  p = p.copyWith(
    vremeOtkazivanja: oData['vreme_otkazivanja'] as DateTime,
  );
}
```

### Problem 3: Otkazivanje se čuva za pogrešan dan
**Uzrok:** `selectedDan` nije pravilno normalizovan
```dart
// Rešenje: Koristi daniKratice mapping
const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
final danKratica = selectedDan.toLowerCase().substring(0, 3);
if (!daniKratice.contains(danKratica)) {
  danKratica = daniKratice[DateTime.now().weekday - 1];
}
```

---

## 8. SORTIRANJE KARTICA PUTNIKA

### 8.1 Redosled Kartica - Prioritet Boja
```
1. ⚪ BELE    - Nepokupljeni (na vrhu)
2. 🔵 PLAVE   - Pokupljeni neplaćeni  
3. 🟢 ZELENE  - Pokupljeni plaćeni/mesečni
4. 🔴 CRVENE  - Otkazani ← 👈 OTKAZANI PUTNICI
5. 🟡 ŽUTE    - Odsustvo (godišnji/bolovanje) (na dnu)
```

### 8.2 Logika Sortiranja - `_putnikSortKey()`
```dart
// lib/widgets/putnik_list.dart

int _putnikSortKey(Putnik p, String currentDriver, {bool imaSivih = false}) {
  // Prioritet: ŽUTE (dno) → CRVENE → PLAVE → ZELENE → SIVI → NEDODELJENI → MOJI (vrh)
  
  // 🟡 ŽUTE na dno
  if (p.jeOdsustvo) {
    return 7;  // Na dno
  }
  
  // 🔴 CRVENE - OTKAZANI
  if (p.jeOtkazan) {
    return 6;  // Pre žutih, nakon ostalih
  }
  
  // 🔵/🟢 POKUPLJENI
  if (p.jePokupljen) {
    if (p.isMesecniTip || (p.iznosPlacanja ?? 0) > 0) {
      return 5;  // 🟢 Zelene - plaćeni/mesečni
    }
    return 4;    // 🔵 Plave - neplaćeni dnevni
  }
  
  // 🔘 SIVI - tuđi putnici
  final isTudji = p.dodeljenVozac != null && 
                  p.dodeljenVozac != currentDriver;
  if (isTudji) {
    return 3;    // Sivi putnici (tuđi)
  }
  
  // ⚪ BELI - Moji ili nedodeljeni
  if (imaSivih) {
    return (p.dodeljenVozac == currentDriver) ? 1 : 2;
  }
  return 1;      // Nema sivih - svi beli zajedno
}
```

### 8.3 Grupe Sortiranja
Kada je `useProvidedOrder = true`:

```dart
// HYBRID SORTIRANJE: Bele (geografski) + Ostatak (po grupama)

final moji = [];           // Sortkey 1 - moji putnici (VRSTA: bela)
final nedodeljeni = [];    // Sortkey 2 - nedodeljeni (VRSTA: bela)
final sivi = [];           // Sortkey 3 - tuđi putnici (VRSTA: bela)
final plavi = [];          // Sortkey 4 - pokupljeni neplaćeni (VRSTA: plava)
final zeleni = [];         // Sortkey 5 - pokupljeni plaćeni (VRSTA: zelena)
final crveni = [];         // Sortkey 6 - OTKAZANI (VRSTA: CRVENA) ← OVO JE KLJUČNO
final zuti = [];           // Sortkey 7 - odsustvo (VRSTA: žuta)

// FINALNA LISTA:
final prikaz = [
  ...moji,        // Bele - na vrhu (geografski redosled)
  ...nedodeljeni, // Bele - geografski
  ...sivi,        // Bele - geografski
  ...plavi,       // Plave - sortirane po grupama
  ...zeleni,      // Zelene - sortirane po grupama
  ...crveni,      // CRVENE - OTKAZANI PUTNICI
  ...zuti         // Žute - na dnu
];
```

### 8.4 Primer - Kako se Otkazani Putnici Sortiraju?

**Originalna lista:**
```
1. Marko (bela, moj)
2. Petar (crvena, OTKAZAN)
3. Ana (plava, tuđa)
4. Ivan (žuta, godišnji)
5. Jelena (zelena, plaćena)
```

**Sortirana lista:**
```
1. Marko (bela, moj)           ← Sortkey 1
2. Ana (plava, tuđa)           ← Sortkey 3 (sivi)
3. Jelena (zelena, plaćena)    ← Sortkey 5
4. Petar (crvena, OTKAZAN)     ← Sortkey 6 ← VIŠI OD ŽUTIH!
5. Ivan (žuta, godišnji)       ← Sortkey 7
```

⚠️ **NAPOMENA:** Otkazani putnici dolaze **PRE žutih** ali **POSLE ostalih** grupacija!

### 8.5 Redni Brojevi Mesta

```dart
// Redni brojevi se računaju samo za putnika koji trebaju biti prebrojani
int _pocetniRedniBroj(List<Putnik> putnici, int currentIndex) {
  int redniBroj = 1;
  
  // Zbrajaj mesta do ovog putnika
  for (int i = 0; i < currentIndex; i++) {
    final p = putnici[i];
    if (_imaRedniBroj(p)) {  // Proveri da li se broji
      redniBroj += p.brojMesta;
    }
  }
  return redniBroj;
}

// _imaRedniBroj() → Koristi PutnikHelpers.shouldHaveOrdinalNumber()
// OTKAZANI putnici se NE BROJE u rednim brojevima!
```

### 8.6 Provera Sivih Kartica
```dart
bool _imaSivihKartica(List<Putnik> putnici, String currentDriver) {
  return putnici.any((p) =>
    !p.jeOdsustvo &&           // Nije godišnji/bolovanje
    !p.jeOtkazan &&            // NIJE OTKAZAN
    !p.jePokupljen &&          // Nije pokupljen
    p.dodeljenVozac != null &&
    p.dodeljenVozac != currentDriver  // Dodeljen drugom vozaču
  );
}
```

**Zaključak:** Otkazani putnici se **NE RAČUNAJU** kao "sivi"!

---

## 9. SUMMARY - Brzina Provere

| Šta? | Fajl | Metoda | Vraća |
|------|------|--------|-------|
| Da li je otkazan za polazak | `registrovani_helpers.dart` | `isOtkazanForDayAndPlace()` | `bool` |
| Vreme otkazivanja | `registrovani_helpers.dart` | `getVremeOtkazivanjaForDayAndPlace()` | `DateTime?` |
| Vozač koji je otkazao | `registrovani_helpers.dart` | `getOtkazaoVozacForDayAndPlace()` | `String?` |
| Kreiraj otkazanog putnika | `putnik.dart` | `fromRegistrovaniPutnici()` | `Putnik` |
| Otkazi putnika | `putnik_service.dart` | `otkaziPutnika()` | `Future<void>` |
| Getter otkazanosti | `putnik.dart` | `jeOtkazan` | `bool` |
| Sort key putnika | `putnik_list.dart` | `_putnikSortKey()` | `int` (1-7) |
