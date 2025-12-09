# 📊 Izveštaj: Logika za mesečne putnike tip "DNEVNI"

**Datum analize:** 9. decembar 2025.  
**Analizirani fajlovi:**
- `lib/models/mesecni_putnik.dart`
- `lib/models/putovanja_istorija.dart`
- `lib/services/putnik_service.dart`
- `lib/services/putovanja_istorija_service.dart`
- `lib/services/cena_obracun_service.dart`
- `lib/services/statistika_service.dart`
- `lib/screens/mesecni_putnici_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/mesecni_putnik_dialog.dart`

---

## 1. 📦 Model i tabele

### NAPOMENA: Dnevni putnici imaju DUALNU PRIRODU

Dnevni putnici mogu postojati u **dve tabele**:

| Tabela | Opis | Kada se koristi |
|--------|------|-----------------|
| `mesecni_putnici` | Registrovani dnevni putnici sa profilom | Putnici koji se često voze, imaju profil |
| `putovanja_istorija` | Pojedinačna putovanja | Svako pojedinačno putovanje (i registrovanih i ad-hoc) |

### Model `MesecniPutnik` - tip dnevni
```dart
tip: 'dnevni'  // Vrednost u mesecni_putnici tabeli
```

### Model `PutovanjaIstorija` - tip dnevni
```dart
tipPutnika: 'dnevni'  // Default vrednost pri parsiranju (linija 35)
```

---

## 2. 💰 Cene (`cena_obracun_service.dart`)

### ⚠️ KRITIČNO: Default cena je 0!

```dart
static const double defaultCenaDnevniPoDanu = 0.0; // Dnevni mora imati custom cenu
```

### Implikacije
- Dnevni putnici **MORAJU** imati postavljenu `cenaPoDanu` ili `cena` polje
- Ako nemaju, cena se računa kao 0 RSD
- Komentar u kodu: "Dnevni mora imati custom cenu"

### Logika cenovnika
```dart
case 'dnevni':
  return defaultCenaDnevniPoDanu;  // Vraća 0.0
```

---

## 3. 🔍 Filtriranje

### `mesecni_putnici_screen.dart`
```dart
putnici.where((p) => 
  p.tip == 'dnevni' && 
  p.aktivan && 
  !p.obrisan && 
  p.status != 'bolovanje' && 
  p.status != 'godišnje'
).length
```

### `putnik_service.dart` - Filtriranje po tipu
```dart
.eq('tip_putnika', 'dnevni')  // Supabase query filter
```

### Stream kombinovanih putnika
- Dnevni putnici se učitavaju iz `putovanja_istorija` tabele
- Mesečni putnici se učitavaju iz `mesecni_putnici` tabele
- Kombinuju se u jednu listu za prikaz

---

## 4. 🎨 UI Prikaz

### Boje i ikone
| Element | Vrednost |
|---------|----------|
| Boja    | Narandžasta (`orange.shade600`) |
| Ikona   | `Icons.today` |

### Prikaz u listi (`mesecni_putnici_screen.dart`)
```dart
putnik.tip == 'dnevni' ? Icons.today : ...
color: putnik.tip == 'dnevni' ? Colors.orange.shade600 : ...
```

### Prikaz u home_screen dropdown-u
```dart
putnik.tip == 'dnevni' ? Icons.today : ...
color: putnik.tip == 'dnevni' ? Colors.orange.shade600 : ...
```

---

## 5. ➕ Dodavanje dnevnog putnika

### Dva načina dodavanja:

#### A) Iz mesecni_putnici registra (home_screen.dart)
1. Izabere se postojeći dnevni putnik iz dropdown-a
2. Kreira se zapis u `putovanja_istorija` tabeli
3. `mesecnaKarta = false` za dnevne putnike

```dart
// Mesečna karta = true za radnik/ucenik, false za dnevni
final isMesecnaKarta = selectedPutnik!.tip != 'dnevni';

final putnik = Putnik(
  ime: selectedPutnik!.putnikIme,
  polazak: _selectedVreme,
  grad: _selectedGrad,
  dan: _getDayAbbreviation(_selectedDay),
  mesecnaKarta: isMesecnaKarta,  // false za dnevni
  ...
);
```

#### B) Direktno dodavanje u putovanja_istorija
```dart
await supabase.from('putovanja_istorija').insert(insertData);
```

### `putovanja_istorija_service.dart` - Metoda za dodavanje
```dart
static Future<PutovanjaIstorija?> dodajPutovanjeDnevnogPutnika({
  required String putnikIme,
  required DateTime datum,
  required String vremePolaska,
  required String adresaPolaska,
  String? brojTelefona,
  String status = 'radi',
  double cena = 0.0,  // ⚠️ Default je 0!
}) async {
  final putovanje = PutovanjaIstorija(
    tipPutnika: 'dnevni',
    ...
    napomene: 'Dnevni putnik',
  );
}
```

---

## 6. 📊 Statistike i dužnici

### Definicija dužnika (`statistika_service.dart`)
```dart
/// Dužnik = SAMO DNEVNI putnik koji je pokupljen ali nije platio (cena == null || 0)
```

