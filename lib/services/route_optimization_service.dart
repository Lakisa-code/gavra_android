import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/text_utils.dart';

class _CacheEntry {
  _CacheEntry({required this.data, required this.expiry});
  final List<Putnik> data;
  final DateTime expiry;
}

class RouteOptimizationService {
  // 🎯 DOZVOLJENI GRADOVI za navigaciju - samo Bela Crkva i Vršac
  static const List<String> _dozvoljeninGradovi = ['Bela Crkva', 'Vršac'];

  /// 🎯 Filtriraj putnike samo za dozvoljene gradovi (Bela Crkva i Vršac opštine)
  static List<Putnik> filterByAllowedCities(List<Putnik> putnici) {
    return putnici.where((p) => _isPassengerInServiceArea(p)).toList();
  }

  /// 🚫 HELPER - proveri da li je putnik u BC/Vršac servisnoj oblasti
  static bool _isPassengerInServiceArea(Putnik putnik) {
    // Koristi centralizovanu normalizaciju iz TextUtils
    final normalizedGrad = TextUtils.normalizeText(putnik.grad);
    final normalizedAdresa = TextUtils.normalizeText(putnik.adresa ?? '');

    // ✅ SERVISNA OBLAST: SAMO Bela Crkva i Vršac opštine
    final serviceAreaCities = [
      // VRŠAC OPŠTINA
      'vrsac', 'straza', 'vojvodinci', 'potporanj', 'oresac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kusic', 'crvena crkva',
    ]; // Proveri grad ili adresu da li su u servisnoj oblasti
    return serviceAreaCities.any(
      (city) =>
          normalizedGrad.contains(city) ||
          city.contains(normalizedGrad) ||
          normalizedAdresa.contains(city) ||
          city.contains(normalizedAdresa),
    );
  }

  /// 🗺️ LEGACY: Geografska optimizacija
  /// ⚠️ DEPRECATED: Koristi SmartNavigationService.optimizeRouteOnly() umesto ove metode
  /// SmartNavigationService koristi OSRM za pravu TSP optimizaciju sa fallback na 2-opt
  @Deprecated('Koristi SmartNavigationService.optimizeRouteOnly() za bolju optimizaciju')
  static Future<List<Putnik>> optimizeRouteGeographically(
    List<Putnik> putnici, {
    Position? driverPosition, // Trenutna lokacija vozača
    String? startAddress, // Ili početna adresa kao fallback
  }) async {
    if (putnici.isEmpty) return putnici;

    // 🎯 FILTRIRAJ SAMO BELA CRKVA I VRŠAC gradove za navigaciju
    // Filtriraj samo aktivne putnike sa adresama iz dozvoljenih gradova
    final aktivniPutnici = putnici
        .where(
          (p) =>
              p.status != 'otkazan' &&
              p.status != 'Otkazano' &&
              p.adresa != null &&
              p.adresa!.isNotEmpty &&
              _dozvoljeninGradovi.any((grad) => p.adresa!.contains(grad)),
        )
        .toList();

    if (aktivniPutnici.isEmpty) return putnici;
    if (aktivniPutnici.length == 1) return aktivniPutnici;

    try {
      // 1. Određi početnu lokaciju
      Position? startLocation;

      if (driverPosition != null) {
        startLocation = driverPosition;
      } else if (startAddress != null) {
        // Geokodiraj početnu adresu u koordinate
        startLocation = await _geocodeAddress(startAddress);
      } else {
        // Pokušaj da dohvatiš trenutnu GPS lokaciju
        try {
          startLocation = await Geolocator.getCurrentPosition(
              // desiredAccuracy: deprecated, use settings parameter
              // timeLimit: const Duration(seconds: 5), // deprecated, use settings parameter
              );
        } catch (e) {
          return _fallbackToOriginalOrder(aktivniPutnici);
        }
      }

      if (startLocation == null) {
        return _fallbackToOriginalOrder(aktivniPutnici);
      }

      // 2. Geokodiraj sve adrese putnika u koordinate
      final putnikCoordinates = <Putnik, Position>{};

      for (final putnik in aktivniPutnici) {
        final coordinates = await _geocodeAddress(putnik.adresa!);
        if (coordinates != null) {
          putnikCoordinates[putnik] = coordinates;
        }
      }

      if (putnikCoordinates.isEmpty) {
        return _fallbackToOriginalOrder(aktivniPutnici);
      }

      // 3. Koristi Traveling Salesman Problem (TSP) algoritam
      final optimizedRoute = await _solveTSP(
        startLocation,
        putnikCoordinates,
      );

      return optimizedRoute;
    } catch (e) {
      return _fallbackToOriginalOrder(aktivniPutnici);
    }
  }

