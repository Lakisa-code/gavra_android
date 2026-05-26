# V3 Vozač Akcije Sistem

## Opis
Novi sistem za praćenje svih akcija vozača u aplikaciji. Zamenjuje komplikovano logiku iz `v3_finansije` tabele sa jednostavnom i jasnom strukturom.

## Tabela: v3_vozac_akcije

### Kolone
- `id` (TEXT PRIMARY KEY) - Jedinstveni ID akcije
- `vozac_id` (TEXT NOT NULL) - ID vozača koji je izvršio akciju
- `vozac_ime` (TEXT NOT NULL) - Ime vozača
- `datum` (TIMESTAMP NOT NULL) - Datum i vreme akcije
- `tip_akcije` (TEXT NOT NULL) - Tip akcije: 'pokupio' ili 'naplata'
- `putnik_id` (TEXT NOT NULL) - ID putnika
- `putnik_ime` (TEXT NOT NULL) - Ime putnika
- `iznos` (DECIMAL(10,2)) - Iznos naplate (samo za 'naplata' akcije)
- `created_at` (TIMESTAMP) - Kada je kreiran zapis
- `created_by` (TEXT) - Ko je kreirao zapis

### Tipovi Akcija
1. **'pokupio'** - Vozač je pokupio putnika
2. **'naplata'** - Vozač je naplatio putniku

## Komponente Sistema

### 1. Model (`V3VozacAkcija`)
- Lokacija: `lib/models/v3_vozac_akcije.dart`
- Sadrži sve polja tabele i metode za konverziju JSON/objekat

### 2. Repository (`V3VozacAkcijeRepository`)
- Lokacija: `lib/services/v3/repositories/v3_vozac_akcije_repository.dart`
- Komunikacija sa bazom podataka
- CRUD operacije
- Specijalizovani upiti (po vozaču, po datumu, po tipu akcije)

### 3. Service (`V3VozacAkcijeService`)
- Lokacija: `lib/services/v3/v3_vozac_akcije_service.dart`
- Business logika
- Metode za evidentiranje akcija
- Korišćenje cache-a za brz pristup

### 4. Integracija sa Realtime Manager
- Dodata u `V3MasterRealtimeManager`
- Automatsko sinhronizovanje podataka
- Realtime update-i na klijentu

## Korišćenje

### Evidentiranje pokupljenog putnika
```dart
await V3VozacAkcijeService.evidentirajPokupio(
  vozacId: 'vozac_123',
  vozacIme: 'Petar Petrović',
  putnikId: 'putnik_456',
  putnikIme: 'Marko Marković',
  datum: DateTime.now(),
  evidentiraoBy: 'admin_id',
);
```

### Evidentiranje naplate
```dart
await V3VozacAkcijeService.evidentirajNaplata(
  vozacId: 'vozac_123',
  vozacIme: 'Petar Petrović',
  putnikId: 'putnik_456',
  putnikIme: 'Marko Marković',
  iznos: 1500.0,
  datum: DateTime.now(),
  evidentiraoBy: 'admin_id',
);
```

### Dobavljanje izveštaja za vozača i dan
```dart
final izvestaj = V3VozacAkcijeService.getIzvestajZaVozacaDan(
  vozacId: 'vozac_123',
  dan: DateTime.now(),
);

print('Pokupio: ${izvestaj.brojPokupljenih}');
print('Naplate: ${izvestaj.brojNaplata}');
print('Ukupan iznos: ${izvestaj.ukupanIznos}');
```

## Automatska Integracija

Sistem je integrisan sa postojećim metodama:

1. **`V3FinansijeService.evidentirajRealizacijuPriPokupljanju()`**
   - Automatski evidentira 'pokupio' akciju
   - Koristi `evidentiraoBy` parametar

2. **`V3FinansijeService.sacuvajMesecnuNaplatu()`**
   - Automatski evidentira 'naplata' akciju
   - Koristi trenutni datum za naplatu

## Dnevnik Naplate Ekran

Ažuriran da koristi novi sistem:

- Prikazuje i pokupljene putnike i naplate
- Realtime update kada se dodaju nove akcije
- PDF export sa obe sekcije
- Clipboard share sa detaljnim izveštajem

## Prednosti

1. **Jasna struktura** - Svaka akcija je poseban zapis
2. **Puna istorija** - Sve akcije su sačuvane sa vremenom
3. **Brzi upiti** - Optimizovani indeksi za brz pristup
4. **Realtime sinhronizacija** - Automatski update-i
5. **Jednostavno proširenje** - Lako dodati nove tipove akcija

## Migracija

Postojeći podaci iz `v3_finansije` se i dalje koriste za mesečne izveštaje i dugovanja, dok se nove akcije evidentiraju u `v3_vozac_akcije` tabelu. Ovo omogućava postepenu migraciju bez gubitka podataka.