### Stream dužnika
```dart
static Stream<int> streamBrojDuznikaZaVozaca(String vozac, {...}) {
  return data.where((item) {
    // ✅ SAMO DNEVNI PUTNICI - isključi mesečne
    final tipPutnika = item['tip_putnika'] as String?;
    final jeDnevni = tipPutnika == 'dnevni';
    if (!jeDnevni) return false;

    // Nije platio
    final cena = item['cena'] as num?;
    final nijePlatio = cena == null || cena == 0;

    // Je pokupljen
    final jePokupljen = status == 'pokupljen';

    return jeDnevni && nijePlatio && nijeOtkazan && nijeObrisan && jePokupljen && jeDanas;
  }).length;
}
```

### Logika
- Samo dnevni putnici mogu biti "dužnici"
- Dužnik = pokupljen putnik sa cenom 0 ili null
- Mesečni putnici se isključuju iz ove statistike

---

## 7. ⚠️ Pronađeni problemi

### Problem 1: Validacija ne uključuje 'dnevni'
**Lokacija:** `lib/models/mesecni_putnik.dart`, linija 428  
**Opis:** Metoda `validateFull()` ne prepoznaje `'dnevni'` kao validan tip
```dart
if (tip.isEmpty || !['radnik', 'ucenik'].contains(tip)) {
  errors['tip'] = 'Tip mora biti "radnik" ili "ucenik"';
}
```
**Preporučena ispravka:**
```dart
if (tip.isEmpty || !['radnik', 'ucenik', 'dnevni'].contains(tip)) {
  errors['tip'] = 'Tip mora biti "radnik", "ucenik" ili "dnevni"';
}
```

### Problem 2: Default cena je 0 bez upozorenja
**Lokacija:** `lib/services/cena_obracun_service.dart`  
**Opis:** Dnevni putnici nemaju default cenu, što može dovesti do grešaka u obračunu  
**Preporuka:** Dodati upozorenje ili validaciju pri kreiranju dnevnog putnika bez cene

### Problem 3: Cena po danu sekcija unutar učeničkog bloka
**Lokacija:** `lib/widgets/mesecni_putnik_dialog.dart`, linije 478-532  
**Opis:** Sekcija za cenu po danu je **unutar** `if (_tip == 'ucenik')` bloka, tako da se ne prikazuje za dnevne putnike direktno  
**Status:** Potrebna detaljnija analiza - moguće da je namerno

---

## 8. ✅ Šta radi ispravno

1. ✅ Filtriranje po tipu "dnevni" funkcioniše korektno
2. ✅ UI prikazuje narandžastu boju i ikonu `Icons.today`
3. ✅ Dnevni putnici se ispravno čuvaju u `putovanja_istorija` tabeli
4. ✅ Statistika dužnika ispravno filtrira samo dnevne putnike
5. ✅ `mesecnaKarta = false` se ispravno postavlja za dnevne
6. ✅ Stream kombinovanih putnika pravilno učitava dnevne iz istorije
7. ✅ Dropdown u home_screen uključuje dnevne putnike

---

## 9. 📋 Razlike između dnevnog i mesečnog putnika

| Aspekt | Dnevni | Mesečni (radnik/učenik) |
|--------|--------|-------------------------|
| Tabela za profil | `mesecni_putnici` | `mesecni_putnici` |
| Tabela za putovanja | `putovanja_istorija` | `mesecni_putnici` + override u `putovanja_istorija` |
| Cena po danu | 0 RSD (custom obavezna) | 700/600 RSD |
| `mesecnaKarta` | `false` | `true` |
| Može biti dužnik | ✅ Da | ❌ Ne |
| Roditeljski kontakti | ❌ Ne | ✅ Da (učenici) |
| Škola/Ustanova | ❌ Ne | ✅ Da (učenici) |
| Boja | Narandžasta | Plava/Zelena |

---

## 10. 🔄 Tok podataka za dnevnog putnika

```
1. REGISTRACIJA (opciono):
   mesecni_putnici (tip='dnevni')
         │
         ▼
2. IZBOR IZ DROPDOWN-A (home_screen):
   selectedPutnik.tip == 'dnevni'
         │
         ▼
3. KREIRANJE PUTOVANJA:
   Putnik(mesecnaKarta: false)
         │
         ▼
4. ČUVANJE U BAZU:
   putovanja_istorija (tip_putnika='dnevni')
         │
         ▼
5. PRIKAZ:
   streamPutnici() → filtrira po datum_putovanja
```

---

## 11. 📋 Preporuke za dalje akcije

1. **[KRITIČNO]** Ispraviti validaciju da uključi `'dnevni'` tip
2. **[VAŽNO]** Razmotriti prikaz sekcije za cenu po danu za dnevne putnike
3. **[OPCIONO]** Dodati upozorenje ako se dodaje dnevni putnik bez cene
4. **[OPCIONO]** Dodati validaciju da dnevni putnik mora imati cenu > 0 pri plaćanju
5. **[INFO]** Dokumentovati dualnu prirodu dnevnih putnika (profil vs. pojedinačna putovanja)

---

*Izveštaj generisan automatski od strane analize koda.*
