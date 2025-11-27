import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';

/// 🗺️ BESPLATNO OFFLINE MAPS SISTEM
/// Koristi OpenStreetMap tiles + lokalna SQLite baza za geocoding
class OfflineMapService {
  static Database? _database;
  static final String _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Granice Vršac/Bela Crkva regiona
  static const double _minLat = 44.7; // Južno od Vršca
  static const double _maxLat = 45.2; // Severno od Bele Crkve
  static const double _minLng = 20.8; // Zapadno
  static const double _maxLng = 21.5; // Istočno

  static const int _maxZoom = 16;

  /// 🚀 INITIALIZE OFFLINE MAP SYSTEM
  static Future<void> initialize() async {
    await _initializeDatabase();
    await _preloadCriticalAddresses();
    // 🆕 Sync sa Supabase u pozadini (ne blokira startup)
    _syncAddressesFromSupabase();
  }

  /// 🔄 SYNC ADRESE IZ SUPABASE (pozadinski task)
  static Future<void> _syncAddressesFromSupabase() async {
    try {
      final db = await _getDatabase();

      // 1. Učitaj sve adrese iz 'adrese' tabele koje imaju koordinate
      final response = await Supabase.instance.client
          .from('adrese')
          .select('id, ulica, broj, grad, latitude, longitude')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (response.isEmpty) {
        print('📍 Offline sync: Nema adresa sa koordinatama u Supabase');
        return;
      }

      int syncCount = 0;
      for (final row in response) {
        final ulica = row['ulica'] as String? ?? '';
        final broj = row['broj'] as String? ?? '';
        final grad = row['grad'] as String? ?? '';
        final lat = row['latitude'];
        final lng = row['longitude'];

        if (lat == null || lng == null) continue;

        final adresa = broj.isNotEmpty ? '$ulica $broj' : ulica;
        if (adresa.isEmpty || grad.isEmpty) continue;

        await db.insert(
          'addresses',
          {
            'grad': grad,
            'adresa': adresa,
            'latitude': (lat is int) ? lat.toDouble() : lat as double,
            'longitude': (lng is int) ? lng.toDouble() : lng as double,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        syncCount++;
      }

      print('📍 Offline sync: Sinhronizovano $syncCount adresa iz Supabase');
    } catch (e) {
      print('⚠️ Offline sync greška: $e');
      // Ne prekidaj - offline baza i dalje ima hardkodirane adrese
    }
  }

  /// 🔄 FORCE SYNC - pozovi ručno kad treba refresh
  static Future<int> forceSyncFromSupabase() async {
    try {
      final db = await _getDatabase();

      final response = await Supabase.instance.client
          .from('adrese')
          .select('id, ulica, broj, grad, latitude, longitude')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (response.isEmpty) return 0;

      int syncCount = 0;
      for (final row in response) {
        final ulica = row['ulica'] as String? ?? '';
        final broj = row['broj'] as String? ?? '';
        final grad = row['grad'] as String? ?? '';
        final lat = row['latitude'];
        final lng = row['longitude'];

        if (lat == null || lng == null) continue;

        final adresa = broj.isNotEmpty ? '$ulica $broj' : ulica;
        if (adresa.isEmpty || grad.isEmpty) continue;

        await db.insert(
          'addresses',
          {
            'grad': grad,
            'adresa': adresa,
            'latitude': (lat is int) ? lat.toDouble() : lat as double,
            'longitude': (lng is int) ? lng.toDouble() : lng as double,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        syncCount++;
      }

      return syncCount;
    } catch (e) {
      print('⚠️ Force sync greška: $e');
      return 0;
    }
  }

  /// 📊 GET OFFLINE STATS
  static Future<Map<String, int>> getOfflineStats() async {
    try {
      final db = await _getDatabase();
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM addresses');
      final count = result.first['count'] as int? ?? 0;
      return {'totalAddresses': count};
    } catch (e) {
      return {'totalAddresses': 0};
    }
  }

  /// 📱 GET FLUTTER MAP WIDGET ZA OFFLINE UPOTREBU
  static Widget buildOfflineMap({
    required LatLng center,
    required List<Marker> markers,
    double zoom = 13.0,
    void Function(LatLng)? onTap,
  }) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: (tapPosition, point) => onTap?.call(point),
        // Ograniči na Vršac/Bela Crkva region
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(_minLat, _minLng),
            const LatLng(_maxLat, _maxLng),
          ),
        ),
      ),
      children: [
        // 🗺️ OpenStreetMap tile layer sa cache
        TileLayer(
          urlTemplate: _tileUrlTemplate,
          userAgentPackageName: 'com.gavra013.gavra_android',
          maxZoom: _maxZoom.toDouble(),

          // 💾 OFFLINE TILE CACHE KONFIGURACIJA
          tileProvider: CachedNetworkTileProvider(
            maxStale: const Duration(days: 30), // Tiles važe 30 dana
            fallbackUrl: _tileUrlTemplate,
          ),
        ),

        // 📍 Markers layer
        MarkerLayer(markers: markers),
      ],
    );
  }

  /// 📍 OFFLINE GEOCODING - koristi lokalnu bazu
  static Future<LatLng?> geocodeOffline(String grad, String adresa) async {
    try {
      final db = await _getDatabase();

      // Pokušaj exact match prvo
      final exactResults = await db.query(
        'addresses',
        columns: ['latitude', 'longitude'],
        where: 'LOWER(grad) = ? AND LOWER(adresa) = ?',
        whereArgs: [grad.toLowerCase().trim(), adresa.toLowerCase().trim()],
        limit: 1,
      );

      if (exactResults.isNotEmpty) {
        final result = exactResults.first;
        return LatLng(
          result['latitude'] as double,
          result['longitude'] as double,
        );
      }

      // Pokušaj fuzzy match
      final fuzzyResults = await db.query(
        'addresses',
        columns: ['latitude', 'longitude'],
        where: 'LOWER(grad) LIKE ? AND LOWER(adresa) LIKE ?',
        whereArgs: ['%${grad.toLowerCase()}%', '%${adresa.toLowerCase()}%'],
        limit: 1,
      );

      if (fuzzyResults.isNotEmpty) {
        final result = fuzzyResults.first;
        return LatLng(
          result['latitude'] as double,
          result['longitude'] as double,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 📍 REVERSE GEOCODING - adresa iz koordinata
  static Future<String?> reverseGeocodeOffline(LatLng coordinates) async {
    try {
      final db = await _getDatabase();

      // Pronađi najbližu adresu (simple distance calculation)
      final results = await db.rawQuery(
        '''
        SELECT adresa, grad,
               ABS(latitude - ?) + ABS(longitude - ?) as distance
        FROM addresses 
        ORDER BY distance 
        LIMIT 1
      ''',
        [coordinates.latitude, coordinates.longitude],
      );

      if (results.isNotEmpty) {
        final result = results.first;
        return '${result['adresa']}, ${result['grad']}';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🎯 OFFLINE ROUTE OPTIMIZATION
  static Future<List<Putnik>> optimizeRouteOffline(
    List<Putnik> putnici,
    LatLng startPosition,
  ) async {
    try {
      // Geocode sve adrese offline
      final Map<Putnik, LatLng> coordinates = {};

      for (final putnik in putnici) {
        if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
          final coords = await geocodeOffline(putnik.grad, putnik.adresa!);
          if (coords != null) {
            coordinates[putnik] = coords;
          }
        }
      }

      if (coordinates.isEmpty) {
        return putnici; // Fallback na originalni redosled
      }

      // Simple nearest neighbor algorithm
      final List<Putnik> optimizedRoute = [];
      final unvisited = Set<Putnik>.from(coordinates.keys);
      LatLng currentPosition = startPosition;

      while (unvisited.isNotEmpty) {
        Putnik? nearest;
        double shortestDistance = double.infinity;

        for (final putnik in unvisited) {
          final distance = _calculateDistance(currentPosition, coordinates[putnik]!);
          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearest = putnik;
          }
        }

        if (nearest != null) {
          optimizedRoute.add(nearest);
          currentPosition = coordinates[nearest]!;
          unvisited.remove(nearest);
        }
      }

      return optimizedRoute;
    } catch (e) {
      return putnici; // Fallback
    }
  }

  /// 💾 PRELOAD MAP TILES ZA REGION
  static Future<void> preloadMapTiles({
    required LatLng center,
    double radiusKm = 10.0,
    int zoomLevel = 14,
    void Function(double)? onProgress,
  }) async {
    try {
      final double latDelta = radiusKm / 111.0; // 1 stepen ≈ 111km
      final double lngDelta = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));

      final LatLng southwest = LatLng(
        math.max(_minLat, center.latitude - latDelta),
        math.max(_minLng, center.longitude - lngDelta),
      );

      final LatLng northeast = LatLng(
        math.min(_maxLat, center.latitude + latDelta),
        math.min(_maxLng, center.longitude + lngDelta),
      );

      // Preload tiles u region bounds
      await _preloadTilesInBounds(southwest, northeast, zoomLevel, onProgress);
    } catch (e) {
      // Silent fail
    }
  }

  /// 🔧 INITIALIZE SQLITE DATABASE
  static Future<void> _initializeDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = '${documentsDirectory.path}/gavra_offline_maps.db';

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Tabela za adrese sa koordinatama
        await db.execute('''
          CREATE TABLE addresses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grad TEXT NOT NULL,
            adresa TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        ''');

        // Index za brže pretrage
        await db.execute('CREATE INDEX idx_grad_adresa ON addresses(grad, adresa)');
        await db.execute(
          'CREATE INDEX idx_coordinates ON addresses(latitude, longitude)',
        );
      },
    );
  }

  /// 🏠 PRELOAD KRITIČNIH ADRESA
  static Future<void> _preloadCriticalAddresses() async {
    final criticalAddresses = [
      // VRŠAC
      {
        'grad': 'Vršac',
        'adresa': 'Trg pobede 1',
        'lat': 45.1167,
        'lng': 21.3000,
      },
      {
        'grad': 'Vršac',
        'adresa': 'Svetosavska 1',
        'lat': 45.1170,
        'lng': 21.3010,
      },
      {
        'grad': 'Vršac',
        'adresa': 'Omladinska 1',
        'lat': 45.1160,
        'lng': 21.2990,
      },
      {
        'grad': 'Vršac',
        'adresa': 'Železnička stanica',
        'lat': 45.1180,
        'lng': 21.2950,
      },

      // BELA CRKVA
      {
        'grad': 'Bela Crkva',
        'adresa': 'Trg oslobođenja 1',
        'lat': 44.8975,
        'lng': 21.4178,
      },
      {
        'grad': 'Bela Crkva',
        'adresa': 'Cara Dušana 1',
        'lat': 44.8980,
        'lng': 21.4180,
      },
      {
        'grad': 'Bela Crkva',
        'adresa': 'Autobuska stanica',
        'lat': 44.8970,
        'lng': 21.4175,
      },

      // SELA VRŠAC
      {'grad': 'Straža', 'adresa': 'Centar', 'lat': 45.1000, 'lng': 21.2500},
      {
        'grad': 'Vojvodinci',
        'adresa': 'Centar',
        'lat': 45.0500,
        'lng': 21.2000,
      },
      {'grad': 'Potporanj', 'adresa': 'Centar', 'lat': 45.0800, 'lng': 21.1500},

      // SELA BELA CRKVA
      {
        'grad': 'Vraćev Gaj',
        'adresa': 'Centar',
        'lat': 44.9200,
        'lng': 21.3500,
      },
      {'grad': 'Dupljaja', 'adresa': 'Centar', 'lat': 44.8500, 'lng': 21.3000},
      {'grad': 'Jasenovo', 'adresa': 'Centar', 'lat': 44.8800, 'lng': 21.5000},
    ];

    final db = await _getDatabase();

    for (final addr in criticalAddresses) {
      await db.insert(
        'addresses',
        {
          'grad': addr['grad'],
          'adresa': addr['adresa'],
          'latitude': addr['lat'],
          'longitude': addr['lng'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// 📐 CALCULATE DISTANCE IZMEĐU DVE KOORDINATE
  static double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// 💾 PRELOAD TILES IN BOUNDS
  static Future<void> _preloadTilesInBounds(
    LatLng southwest,
    LatLng northeast,
    int zoomLevel,
    void Function(double)? onProgress,
  ) async {
    // Implementacija tile preload-a
    // Ovo je simplified verzija - u produkciji bi trebalo više sophisticated cache
    final double n = math.pow(2.0, zoomLevel.toDouble()).toDouble();

    int totalTiles = 0;
    int loadedTiles = 0;

    // Calculate tile coordinates
    final int minX = ((southwest.longitude + 180.0) / 360.0 * n).floor();
    final int maxX = ((northeast.longitude + 180.0) / 360.0 * n).floor();
    final int minY = ((1.0 -
                math.log(
                      math.tan(northeast.latitude * math.pi / 180.0) +
                          1.0 / math.cos(northeast.latitude * math.pi / 180.0),
                    ) /
                    math.pi) /
            2.0 *
            n)
        .floor();
    final int maxY = ((1.0 -
                math.log(
                      math.tan(southwest.latitude * math.pi / 180.0) +
                          1.0 / math.cos(southwest.latitude * math.pi / 180.0),
                    ) /
                    math.pi) /
            2.0 *
            n)
        .floor();

    totalTiles = (maxX - minX + 1) * (maxY - minY + 1);

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        try {
          final url = _tileUrlTemplate
              .replaceAll('{z}', zoomLevel.toString())
              .replaceAll('{x}', x.toString())
              .replaceAll('{y}', y.toString());

          // Simple HTTP get za tile (u production bi trebao proper cache)
          await http.get(Uri.parse(url));

          loadedTiles++;
          onProgress?.call(loadedTiles / totalTiles);
        } catch (e) {
          // Continue sa sledećim tile-om
        }
      }
    }
  }

  /// 🗄️ GET DATABASE INSTANCE
  static Future<Database> _getDatabase() async {
    if (_database == null) {
      await _initializeDatabase();
    }
    return _database!;
  }

  /// 🧹 CLEANUP
  static Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}

/// 💾 CUSTOM TILE PROVIDER SA CACHE
class CachedNetworkTileProvider extends TileProvider {
  CachedNetworkTileProvider({
    required this.maxStale,
    required this.fallbackUrl,
  });
  final Duration maxStale;
  final String fallbackUrl;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = options.urlTemplate!
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());

    // U production bi ovde trebao sophisticated cache mechanism
    // Za sada koristimo basic network image
    return NetworkImage(url);
  }
}
