# Plan: Optimizacija sistema za rutiranje

Implementacija 9 poboljšanja sistema optimizacije ruta kroz centralizaciju koda, ispravke grešaka i performance optimizacije.

## Steps

### Step 1: Kreirati `lib/config/route_config.dart`
**Prioritet: 1 (Kritično)**

Centralizovana konfiguracija sa:
- Lista dozvoljenih gradova (Vršac opština, Bela Crkva opština)
- Koordinate centara gradova (sa tolerancijom)
- Timeout vrednosti za sve servise
- Retry parametri (maxRetries, backoff multiplier)
- Granice regiona za offline mapu

```dart
// Primer strukture:
class RouteConfig {
  static const List<String> dozvonjeniGradovi = ['Bela Crkva', 'Vršac'];
  static const Map<String, LatLng> centriGradova = {...};
  static const Duration osrmTimeout = Duration(seconds: 8);
  static const int maxRetries = 3;
}
```

---

### Step 2: Ispraviti OSRM parsiranje u `lib/services/osrm_service.dart`
**Prioritet: 1 (Kritično)**

Trenutni bug:
```dart
// ❌ POGREŠNO - waypoint_index je originalni index, ne optimalni redosled
sortedWaypoints.sort((a, b) => 
    (a['waypoint_index'] as int).compareTo(b['waypoint_index'] as int));
```

Ispravka:
```dart
// ✅ ISPRAVNO - koristiti trips[0].legs za optimalni redosled
final legs = trips[0]['legs'] as List;
// legs[i] ide od waypoint[i] do waypoint[i+1]
// Redosled je: start -> leg[0].end -> leg[1].end -> ... -> leg[n-1].end
```

Dodatno:
- Smanjiti timeout sa 15s na 8s
- Dodati retry logiku sa exponential backoff (500ms, 1000ms, 2000ms)
- Dodati validaciju OSRM odgovora

---

### Step 3: Kreirati `lib/services/unified_geocoding_service.dart`
**Prioritet: 1 (Kritično)**

Centralizovati geocoding iz:
- `OsrmService.getCoordinatesForPutnici()` 
- `SmartNavigationService._getCoordinatesForPutnici()`
- `GeocodingService.getKoordinateZaAdresu()`
- `OfflineMapService.geocodeOffline()`

Funkcionalnosti:
- Paralelni fetch sa `Future.wait()` (max 5 concurrent)
- Prioritetni redosled: Baza → Memory Cache → Disk Cache → Nominatim API
- Automatsko čuvanje u bazu nakon Nominatim poziva
- Progress callback za UI

---

### Step 4: Ažurirati `lib/services/osrm_service.dart`
**Prioritet: 2 (Važno)**

Refaktorisati da koristi:
- `RouteConfig` za konstante
- `UnifiedGeocodingService` za koordinate
- Poboljšanu validaciju OSRM odgovora

---

### Step 5: Ažurirati `lib/services/smart_navigation_service.dart`
**Prioritet: 2 (Važno)**

- Ukloniti duplirani `_getCoordinatesForPutnici()` (~100 linija)
- Koristiti `UnifiedGeocodingService.getCoordinatesForPutnici()`
- Koristiti `RouteConfig` za konstante

---

### Step 6: Ažurirati `lib/screens/danas_screen.dart`
**Prioritet: 2 (Važno)**

Trenutno:
```dart
body: _isLoading
    ? const Center(child: CircularProgressIndicator())
```

Poboljšanje:
```dart
body: _isLoading
    ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage), // "Optimizujem rutu...", "Geocodiram adrese..."
          ],
        ),
      )
```

---

### Step 7: Dodati 2-opt improvement
**Prioritet: 3 (Nice to have)**

U `UnifiedGeocodingService` fallback optimizaciji:

```dart
/// 2-opt improvement algoritam
/// Poboljšava Nearest Neighbor rutu za 10-15%
static List<Putnik> _twoOptImprovement(
  List<Putnik> route,
  Map<Putnik, Position> coordinates,
) {
  bool improved = true;
  while (improved) {
    improved = false;
    for (int i = 0; i < route.length - 1; i++) {
      for (int j = i + 2; j < route.length; j++) {
        // Swap edges i→i+1 i j→j+1
        // Ako je nova ruta kraća, zadrži je
      }
    }
  }
  return route;
}
```

---

### Step 8: Kreirati `lib/services/background_geocoding_service.dart`
**Prioritet: 3 (Nice to have)**

Implementirati precompute koordinata:
- WorkManager za background job (jednom dnevno)
- Batch geocoding svih adresa bez koordinata
- Notifikacija vozaču kada je završeno

---

## Further Considerations

1. **Offline OSRM:** Da li želiš da implementiram lokalni OSRM server kao Android Service? To zahteva ~300MB storage za mapu Srbije.

2. **Migracija postojećeg koda:** Da li da odmah ažuriram sve reference na stare hardkodirane konstante, ili da ostavim backwards compatibility?

3. **Testiranje:** Da li da napišem unit testove za nove servise, posebno za OSRM parsiranje i 2-opt algoritam?

---

## Fajlovi koji će biti kreirani/izmenjeni

### Novi fajlovi:
- `lib/config/route_config.dart`
- `lib/services/unified_geocoding_service.dart`
- `lib/services/background_geocoding_service.dart`

### Izmenjeni fajlovi:
- `lib/services/osrm_service.dart`
- `lib/services/smart_navigation_service.dart`
- `lib/services/geocoding_service.dart`
- `lib/screens/danas_screen.dart`
- `lib/services/offline_map_service.dart`
- `lib/widgets/putnik_card.dart`

---

## Očekivani rezultati

| Poboljšanje | Efekat |
|------------|--------|
| Centralizacija gradova | Lakše održavanje, nema duplikacije |
| OSRM fix | Ispravne optimizovane rute |
| Paralelni geocoding | 3-5x brže geocodiranje |
| Retry logika | Veća pouzdanost na slaboj mreži |
| 2-opt improvement | 10-15% kraće rute |
| Progress UI | Bolje korisničko iskustvo |