  /// 🌍 Geocoding uklonjen - koristi se lokalna optimizacija
  static Future<Position?> _geocodeAddress(String address) async {
    // 🔒 GOOGLE GEOCODING API UKLONJEN ZA BEZBEDNOST
    // Vraćamo null da se koristi lokalna optimizacija
    return null;
  }

  /// 🧮 Reši Traveling Salesman Problem (TSP) - Nearest Neighbor algoritam
  static Future<List<Putnik>> _solveTSP(
    Position start,
    Map<Putnik, Position> destinations,
  ) async {
    final List<Putnik> optimizedRoute = [];
    final unvisited = Set<Putnik>.from(destinations.keys);
    Position currentPosition = start;

    // Nearest Neighbor algoritam
    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      // Pronađi najbližu destinaciju
      for (final putnik in unvisited) {
        final distance = _calculateDistance(
          currentPosition,
          destinations[putnik]!,
        );

        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = putnik;
        }
      }

      if (nearest != null) {
        optimizedRoute.add(nearest);
        currentPosition = destinations[nearest]!;
        unvisited.remove(nearest);
      }
    }

    return optimizedRoute;
  }

  /// 📐 Izračunaj udaljenost između dve geografske tačke (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// � Jednostavno vrati originalni redosled ako GPS optimizacija ne uspe
  static List<Putnik> _fallbackToOriginalOrder(List<Putnik> putnici) {
    // Jednostavno vrati putnice u originalnom redosledu
    // Originalni redosled iz baze je često logičan i pošten (FIFO)
    return List<Putnik>.from(putnici);
  }

  // Optimizuj rutu za određeni polazak (specifično za grad i vreme)
  static Future<List<Putnik>> optimizeRoute(List<Putnik> putnici) async {
    if (putnici.isEmpty) return putnici;

    // Filtriraj samo one koji nisu otkazani
    final aktivniPutnici = putnici.where((p) => p.status != 'otkazan' && p.status != 'Otkazano').toList();

    if (aktivniPutnici.isEmpty) return putnici;

    // Zadržava originalni redosled iz baze umesto alfabetskog sortiranja
    // Originalni redosled često prati logiku unosa i registracije putnika
    // što je pravednije i prirodnije za vozače i putnike

    // Dodaj otkazane na kraj
    final otkazaniPutnici = putnici.where((p) => p.status == 'otkazan' || p.status == 'Otkazano').toList();

    return [...aktivniPutnici, ...otkazaniPutnici];
  }

  // NOVA FUNKCIJA: Optimizuj rutu za specifičan grad i vreme
  static Future<List<Putnik>> optimizeRouteForCityAndTime(
    List<Putnik> allPutnici,
    String grad,
    String vreme,
    String dan,
  ) async {
    if (allPutnici.isEmpty) return [];

    // 🎯 Dodatna sigurnost - proverava da je grad dozvoljeni
    if (!_dozvoljeninGradovi.contains(grad)) {
      return [];
    }

    // Filtriraj putnike samo za određeni grad, vreme i dan
    final normFilterTime = GradAdresaValidator.normalizeTime(vreme);

    final filteredPutnici = allPutnici.where((putnik) {
      // 🎯 DAN FILTER
      if (putnik.dan != dan) return false;

      // 🎯 VREME FILTER - koristi normalizaciju za konzistentnost
      final pTime = GradAdresaValidator.normalizeTime(putnik.polazak);
      if (pTime != normFilterTime) return false;

      // 🎯 GRAD FILTER - koristi GradAdresaValidator za konzistentnost
      final isRegistrovaniPutnik = putnik.mesecnaKarta == true;
      bool gradMatch;
      if (isRegistrovaniPutnik) {
        gradMatch = putnik.grad == grad;
      } else {
        gradMatch = GradAdresaValidator.isGradMatch(putnik.grad, putnik.adresa, grad);
      }
      if (!gradMatch) return false;

      // 🔄 UJEDNAČENA LOGIKA: Isti filter za mesečne i dnevne putnike
      // Isključuje: otkazane, bolovanje, godišnji, obrisane
      if (!TextUtils.isStatusActive(putnik.status)) return false;

      return true;
    }).toList();

    if (filteredPutnici.isEmpty) return [];

    // Optimizuj rutu samo za filtrirane putnike
    return await optimizeRoute(filteredPutnici);
  }

  // Izračunaj ukupnu distancu (simulacija) - ZASTARELO, koristi se nova geografska optimizacija
  static double calculateTotalDistance(List<Putnik> putnici) {
    if (putnici.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < putnici.length - 1; i++) {
      // Simulacija distance calculation
      final fromIdentifier = putnici[i].adresa ?? putnici[i].ime;
      final toIdentifier = putnici[i + 1].adresa ?? putnici[i + 1].ime;

      if (fromIdentifier.isEmpty || toIdentifier.isEmpty) {
        totalDistance += 1.0;
      } else {
        final diff = (fromIdentifier.length - toIdentifier.length).abs();
        totalDistance += diff * 0.5 + Random().nextDouble() * 2;
      }
    }
    return totalDistance;
  }

  // Generiši rutu string za prikaz
  static Future<String> generateRouteString(List<Putnik> putnici) async {
    return generateRouteStringSync(putnici);
  }

  // 🔄 REAL-TIME ROUTE STRING STREAM
  static Stream<String> streamRouteString(Stream<List<Putnik>> putniciStream) {
    return putniciStream.map((putnici) => generateRouteStringSync(putnici));
  }

  // 📍 SINHRONA GENERACIJA ROUTE STRING-a
  static String generateRouteStringSync(List<Putnik> putnici) {
    if (putnici.isEmpty) return 'Nema putnika';

    final aktivniPutnici = putnici.where((p) => p.status != 'otkazan' && p.status != 'Otkazano').toList();

    if (aktivniPutnici.isEmpty) return 'Nema aktivnih putnika';

    // Generiši rutu string koristeći SAMO adrese iz tabele putnici
    final rutaDelovi = aktivniPutnici.map((p) {
      final adresa = p.adresa;
      return adresa != null && adresa.isNotEmpty ? '${p.ime} ($adresa)' : p.ime;
    }).toList();

    return rutaDelovi.join(' → ');
  }

  // NOVA FUNKCIJA: Generiši optimizovan route string za specifičan grad i vreme
  static Future<String> generateOptimizedRouteForCityAndTime(
    List<Putnik> allPutnici,
    String grad,
    String vreme,
    String dan,
  ) async {
    final optimizedPutnici = await optimizeRouteForCityAndTime(allPutnici, grad, vreme, dan);

    if (optimizedPutnici.isEmpty) {
      return 'Nema putnika za $grad u $vreme';
    }

    final rutaDelovi = optimizedPutnici.map((p) {
      final adresa = p.adresa;
      return adresa != null && adresa.isNotEmpty ? '${p.ime} ($adresa)' : p.ime;
    }).toList();

    return '🚗 $grad $vreme: ${rutaDelovi.join(' → ')}';
  }

  // NOVA FUNKCIJA: Optimizuj sve rute za sve gradove i vremena odjednom
  static Future<Map<String, List<Putnik>>> optimizeAllRoutes(
    List<Putnik> allPutnici,
    String dan,
  ) async {
    const gradovi = ['Bela Crkva', 'Vršac'];
    const vremena = [
      '05:00',
      '06:00',
      '07:00',
      '08:00',
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
      '21:00',
      '22:00',
    ];

    Map<String, List<Putnik>> optimizedRoutes = {};

    for (String grad in gradovi) {
      for (String vreme in vremena) {
        final routeKey = '${grad}_$vreme';
        final optimizedRoute = await optimizeRouteForCityAndTime(allPutnici, grad, vreme, dan);

        if (optimizedRoute.isNotEmpty) {
          optimizedRoutes[routeKey] = optimizedRoute;
        }
      }
    }

    return optimizedRoutes;
  }

  // NOVA FUNKCIJA: Generiši kompletnu rutu za ceo dan
  static Future<String> generateDailyRouteReport(
    List<Putnik> allPutnici,
    String dan,
  ) async {
    final allRoutes = await optimizeAllRoutes(allPutnici, dan);

    if (allRoutes.isEmpty) {
      return 'Nema putnika za $dan';
    }

    List<String> reportLines = [];
    reportLines.add('📅 OPTIMIZOVANE RUTE ZA $dan:');
    reportLines.add('=' * 40);

    for (String routeKey in allRoutes.keys) {
      final parts = routeKey.split('_');
      final grad = parts[0];
      final vreme = parts[1];
      final putnici = allRoutes[routeKey]!;

      final rutaString = putnici.map((p) {
        final adresa = p.adresa;
        return adresa != null && adresa.isNotEmpty ? '${p.ime} ($adresa)' : p.ime;
      }).join(' → ');

      reportLines.add('🚗 $grad $vreme (${putnici.length}): $rutaString');
    }

    return reportLines.join('\n');
  }

  // Proveri da li je ruta logično organizovana (bez alfabetskog sortiranja)
  static Future<bool> isRouteOptimized(List<Putnik> putnici) async {
    if (putnici.isEmpty) return true;

    final aktivniPutnici = putnici.where((p) => p.status != 'otkazan' && p.status != 'Otkazano').toList();

    if (aktivniPutnici.length < 2) return true;

    // Jednostavno proverava da li lista ima logičnu strukturu
    // bez forsiranja alfabetskog redosleda

    // Proveri da li su otkazani putnici na kraju
    final imaAktivnihNaKraju = putnici.any(
      (p) =>
          (p.status == 'otkazan' || p.status == 'Otkazano') &&
          putnici.indexOf(p) < putnici.length - 1 &&
          putnici.sublist(putnici.indexOf(p) + 1).any(
                (next) => next.status != 'otkazan' && next.status != 'Otkazano',
              ),
    );

    return !imaAktivnihNaKraju; // True ako otkazani NISU između aktivnih
  }

  // -------------------- NEW: CACHED FETCH API --------------------
  final Map<String, _CacheEntry> _cache = {};
  final Duration _defaultTTL;
  PutnikService? _putnikService;
  final Future<List<Putnik>> Function({String? targetDay})? _fetchFn;

  RouteOptimizationService(
      {PutnikService? putnikService, Duration? ttl, Future<List<Putnik>> Function({String? targetDay})? fetchFn})
      : _putnikService = putnikService,
        // Default TTL changed to 30s for more realtime updates while keeping cache to reduce excessive calls
        _defaultTTL = ttl ?? const Duration(seconds: 30),
        _fetchFn = fetchFn;

  /// Generate cache key for grad|vreme|dan
  String _cacheKey(String grad, String vreme, String dan) => '${grad.trim().toLowerCase()}|${vreme.trim()}|$dan';

  /// Invalidate a specific cache entry
  void invalidateCacheFor({required String grad, required String vreme, String? dan}) {
    final key = _cacheKey(grad, vreme, _normalizeDayName(dan));
    _cache.remove(key);
  }

  /// Clear entire cache
  void clearCache() {
    _cache.clear();
  }

  String _normalizeDayName(String? dan) {
    if (dan == null) {
      final now = DateTime.now();
      const dani = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      return dani[now.weekday - 1];
    }
    return dan;
  }

  /// Fetch passengers for the selected grad + vreme.
  /// Uses a ttl-backed in-memory cache to reduce repeated Supabase queries.
  /// Vraća listu putnika za dati grad/vreme/dan.
  /// Ako je `driverPosition` prosleđena, koristi geografsku optimizaciju.
  Future<List<Putnik>> fetchPassengersForRoute({
    required String grad,
    required String vreme,
    String? dan,
    bool optimize = true,
    Position? driverPosition,
  }) async {
    final dayNormalized = _normalizeDayName(dan);
    final key = _cacheKey(grad, vreme, dayNormalized);
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && cached.expiry.isAfter(now)) {
      debugPrint('🔍 fetchPassengersForRoute: CACHE HIT za $grad $vreme - ${cached.data.length} putnika');
      return cached.data;
    }

    // Fetch all putnici and filter by grad + vreme for the selected day
    final allPutnici = (_fetchFn != null)
        ? await _fetchFn!(targetDay: dayNormalized)
        : await (_putnikService ??= PutnikService()).getAllPutniciFromBothTables(targetDay: dayNormalized);

    debugPrint('🔍 fetchPassengersForRoute: učitano ${allPutnici.length} ukupno putnika za dan=$dayNormalized');
    // DEBUG: Prikaži dan za svako putnika
    for (final p in allPutnici.take(5)) {
      debugPrint('   📋 ${p.ime} | p.dan="${p.dan}" | tražimo="$dayNormalized"');
    }

    // Normalize times for comparison
    final normFilterTime = GradAdresaValidator.normalizeTime(vreme);

    final filtered = allPutnici.where((p) {
      // 🎯 DAN FILTER - proveri da li putnik ima vožnju za ovaj dan
      // Mesečni putnici imaju raspored po danima (npr. "Pon, Uto, Sre")
      final dayMatch = p.dan.toLowerCase().contains(dayNormalized.toLowerCase());
      if (!dayMatch) return false;

      // 🎯 VREME FILTER
      final pTime = GradAdresaValidator.normalizeTime(p.polazak);
      if (pTime != normFilterTime) return false;

      // 🎯 GRAD FILTER - koristi GradAdresaValidator za konzistentnost sa danes_screen
      // Za mesečne putnike: direktno poređenje grada
      // Za dnevne putnike: koristi adresnu validaciju
      final isRegistrovaniPutnik = p.mesecnaKarta == true;
      bool gradMatch;
      if (isRegistrovaniPutnik) {
        gradMatch = p.grad == grad;
      } else {
        gradMatch = GradAdresaValidator.isGradMatch(p.grad, p.adresa, grad);
      }
      if (!gradMatch) return false;

      // 🔄 UJEDNAČENA LOGIKA: Isti filter za mesečne i dnevne putnike
      // Isključuje: otkazane, bolovanje, godišnji, obrisane
      if (!TextUtils.isStatusActive(p.status)) return false;

      return true;
    }).toList();

    debugPrint(
        '🔍 fetchPassengersForRoute: posle filtriranja ${filtered.length} putnika za $grad $vreme (dan=$dayNormalized)');
    for (final p in filtered) {
      debugPrint('   ✅ ${p.ime} | dan=${p.dan} | grad=${p.grad} | polazak=${p.polazak}');
    }

    // If requested, try to optimize route ordering using TSP based algorithm
    List<Putnik> result;
    if (optimize) {
      try {
        List<Putnik> optimized = [];
        if (driverPosition != null) {
          // pokušaj GPS optimizacije
          // ignore: deprecated_member_use_from_same_package
          optimized = await optimizeRouteGeographically(
            filtered,
            driverPosition: driverPosition,
            startAddress: grad == 'Bela Crkva' ? 'Bela Crkva' : null,
          );
        }
        if (optimized.isEmpty) {
          optimized =
              await RouteOptimizationService.optimizeRouteForCityAndTime(allPutnici, grad, vreme, dayNormalized);
        }
        // If optimization returned something non-empty, use it. Otherwise use filtered.
        result = optimized.isNotEmpty ? optimized : filtered;
      } catch (_) {
        result = filtered;
      }
    } else {
      result = filtered;
    }

    // Store in cache
    _cache[key] = _CacheEntry(data: result, expiry: now.add(_defaultTTL));
    return result;
  }

  /// Returns true if there is a fresh cache for grad/vreme/dan
  bool isCacheFresh({
    required String grad,
    required String vreme,
    String? dan,
  }) {
    final dayNormalized = _normalizeDayName(dan);
    final key = _cacheKey(grad, vreme, dayNormalized);
    final cached = _cache[key];
    return cached != null && cached.expiry.isAfter(DateTime.now());
  }
}
