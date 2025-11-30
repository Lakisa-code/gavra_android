/// 🎯 UNIFIED GEOCODING SERVICE
/// Centralizovani servis za geocoding sa:
/// - Paralelnim fetch-om koordinata
/// - Prioritetnim redosledom (Baza → Memory → Disk → API)
/// - 2-opt improvement za fallback optimizaciju
/// - Progress callback za UI
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'adresa_supabase_service.dart';
import 'cache_service.dart';
import 'geocoding_service.dart';

/// Callback za praćenje progresa geocodinga
typedef GeocodingProgressCallback = void Function(
  int completed,
  int total,
  String currentAddress,
);

/// Rezultat geocodinga za jednog putnika
class GeocodingResult {
  const GeocodingResult({
    required this.putnik,
    this.position,
    this.source,
    this.error,
  });

  final Putnik putnik;
  final Position? position;
  final String? source; // 'database', 'memory_cache', 'disk_cache', 'nominatim'
  final String? error;

  bool get success => position != null;
}

/// 🎯 UNIFIED GEOCODING SERVICE
class UnifiedGeocodingService {
  UnifiedGeocodingService._();

  // ═══════════════════════════════════════════════════════════════════════
  // 📍 GLAVNA FUNKCIJA - Dobij koordinate za više putnika (PARALELNO)
  // ═══════════════════════════════════════════════════════════════════════

  /// Dobij koordinate za listu putnika sa paralelnim fetch-om
  /// Vraća mapu Putnik -> Position samo za uspešno geocodirane
  static Future<Map<Putnik, Position>> getCoordinatesForPutnici(
    List<Putnik> putnici, {
    GeocodingProgressCallback? onProgress,
    bool saveToDatabase = true,
  }) async {
    final Map<Putnik, Position> coordinates = {};
    // final List<Future<GeocodingResult>> futures = []; // REMOVED: Unused

    // Filtriraj putnike sa adresama
    final putniciSaAdresama = putnici.where((p) => _hasValidAddress(p)).toList();

    if (putniciSaAdresama.isEmpty) {
      return coordinates;
    }

    // Kreiraj funkcije za sekvencijalno izvršavanje
    final List<Future<GeocodingResult> Function()> tasks = [];
    int completed = 0;
    final int total = putniciSaAdresama.length;

    for (final putnik in putniciSaAdresama) {
      tasks.add(() async {
        final result = await _getCoordinatesForPutnik(putnik, saveToDatabase);
        completed++;
        onProgress?.call(completed, total, putnik.adresa ?? putnik.ime);
        return result;
      });
    }

    // Izvrši taskove sekvencijalno sa pauzom
    final results = await _executeWithRateLimit(
      tasks,
      delay: RouteConfig.nominatimBatchDelay,
    );

    // Popuni mapu sa uspešnim rezultatima
    for (final result in results) {
      if (result.success) {
        coordinates[result.putnik] = result.position!;
      }
    }

    return coordinates;
  }

