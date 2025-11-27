import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import 'adresa_supabase_service.dart'; // 🎯 DODANO za koordinate iz baze
import 'geocoding_service.dart';
import 'osrm_service.dart'; // 🗺️ OSRM za optimizaciju ruta

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OSRM (OpenStreetMap Routing Machine) za pravu optimizaciju ruta
class SmartNavigationService {
  /// 🎯 SAMO OPTIMIZACIJA RUTE (bez otvaranja mape) - za "Pokreni" dugme
  static Future<NavigationResult> optimizeRouteOnly({
    required List<Putnik> putnici,
    required String startCity,
    bool optimizeForTime = true,
  }) async {
    print('');
    print('🚀🚀🚀 ===== OPTIMIZE ROUTE ONLY (OSRM) ===== 🚀🚀🚀');
    print('🚀 Broj putnika: ${putnici.length}');
    print('🚀 Start city: $startCity');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();
      print('📍 VOZAČ POZICIJA: lat=${currentPosition.latitude}, lng=${currentPosition.longitude}');

      // 2. 🗺️ KORISTI OSRM ZA OPTIMIZACIJU
      final osrmResult = await OsrmService.optimizeRoute(
        startPosition: currentPosition,
        putnici: putnici,
      );

      if (osrmResult.success && osrmResult.optimizedPutnici != null) {
        print('✅ OSRM optimizacija uspešna');
        
        // Nađi preskočene putnike
        final skipped = putnici.where((p) => 
            !osrmResult.optimizedPutnici!.contains(p)).toList();

        return NavigationResult.success(
          message: '✅ Ruta optimizovana (OSRM)',
          optimizedPutnici: osrmResult.optimizedPutnici!,
          totalDistance: osrmResult.totalDistanceKm,
          skippedPutnici: skipped.isNotEmpty ? skipped : null,
        );
      }

      // 3. FALLBACK: Ako OSRM ne radi, koristi staru metodu
      print('⚠️ OSRM nije dostupan, koristim fallback');
      
      final Map<Putnik, Position> coordinates = await _getCoordinatesForPutnici(putnici);
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // Fallback na Nearest Neighbor
      final optimizedRoute = await OsrmService.fallbackOptimization(
        startPosition: currentPosition,
        putnici: putnici,
        coordinates: coordinates,
      );

      return NavigationResult.success(
        message: '✅ Ruta optimizovana (lokalno)',
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
  /// 🎯 skipOptimization=true: koristi prosleđenu listu bez re-optimizacije (za NAV dugme)
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity, // 'Bela Crkva' ili 'Vršac'
    bool optimizeForTime = true, // true = vreme, false = distanca
    bool useTrafficData = false, // 🚦 NOVO: traffic-aware routing
    bool skipOptimization = true, // 🎯 NOVO: preskoči re-optimizaciju ako je ruta već optimizovana
  }) async {
    print('');
    print('🗺️🗺️🗺️ ===== START NAVIGATION (OSRM) ===== 🗺️🗺️🗺️');
    print('🗺️ Broj putnika: ${putnici.length}');
    print('🗺️ Start city: $startCity');
    print('🗺️ skipOptimization: $skipOptimization');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. OPTIMIZUJ REDOSLED PUTNIKA (ili koristi već optimizovanu listu)
      List<Putnik> optimizedRoute;
      double? totalDistanceKm;

      if (skipOptimization) {
        // 🎯 KORISTI VEĆ OPTIMIZOVANU LISTU (od "Ruta" dugmeta)
        print('🎯 Koristi već optimizovanu rutu (skipOptimization=true)');
        optimizedRoute = putnici;
      } else {
        // 🗺️ KORISTI OSRM ZA OPTIMIZACIJU
        final osrmResult = await OsrmService.optimizeRoute(
          startPosition: currentPosition,
          putnici: putnici,
        );

        if (osrmResult.success && osrmResult.optimizedPutnici != null) {
          optimizedRoute = osrmResult.optimizedPutnici!;
          totalDistanceKm = osrmResult.totalDistanceKm;
          print('✅ OSRM optimizacija uspešna: ${totalDistanceKm?.toStringAsFixed(1)} km');
        } else {
          // Fallback na staru metodu
          final coordinates = await _getCoordinatesForPutnici(putnici);
          if (coordinates.isEmpty) {
            return NavigationResult.error('❌ Nijedan putnik nema validnu adresu');
          }
          optimizedRoute = await OsrmService.fallbackOptimization(
            startPosition: currentPosition,
            putnici: putnici,
            coordinates: coordinates,
          );
        }
      }

      // 3. OTVORI RUTU U GOOGLE MAPS SA WAYPOINT-IMA (max 10)
      final success = await _openGoogleMapsNavigation(
        currentPosition,
        optimizedRoute,
        startCity,
        useTrafficData: useTrafficData,
      );

      // Informacija o broju putnika
      final maxWaypoints = 10;
      final shownCount = optimizedRoute.length > maxWaypoints ? maxWaypoints : optimizedRoute.length;
      final remainingCount = optimizedRoute.length > maxWaypoints ? optimizedRoute.length - maxWaypoints : 0;

      if (success) {
        String message = '🎯 Google Maps: $shownCount putnika';
        if (remainingCount > 0) {
          message += ' (još $remainingCount posle)';
        }
        return NavigationResult.success(
          message: message,
          optimizedPutnici: optimizedRoute,
          totalDistance: totalDistanceKm,
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

  // 🗺️ TSP METODE UKLONJENE - sada koristi OsrmService za optimizaciju

  /// 📐 Izračunaj distancu između dve pozicije (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🗺️ Otvori Google Maps sa svim putnicima
  /// Google sam optimizuje rutu - uzima u obzir puteve, saobraćaj, jednosmerne ulice
  static Future<bool> _openGoogleMapsNavigation(
    Position startPosition,
    List<Putnik> optimizedRoute,
    String startCity, {
    bool useTrafficData = false,
  }) async {
    try {
      if (optimizedRoute.isEmpty) {
        print('❌ Nema putnika za navigaciju');
        return false;
      }

      // 🎯 Google Maps podržava max 10 waypoint-a
      final maxWaypoints = 10;
      final putnici = optimizedRoute.take(maxWaypoints).toList();
      
      print('🗺️ Otvaram Google Maps sa ${putnici.length} putnika');

      // 🎯 Dobij koordinate za sve putnike
      final coordinates = await _getCoordinatesForPutnici(putnici);
      
      if (coordinates.isEmpty) {
        print('❌ Nema koordinata za putnike');
        return false;
      }

      // 🎯 Kreiraj Google Maps URL sa svim putnicima
      // Format: /dir/origin/wp1/wp2/.../destination
      String googleMapsUrl = 'https://www.google.com/maps/dir/${startPosition.latitude},${startPosition.longitude}';

      for (final putnik in putnici) {
        if (coordinates.containsKey(putnik)) {
          final pos = coordinates[putnik]!;
          googleMapsUrl += '/${pos.latitude},${pos.longitude}';
          print('   📍 ${putnik.ime}: ${pos.latitude},${pos.longitude}');
        }
      }

      googleMapsUrl += '?travelmode=driving';

      print('🗺️ Google Maps URL: $googleMapsUrl');

      final Uri uri = Uri.parse(googleMapsUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched && optimizedRoute.length > maxWaypoints) {
          print('⚠️ Ima još ${optimizedRoute.length - maxWaypoints} putnika posle ovih ${maxWaypoints}');
        }
        
        return launched;
      } else {
        throw Exception('Ne mogu da otvorim Google Maps');
      }
    } catch (e) {
      print('❌ Greška pri otvaranju Google Maps: $e');
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
      if (coordinates.containsKey(putnik)) {
        final nextPos = coordinates[putnik]!;
        totalDistance += _calculateDistance(currentPos, nextPos);
        currentPos = nextPos;
      }
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
