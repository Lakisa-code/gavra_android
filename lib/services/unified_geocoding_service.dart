/// UNIFIED GEOCODING SERVICE
/// Centralizovani servis za geocoding sa:
/// - Paralelnim fetch-om koordinata
/// - Prioritetnim redosledom (Baza → Memory → Disk → API)
/// - Progress callback za UI
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// UNIFIED GEOCODING SERVICE
class UnifiedGeocodingService {
  UnifiedGeocodingService._();

  // ═══════════════════════════════════════════════════════════════════════
  // GLAVNA FUNKCIJA - Dobij koordinate za više putnika (PARALELNO)
  // ═══════════════════════════════════════════════════════════════════════

  /// Dobij koordinate za listu putnika sa paralelnim fetch-om
  /// Vraća mapu Putnik -> Position samo za uspešno geocodirane
  static Future<Map<Putnik, Position>> getCoordinatesForPutnici(
    List<Putnik> putnici, {
    GeocodingProgressCallback? onProgress,
    bool saveToDatabase = true,
  }) async {
    final Map<Putnik, Position> coordinates = {};

    final putniciSaAdresama = putnici.where((p) => _hasValidAddress(p)).toList();

    if (putniciSaAdresama.isEmpty) {
      return coordinates;
    }

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

    final results = await _executeWithRateLimit(
      tasks,
      delay: RouteConfig.nominatimBatchDelay,
    );

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

      // PRIORITET 1: Koordinate iz baze (preko adresaId)
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        final adresaFromDb = await AdresaSupabaseService.getAdresaByUuid(
          putnik.adresaId!,
        );
        if (adresaFromDb != null) {
          realAddressName = adresaFromDb.naziv;

          if (adresaFromDb.latitude != null && adresaFromDb.longitude != null) {
            position = _createPosition(
              adresaFromDb.latitude!,
              adresaFromDb.longitude!,
            );
            source = 'database';
          }
        }
      }

      // PRIORITET 2: Memory cache
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

      // PRIORITET 3: Disk cache
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
            CacheService.saveToMemory(cacheKey, diskCached);
          }
        }
      }

      // PRIORITET 4: Nominatim API
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

            final cacheKey = _getCacheKey(putnik);
            CacheService.saveToMemory(cacheKey, coordsString);
            await CacheService.saveToDisk(cacheKey, coordsString);

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
  // HELPER FUNKCIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// Proveri da li putnik ima validnu adresu
  static bool _hasValidAddress(Putnik putnik) {
    // MESEČNI PUTNICI: Imaju adresaId koji pokazuje na pravu adresu
    if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
      return true;
    }

    // DNEVNI PUTNICI: Moraju imati adresu koja nije samo grad
    if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) {
      return false;
    }
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
      // 🔇 Ignore
    }
  }

  /// Trajno loguj lokaciju gde je putnik pokupljen u tabelu putnik_pickup_lokacije
  static Future<void> logPickupLocation({
    required Putnik putnik,
    required String vozacId,
    required double lat,
    required double lng,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('putnik_pickup_lokacije').insert({
        'putnik_id': putnik.id,
        'putnik_ime': putnik.ime,
        'lat': lat,
        'lng': lng,
        'vozac_id': vozacId,
        'datum': DateTime.now().toIso8601String().split('T')[0],
      });
      print('📍 [Geocoding] Lokacija pokupljenja logovana za ${putnik.ime}');
    } catch (e) {
      print('⚠️ [Geocoding] Greška pri logovanju lokacije: $e');
    }
  }

  /// Izvršava taskove sekvencijalno sa pauzom između zahteva
  static Future<List<GeocodingResult>> _executeWithRateLimit(
    List<Future<GeocodingResult> Function()> tasks, {
    required Duration delay,
  }) async {
    final results = <GeocodingResult>[];

    for (int i = 0; i < tasks.length; i++) {
      final result = await tasks[i]();
      results.add(result);

      if (result.source == 'nominatim' && i < tasks.length - 1) {
        await Future.delayed(delay);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTIKE I DEBUG
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

  // ═══════════════════════════════════════════════════════════════════════
  // AUTO-LEARNING (TIHO UČENJE KOORDINATA)
  // ═══════════════════════════════════════════════════════════════════════

  /// Pokušaj da naučiš koordinate adrese na osnovu trenutne lokacije vozača
  /// Poziva se kada vozač označi putnika kao "Pokupljen"
  static Future<void> tryLearnFromDriverLocation(
    Putnik putnik, {
    String? vozacId,
  }) async {
    try {
      // 1. Proveri GPS dozvole i dobij lokaciju
      final locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied || locationPermission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // 2. LOGUJ U TABELU ZA PRACENJE (uvek, ako imamo poziciju)
      if (vozacId != null) {
        unawaited(logPickupLocation(
          putnik: putnik,
          vozacId: vozacId,
          lat: position.latitude,
          lng: position.longitude,
        ));
      }

      // 3. AUTO-LEARNING ADRESE: Proveri da li adresa već ima koordinate (ne menjaj ako ima)
      bool shouldUpdateAddress = true;
      if (_hasValidAddress(putnik)) {
        final existing = await AdresaSupabaseService.getAdresaByUuid(putnik.adresaId ?? '');
        if (existing != null && existing.latitude != null && existing.latitude != 0) {
          shouldUpdateAddress = false;
        }
      }

      if (!shouldUpdateAddress) return;

      // 4. Proveri da li je vozač blizu grada (da ne upišemo lokaciju na autoputu)
      // Koristimo RouteConfig za koordinate centara gradova
      // Max distanca od centra: 5km (radijus grada)

      final distBC = Geolocator.distanceBetween(
          position.latitude, position.longitude, RouteConfig.belaCrkvaLat, RouteConfig.belaCrkvaLng);

      final distVS =
          Geolocator.distanceBetween(position.latitude, position.longitude, RouteConfig.vrsacLat, RouteConfig.vrsacLng);

      // Tolerancija: 6000 metara (6km) od centra grada
      final isNearCity = distBC < 6000 || distVS < 6000;

      if (!isNearCity) {
        // Vozač je negde između gradova, ne upisuj ovu lokaciju kao adresu
        return;
      }

      // 5. Upiši u bazu adresa
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        await _saveCoordinatesToDatabase(
          putnik: putnik,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
    } catch (e) {
      // Ignoriši greške tiho
    }
  }
}