  /// Dobij koordinate za jednog putnika
  static Future<GeocodingResult> _getCoordinatesForPutnik(
    Putnik putnik,
    bool saveToDatabase,
  ) async {
    try {
      Position? position;
      String? source;
      String? realAddressName;

      // 🎯 PRIORITET 1: Koordinate iz baze (preko adresaId)
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        final adresaFromDb = await AdresaSupabaseService.getAdresaByUuid(
          putnik.adresaId!,
        );
        if (adresaFromDb != null) {
          realAddressName = adresaFromDb.naziv;

          // Ako ima koordinate u bazi, koristi ih
          if (adresaFromDb.latitude != null && adresaFromDb.longitude != null) {
            position = _createPosition(
              adresaFromDb.latitude!,
              adresaFromDb.longitude!,
            );
            source = 'database';
          }
        }
      }

      // 🎯 PRIORITET 2: Memory cache
      if (position == null) {
        final cacheKey = _getCacheKey(putnik);
        final memoryCached = CacheService.getFromMemory<String>(
          cacheKey,
          maxAge: RouteConfig.geocodingMemoryCacheDuration,
        );
        if (memoryCached != null) {
          position = _parsePosition(memoryCached);
          if (position != null) source = 'memory_cache';
        }
      }

      // 🎯 PRIORITET 3: Disk cache
      if (position == null) {
        final cacheKey = _getCacheKey(putnik);
        final diskCached = await CacheService.getFromDisk<String>(
          cacheKey,
          maxAge: RouteConfig.geocodingDiskCacheDuration,
        );
        if (diskCached != null) {
          position = _parsePosition(diskCached);
          if (position != null) {
            source = 'disk_cache';
            // Sačuvaj u memory cache za brži pristup
            CacheService.saveToMemory(cacheKey, diskCached);
          }
        }
      }

      // 🎯 PRIORITET 4: Nominatim API
      if (position == null) {
        final addressToGeocode = realAddressName ?? putnik.adresa!;
        final coordsString = await GeocodingService.getKoordinateZaAdresu(
          putnik.grad,
          addressToGeocode,
        );

        if (coordsString != null) {
          position = _parsePosition(coordsString);
          if (position != null) {
            source = 'nominatim';

            // Sačuvaj u cache
            final cacheKey = _getCacheKey(putnik);
            CacheService.saveToMemory(cacheKey, coordsString);
            await CacheService.saveToDisk(cacheKey, coordsString);

            // Sačuvaj u bazu za sledeći put
            if (saveToDatabase) {
              await _saveCoordinatesToDatabase(
                putnik: putnik,
                lat: position.latitude,
                lng: position.longitude,
              );
            }
          }
        }
      }

      return GeocodingResult(
        putnik: putnik,
        position: position,
        source: source,
        error: position == null ? 'Koordinate nisu pronađene' : null,
      );
    } catch (e) {
      return GeocodingResult(
        putnik: putnik,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎯 FALLBACK OPTIMIZACIJA (Nearest Neighbor + 2-opt)
  // ═══════════════════════════════════════════════════════════════════════

  /// Nearest Neighbor optimizacija sa 2-opt improvement
  static Future<List<Putnik>> fallbackOptimization({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    bool use2opt = true,
  }) async {
    // Filtriraj samo putnike sa koordinatama
    final putniciWithCoords = putnici.where((p) => coordinates.containsKey(p)).toList();

    if (putniciWithCoords.isEmpty) return [];
    if (putniciWithCoords.length == 1) return putniciWithCoords;

    // 1. Nearest Neighbor algoritam
    final route = await _nearestNeighborOptimization(
      startPosition,
      putniciWithCoords,
      coordinates,
    );

    // 2. 2-opt improvement (ako je omogućen)
    if (use2opt && route.length >= 4) {
      return _twoOptImprovement(startPosition, route, coordinates);
    }

    return route;
  }

  /// Nearest Neighbor algoritam
  static Future<List<Putnik>> _nearestNeighborOptimization(
    Position start,
    List<Putnik> putnici,
    Map<Putnik, Position> coordinates,
  ) async {
    final unvisited = List<Putnik>.from(putnici);
    final route = <Putnik>[];
    Position currentPosition = start;

    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      for (final putnik in unvisited) {
        final distance = _calculateDistance(
          currentPosition,
          coordinates[putnik]!,
        );
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

  /// 2-opt improvement algoritam
  /// Poboljšava Nearest Neighbor rutu za 10-15%
  static List<Putnik> _twoOptImprovement(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.length < 4) return route;

    List<Putnik> bestRoute = List.from(route);
    double bestDistance = _calculateTotalRouteDistance(
      start,
      bestRoute,
      coordinates,
    );
    bool improved = true;
    int iterations = 0;
    const maxIterations = 100; // Limit za performance

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;

      for (int i = 0; i < bestRoute.length - 1; i++) {
        for (int j = i + 2; j < bestRoute.length; j++) {
          // Probaj 2-opt swap: reverziraj segment između i+1 i j
          final newRoute = _twoOptSwap(bestRoute, i, j);
          final newDistance = _calculateTotalRouteDistance(
            start,
            newRoute,
            coordinates,
          );

          if (newDistance < bestDistance) {
            bestRoute = newRoute;
            bestDistance = newDistance;
            improved = true;
          }
        }
      }
    }

    return bestRoute;
  }

  /// 2-opt swap - reverziraj segment između i+1 i j
  static List<Putnik> _twoOptSwap(List<Putnik> route, int i, int j) {
    final newRoute = <Putnik>[];

    // Dodaj elemente od 0 do i
    for (int k = 0; k <= i; k++) {
      newRoute.add(route[k]);
    }

    // Dodaj elemente od j do i+1 u obrnutom redosledu
    for (int k = j; k > i; k--) {
      newRoute.add(route[k]);
    }

    // Dodaj ostatak rute
    for (int k = j + 1; k < route.length; k++) {
      newRoute.add(route[k]);
    }

    return newRoute;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📐 HELPER FUNKCIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// Proveri da li putnik ima validnu adresu
  static bool _hasValidAddress(Putnik putnik) {
    // 🎯 MESEČNI PUTNICI: Imaju adresaId koji pokazuje na pravu adresu
    if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
      return true;
    }

    // DNEVNI PUTNICI: Moraju imati adresu koja nije samo grad
    if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) {
      return false;
    }
    // Proveri da adresa nije samo naziv grada
    if (putnik.adresa!.toLowerCase().trim() == putnik.grad.toLowerCase().trim()) {
      return false;
    }
    return true;
  }

  /// Generiši cache key za putnika
  static String _getCacheKey(Putnik putnik) {
    return CacheKeys.geocoding('${putnik.grad}_${putnik.adresa}');
  }

  /// Parsiraj koordinate iz stringa "lat,lng"
  static Position? _parsePosition(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length != 2) return null;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) return null;

