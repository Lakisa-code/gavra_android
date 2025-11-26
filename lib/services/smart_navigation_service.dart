import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import 'adresa_supabase_service.dart'; // 🎯 DODANO za koordinate iz baze
import 'geocoding_service.dart';

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OpenStreetMap / self-hosted OSRM/Valhalla ili platform-specific aplikacije za otvaranje rute.
class SmartNavigationService {
  /// 🎯 SAMO OPTIMIZACIJA RUTE (bez otvaranja mape) - za "Pokreni" dugme
  static Future<NavigationResult> optimizeRouteOnly({
    required List<Putnik> putnici,
    required String startCity,
    bool optimizeForTime = true,
  }) async {
    print('');
    print('🚀🚀🚀 ===== OPTIMIZE ROUTE ONLY STARTED ===== 🚀🚀🚀');
    print('🚀 Broj putnika: ${putnici.length}');
    print('🚀 Start city: $startCity');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. DOBIJ KOORDINATE ZA SVE ADRESE
      final Map<Putnik, Position> coordinates = await _getCoordinatesForPutnici(putnici);

      // 🆕 Nađi preskočene putnike (nemaju koordinate)
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // 3. OPTIMIZUJ REDOSLED PUTNIKA
      final optimizedRoute = await _optimizeRoute(
        startPosition: currentPosition,
        coordinates: coordinates,
        optimizeForTime: optimizeForTime,
      );

      // 4. VRATI OPTIMIZOVANU RUTU BEZ OTVARANJA MAPE
      return NavigationResult.success(
        message: '✅ Ruta optimizovana',
        optimizedPutnici: optimizedRoute,
        totalDistance: await _calculateTotalDistance(
          currentPosition,
          optimizedRoute,
          coordinates,
        ),
        skippedPutnici: skipped.isNotEmpty ? skipped : null,
      );
    } catch (e) {
      return NavigationResult.error('❌ Greška pri optimizaciji: $e');
    }
  }

  /// 🚗 GLAVNA FUNKCIJA - Otvori mapu sa optimizovanom rutom (preferirano OSM/OSRM)
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity, // 'Bela Crkva' ili 'Vršac'
    bool optimizeForTime = true, // true = vreme, false = distanca
    bool useTrafficData = false, // 🚦 NOVO: traffic-aware routing
  }) async {
    print('');
    print('🗺️🗺️🗺️ ===== START OPTIMIZED NAVIGATION ===== 🗺️🗺️🗺️');
    print('🗺️ Broj putnika: ${putnici.length}');
    print('🗺️ Start city: $startCity');
    print('🗺️ useTrafficData: $useTrafficData');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. DOBIJ KOORDINATE ZA SVE ADRESE
      final Map<Putnik, Position> coordinates = await _getCoordinatesForPutnici(putnici);

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // 3. OPTIMIZUJ REDOSLED PUTNIKA
      List<Putnik> optimizedRoute;

      if (useTrafficData) {
        // 🚦 TRAFFIC-AWARE OPTIMIZACIJA

        // DISABLED: Google APIs too expensive - use standard optimization instead
        optimizedRoute = await _optimizeRoute(
          startPosition: currentPosition,
          coordinates: coordinates,
          optimizeForTime: optimizeForTime,
        );
      } else {
        // 🎯 STANDARDNA TSP OPTIMIZACIJA
        optimizedRoute = await _optimizeRoute(
          startPosition: currentPosition,
          coordinates: coordinates,
          optimizeForTime: optimizeForTime,
        );
      }

      // 4. OTVORI RUTU U PREFERIRANOJ NAVIGACIONOJ APLIKACIJI (OpenStreetMap/OSM)
      final success = await _openOSMNavigation(
        currentPosition,
        optimizedRoute,
        startCity,
        useTrafficData: useTrafficData, // 🚦 Prosledi traffic parametar
      );

      if (success) {
        return NavigationResult.success(
          message: '🎯 Navigacija pokrenuta sa ${optimizedRoute.length} putnika',
          optimizedPutnici: optimizedRoute,
          totalDistance: await _calculateTotalDistance(
            currentPosition,
            optimizedRoute,
            coordinates,
          ),
        );
      } else {
        return NavigationResult.error('❌ Greška pri otvaranju navigacije');
      }
    } catch (e) {
      return NavigationResult.error('❌ Greška pri navigaciji: $e');
    }
  }

  /// 📍 Dobij trenutnu GPS poziciju vozača
  static Future<Position> _getCurrentPosition() async {
    // Proveri da li je GPS uključen
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      // Otvori sistemski dialog za uključivanje GPS-a (jedan klik!)
      isLocationEnabled = await Geolocator.openLocationSettings();
      
      // Sačekaj malo da se GPS uključi
      await Future.delayed(const Duration(seconds: 2));
      
      // Proveri ponovo
      isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        throw Exception('GPS nije uključen');
      }
    }

    // Dozvole su već odobrene pri instalaciji, ali proveri za svaki slučaj
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      throw Exception('GPS dozvole nisu odobrene');
    }

    // Dobij poziciju sa visokom tačnošću
    return await Geolocator.getCurrentPosition();
  }

  /// 🗺️ Dobij koordinate za sve putnike
  /// 🎯 OPTIMIZOVANO: Prvo proverava bazu, pa tek onda Nominatim API
  static Future<Map<Putnik, Position>> _getCoordinatesForPutnici(
    List<Putnik> putnici,
  ) async {
    final Map<Putnik, Position> coordinates = {};

    print('🗺️ === GEOCODING DEBUG ===');
    print('🗺️ Broj putnika za geocoding: ${putnici.length}');

    // 🎯 Koordinate centra gradova - ako adresa ima ove koordinate, treba geocodirati po nazivu
    const double belaCrkvaLat = 44.9013448;
    const double belaCrkvaLng = 21.4240519;
    const double vrsacLat = 45.1167;
    const double vrsacLng = 21.3;
    const double tolerance = 0.001; // ~100m tolerancija

    bool isCityCenterCoordinate(double? lat, double? lng) {
      if (lat == null || lng == null) return false;
      // Proveri da li je centar Bele Crkve
      if ((lat - belaCrkvaLat).abs() < tolerance && (lng - belaCrkvaLng).abs() < tolerance) return true;
      // Proveri da li je centar Vršca
      if ((lat - vrsacLat).abs() < tolerance && (lng - vrsacLng).abs() < tolerance) return true;
      return false;
    }

    for (final putnik in putnici) {
      if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) {
        print('⚠️ ${putnik.ime}: NEMA ADRESU - preskačem');
        continue;
      }

      print('📍 ${putnik.ime}: adresa="${putnik.adresa}", grad="${putnik.grad}", adresaId="${putnik.adresaId}"');

      try {
        Position? position;
        String? realAddressName; // Pravi naziv adrese iz baze

        // 🎯 PRIORITET 1: Učitaj adresu iz baze da dobijemo NAZIV (ulica, broj)
        if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
          final adresaFromDb = await AdresaSupabaseService.getAdresaByUuid(putnik.adresaId!);
          if (adresaFromDb != null) {
            realAddressName = adresaFromDb.naziv; // npr. "Proleterska 35"
            print('   📫 Naziv adrese iz baze: "$realAddressName"');
            
            // Proveri da li ima SPECIFIČNE koordinate (ne centar grada)
            if (adresaFromDb.latitude != null && 
                adresaFromDb.longitude != null &&
                !isCityCenterCoordinate(adresaFromDb.latitude, adresaFromDb.longitude)) {
              position = Position(
                latitude: adresaFromDb.latitude!,
                longitude: adresaFromDb.longitude!,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              );
              print('   ✅ IZ BAZE (specifične koordinate): lat=${adresaFromDb.latitude}, lng=${adresaFromDb.longitude}');
            } else {
              print('   ⚠️ Koordinate su centar grada - treba geocodirati po nazivu');
            }
          } else {
            print('   ⚠️ adresaId postoji ali adresa nije nađena u bazi');
          }
        }

        // 🎯 PRIORITET 2: Ako nema specifične koordinate, geocodiraj po PRAVOM nazivu adrese
        if (position == null) {
          // Koristi pravi naziv adrese ako postoji, inače fallback na putnik.adresa
          final addressToGeocode = realAddressName ?? putnik.adresa!;
          final improvedAddress = _improveAddressForGeocoding(addressToGeocode, putnik.grad);
          print('   🔍 Nominatim API: "$improvedAddress"');

          // Dobij koordinate preko GeocodingService
          final coordsString = await GeocodingService.getKoordinateZaAdresu(
            putnik.grad,
            improvedAddress,
          );

          if (coordsString != null && coordsString.contains(',')) {
            final parts = coordsString.split(',');
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());

            if (lat != null && lng != null) {
              position = Position(
                latitude: lat,
                longitude: lng,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              );
              print('   ✅ IZ NOMINATIM: lat=$lat, lng=$lng');

              // 🎯 BONUS: Sačuvaj koordinate u bazu za sledeći put
              await _saveCoordinatesToDatabase(
                putnik: putnik,
                lat: lat,
                lng: lng,
              );
            } else {
              print('   ❌ Nominatim vratio nevalidan format: $coordsString');
            }
          } else {
            print('   ❌ Nominatim nije našao koordinate');
          }
        }

        if (position != null) {
          coordinates[putnik] = position;
        } else {
          print('   ❌ NEMA KOORDINATE - putnik će biti preskočen u optimizaciji!');
        }
      } catch (e) {
        print('   ❌ GREŠKA: $e');
      }
    }

    print('🗺️ === GEOCODING REZULTAT ===');
    print('🗺️ Uspešno geocodirano: ${coordinates.length}/${putnici.length} putnika');
    for (final entry in coordinates.entries) {
      print('   📍 ${entry.key.ime}: (${entry.value.latitude}, ${entry.value.longitude})');
    }
    print('🗺️ ========================');

    return coordinates;
  }

  /// 🎯 Sačuvaj koordinate u bazu za buduće korišćenje
  static Future<void> _saveCoordinatesToDatabase({
    required Putnik putnik,
    required double lat,
    required double lng,
  }) async {
    try {
      // Ako putnik već ima adresaId, ažuriraj koordinate
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        await AdresaSupabaseService.updateKoordinate(
          putnik.adresaId!,
          lat: lat,
          lng: lng,
        );
        return;
      }

      // Ako nema adresaId, kreiraj novu adresu sa koordinatama
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        await AdresaSupabaseService.createOrGetAdresa(
          naziv: putnik.adresa!,
          grad: putnik.grad,
          lat: lat,
          lng: lng,
        );
      }
    } catch (e) {
      // Ignoriši greške - koordinate će se ponovo dohvatiti sledeći put
    }
  }

  /// 🎯 Optimizuj redosled putnika (TSP algoritam)
  static Future<List<Putnik>> _optimizeRoute({
    required Position startPosition,
    required Map<Putnik, Position> coordinates,
    bool optimizeForTime = true,
  }) async {
    final putnici = coordinates.keys.toList();

    if (putnici.length <= 1) return putnici;

    // Za manje od 8 putnika koristi brute force, inače nearest neighbor
    if (putnici.length <= 8) {
      return await _bruteForceOptimization(
        startPosition,
        coordinates,
        optimizeForTime,
      );
    } else {
      return await _nearestNeighborOptimization(
        startPosition,
        coordinates,
        optimizeForTime,
      );
    }
  }

  /// 🔥 Brute force optimizacija (za <= 8 putnika)
  static Future<List<Putnik>> _bruteForceOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    final putnici = coordinates.keys.toList();
    double bestDistance = double.infinity;
    List<Putnik> bestRoute = [];

    // Generiši sve permutacije
    final permutations = _generatePermutations(putnici);

    for (final route in permutations) {
      final distance = await _calculateRouteDistance(
        start,
        route,
        coordinates,
        optimizeForTime,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestRoute = List.from(route);
      }
    }

    return bestRoute;
  }

  /// ⚡ Nearest neighbor optimizacija (za >8 putnika)
  static Future<List<Putnik>> _nearestNeighborOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    final unvisited = coordinates.keys.toList();
    final route = <Putnik>[];
    Position currentPosition = start;

    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      // Nađi najbliži neposećen grad
      for (final putnik in unvisited) {
        final distance = _calculateDistance(currentPosition, coordinates[putnik]!);
        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = putnik;
        }
      }

      if (nearest != null) {
        route.add(nearest);
        currentPosition = coordinates[nearest]!;
        unvisited.remove(nearest);
      }
    }

    return route;
  }

  /// 📊 Izračunaj ukupnu distancu rute
  static Future<double> _calculateRouteDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    if (route.isEmpty) return 0.0;

    double totalDistance = 0.0;
    Position currentPos = start;

    for (final putnik in route) {
      final nextPos = coordinates[putnik]!;
      totalDistance += _calculateDistance(currentPos, nextPos);
      currentPos = nextPos;
    }

    // Za optimizaciju vremena, dodaj penalty za gušće saobraćaj u određeno doba
    if (optimizeForTime) {
      final hour = DateTime.now().hour;
      double timePenalty = 1.0;

      // Rush hour penalties
      if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
        timePenalty = 1.3; // 30% duže u špicu
      } else if (hour >= 22 || hour <= 6) {
        timePenalty = 0.8; // 20% brže noću
      }

      totalDistance *= timePenalty;
    }

    return totalDistance;
  }

  /// 📐 Izračunaj distancu između dve pozicije (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🗺️ Otvori OpenStreetMap sa optimizovanom rutom
  static Future<bool> _openOSMNavigation(
    Position startPosition,
    List<Putnik> optimizedRoute,
    String startCity, {
    bool useTrafficData = false, // 🚦 DODATO za traffic parametere
  }) async {
    try {
      // Kreiraj OpenStreetMap URL za navigaciju (koristi osmand ili maps.me)
      String osmNavigationUrl = 'https://www.openstreetmap.org/directions?';

      // Dodaj početnu poziciju
      osmNavigationUrl += 'from=${startPosition.latitude}%2C${startPosition.longitude}';

      // Za OpenStreetMap, koristimo prvi i poslednji destination
      if (optimizedRoute.isNotEmpty) {
        final lastPutnik = optimizedRoute.last;
        if (lastPutnik.adresa != null && lastPutnik.adresa!.isNotEmpty) {
          final improvedAddress = _improveAddressForGeocoding(lastPutnik.adresa!, lastPutnik.grad);
          final encodedAddress = Uri.encodeComponent(
            '$improvedAddress, ${lastPutnik.grad}, Serbia',
          );
          osmNavigationUrl += '&to=$encodedAddress';
        }
      }

      // Dodaj parametre za navigaciju
      osmNavigationUrl += '&route=car';

      final Uri uri = Uri.parse(osmNavigationUrl);

      // Pokušaj da otvoriš OpenStreetMap ili navigaciju
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Otvori u navigacionoj aplikaciji
        );
      } else {
        throw Exception('Ne mogu da otvorim navigaciju');
      }
    } catch (e) {
      return false;
    }
  }

  /// 🛠️ Poboljšaj adresu za geocoding
  static String _improveAddressForGeocoding(String address, String grad) {
    // Normalizuj adresu
    String improved = address.trim();

    // Dodaj grad ako nije prisutan
    if (!improved.toLowerCase().contains(grad.toLowerCase()) &&
        !improved.toLowerCase().contains('serbia') &&
        !improved.toLowerCase().contains('srbija')) {
      improved = '$improved, $grad';
    }

    return improved;
  }

  /// 🔢 Generiši sve permutacije (za brute force)
  static List<List<Putnik>> _generatePermutations(List<Putnik> list) {
    if (list.length <= 1) return [list];

    final permutations = <List<Putnik>>[];

    for (int i = 0; i < list.length; i++) {
      final element = list[i];
      final remaining = [...list]..removeAt(i);

      for (final perm in _generatePermutations(remaining)) {
        permutations.add([element, ...perm]);
      }
    }

    return permutations;
  }

  /// 📊 Izračunaj ukupnu distancu optimizovane rute
  static Future<double> _calculateTotalDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) async {
    if (route.isEmpty) return 0.0;

    double totalDistance = 0.0;
    Position currentPos = start;

    for (final putnik in route) {
      final nextPos = coordinates[putnik]!;
      totalDistance += _calculateDistance(currentPos, nextPos);
      currentPos = nextPos;
    }

    return totalDistance / 1000; // Konvertuj u kilometre
  }
}

/// 📊 Rezultat navigacije
class NavigationResult {
  NavigationResult._({
    required this.success,
    required this.message,
    this.optimizedPutnici,
    this.totalDistance,
    this.skippedPutnici,
  });

  factory NavigationResult.success({
    required String message,
    required List<Putnik> optimizedPutnici,
    double? totalDistance,
    List<Putnik>? skippedPutnici,
  }) {
    return NavigationResult._(
      success: true,
      message: message,
      optimizedPutnici: optimizedPutnici,
      totalDistance: totalDistance,
      skippedPutnici: skippedPutnici,
    );
  }

  factory NavigationResult.error(String message) {
    return NavigationResult._(
      success: false,
      message: message,
    );
  }
  final bool success;
  final String message;
  final List<Putnik>? optimizedPutnici;
  final double? totalDistance;
  final List<Putnik>? skippedPutnici; // 🆕 Putnici bez koordinata
}