      return _createPosition(lat, lng);
    } catch (e) {
      return null;
    }
  }

  /// Kreiraj Position objekat
  static Position _createPosition(double lat, double lng) {
    return Position(
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
  }

  /// Sačuvaj koordinate u bazu
  static Future<void> _saveCoordinatesToDatabase({
    required Putnik putnik,
    required double lat,
    required double lng,
  }) async {
    try {
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        await AdresaSupabaseService.updateKoordinate(
          putnik.adresaId!,
          lat: lat,
          lng: lng,
        );
      } else if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
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

  /// Izračunaj distancu između dve tačke (Haversine)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// Izračunaj ukupnu distancu rute
  static double _calculateTotalRouteDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.isEmpty) return 0;

    double total = 0;
    Position current = start;

    for (final putnik in route) {
      if (coordinates.containsKey(putnik)) {
        total += _calculateDistance(current, coordinates[putnik]!);
        current = coordinates[putnik]!;
      }
    }

    return total;
  }

  /// Izvršava taskove sekvencijalno sa pauzom između zahteva
  static Future<List<GeocodingResult>> _executeWithRateLimit(
    List<Future<GeocodingResult> Function()> tasks, {
    required Duration delay,
  }) async {
    final results = <GeocodingResult>[];

    for (int i = 0; i < tasks.length; i++) {
      // Izvrši task
      final result = await tasks[i]();
      results.add(result);

      // Ako je rezultat došao sa interneta (Nominatim), napravi pauzu
      // Ako je iz keša/baze, ne treba pauza
      if (result.source == 'nominatim' && i < tasks.length - 1) {
        await Future.delayed(delay);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📊 STATISTIKE I DEBUG
  // ═══════════════════════════════════════════════════════════════════════

  /// Generiši statistiku geocodinga
  static Map<String, int> generateStats(List<GeocodingResult> results) {
    final stats = <String, int>{
      'total': results.length,
      'success': 0,
      'failed': 0,
      'from_database': 0,
      'from_memory_cache': 0,
      'from_disk_cache': 0,
      'from_nominatim': 0,
    };

    for (final result in results) {
      if (result.success) {
        stats['success'] = stats['success']! + 1;
        switch (result.source) {
          case 'database':
            stats['from_database'] = stats['from_database']! + 1;
            break;
          case 'memory_cache':
            stats['from_memory_cache'] = stats['from_memory_cache']! + 1;
            break;
          case 'disk_cache':
            stats['from_disk_cache'] = stats['from_disk_cache']! + 1;
            break;
          case 'nominatim':
            stats['from_nominatim'] = stats['from_nominatim']! + 1;
            break;
        }
      } else {
        stats['failed'] = stats['failed']! + 1;
      }
    }

    return stats;
  }
}
