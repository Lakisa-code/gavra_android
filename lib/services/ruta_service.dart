import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/ruta.dart';
import 'batch_database_service.dart';
import 'cache_service.dart';
import 'performance_optimizer_service.dart';
import 'supabase_safe.dart';

/// 🚀 OPTIMIZOVANI SERVIS ZA UPRAVLJANJE RUTAMA
class RutaService with BatchDatabaseMixin {
  RutaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? supabase;
  final SupabaseClient _supabase;

  // Cache konfiguracija
  static const String _cacheKeyPrefix = 'rute';
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // Cache ključevi
  static String _getAllCacheKey() => '${_cacheKeyPrefix}_all';
  static String _getActiveCacheKey() => '${_cacheKeyPrefix}_active';
  static String _getByIdCacheKey(String id) => '${_cacheKeyPrefix}_id_$id';
  static String _getSearchCacheKey(String query) =>
      '${_cacheKeyPrefix}_search_$query';
  static String _getStatsCacheKey() => '${_cacheKeyPrefix}_statistics';

  // Čišćenje cache-a
  static Future<void> _clearCache() async {
    await CacheService.clearFromDisk(_getAllCacheKey());
    await CacheService.clearFromDisk(_getActiveCacheKey());
    await CacheService.clearFromDisk(_getStatsCacheKey());
  }

  static Future<void> _clearCacheForId(String id) async {
    await CacheService.clearFromDisk(_getByIdCacheKey(id));
    await _clearCache();
  }

  /// 🚀 OPTIMIZOVANA VERZIJA - Dohvata sve rute (sa batch optimizacijom)
  Future<List<Ruta>> getAllRute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Pokušaj cache prvo
      final cacheKey = _getAllCacheKey();
      final cached = await CacheService.getFromDisk<List<dynamic>>(
        cacheKey,
        maxAge: _cacheExpiry,
      );
      if (cached != null) {
        return cached
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      // 🚀 OPTIMIZOVANI QUERY - Samo potrebne kolone
      final response = await selectOptimized(
        'rute',
        columns: [
          'id',
          'naziv',
          'polazak',
          'dolazak',
          'opis',
          'udaljenost_km',
          'prosecno_vreme',
          'aktivan',
          'created_at',
          'updated_at',
        ],
      );

      if (response.isNotEmpty) {
        // Keširaj rezultat
        await CacheService.saveToDisk(cacheKey, response);
        return response.map((json) => Ruta.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'ruta_getAllRute',
        stopwatch.elapsed,
      );
    }
  }

  /// 🚀 OPTIMIZOVANA VERZIJA - Dohvata samo aktivne rute
  Future<List<Ruta>> getActiveRute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Pokušaj cache prvo
      final cacheKey = _getActiveCacheKey();
      final cached = await CacheService.getFromDisk<List<dynamic>>(
        cacheKey,
        maxAge: _cacheExpiry,
      );
      if (cached != null) {
        return cached
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      // 🚀 OPTIMIZOVANI QUERY sa WHERE klauzulom
      final response = await selectOptimized(
        'rute',
        columns: [
          'id',
          'naziv',
          'polazak',
          'dolazak',
          'opis',
          'aktivan',
          'created_at',
          'updated_at'
        ],
        where: 'aktivan',
        whereValue: true,
      );

      if (response.isNotEmpty) {
        // Keširaj rezultat
        await CacheService.saveToDisk(cacheKey, response);
        return response.map((json) => Ruta.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'ruta_getActiveRute',
        stopwatch.elapsed,
      );
    }
  }

  /// Dohvata rutu po ID-u (sa keširanje i error handling)
  Future<Ruta?> getRutaById(String id) async {
    try {
      // Pokušaj cache prvo
      final cacheKey = _getByIdCacheKey(id);
      final cached = CacheService.getFromMemory<Ruta>(cacheKey);
      if (cached != null) {
        // Debug logging removed for production
        return cached;
      }

      final response = await SupabaseSafe.run(
        () => _supabase.from('rute').select().eq('id', id).single(),
      );

      if (response == null) {
        // Debug logging removed for production
        return null;
      }

      final ruta = Ruta.fromMap(response);

      // Keširaj u memory
      CacheService.saveToMemory(cacheKey, ruta);

      return ruta;
    } catch (e) {
      // Debug logging removed for production
      return null;
    }
  }

  /// 🚀 OPTIMIZOVANA VERZIJA - Kreira novu rutu sa batch processing
  Future<Ruta?> createRuta(Ruta ruta) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validacija pre dodavanja
      final validation = ruta.validateFull();
      if (validation.isNotEmpty) {
        return null;
      }

      // Osnovna validacija naziva (batch optimizovano)
      final existingNaziv = await selectOptimized(
        'rute',
        columns: ['id', 'naziv'],
        where: 'naziv',
        whereValue: ruta.naziv,
        limit: 1,
      );

      if (existingNaziv.isNotEmpty) {
        return null; // Naziv već postoji
      }

      // 🚀 BATCH INSERT
      batchInsert('rute', ruta.toMap());

      // Privremeno vraćamo rutu (u batch sistemu će biti upisana asinhrono)
      final novaRuta = ruta.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Očisti cache
      await _clearCache();
      return novaRuta;
    } catch (e) {
      return null;
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'ruta_createRuta',
        stopwatch.elapsed,
      );
    }
  }

  /// 🚀 OPTIMIZOVANA VERZIJA - Ažurira rutu sa batch processing
  Future<Ruta?> updateRuta(String id, Map<String, dynamic> updates) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Dodaj timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();
      updates['id'] = id; // Potrebno za batch update

      // 🚀 BATCH UPDATE
      batchUpdate('rute', updates);

      // Privremeno vrati optimistično rezultat
      final currentRuta = await getRutaById(id);
      if (currentRuta == null) return null;

      final azuriranaRuta = currentRuta.copyWith(
        updatedAt: DateTime.now(),
      );

      // Validacija nakon ažuriranja
      final validation = azuriranaRuta.validateFull();
      if (validation.isNotEmpty) {
        return null;
      }

      // Očisti cache
      await _clearCacheForId(id);
      return azuriranaRuta;
    } catch (e) {
      return null;
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'ruta_updateRuta',
        stopwatch.elapsed,
      );
    }
  }

  /// Ažurira celu rutu (alternativa sa Ruta objektom)
  Future<Ruta?> updateRutaObject(Ruta ruta) async {
    try {
      // Validacija
      final validation = ruta.validateFull();
      if (validation.isNotEmpty) {
        // Debug logging removed for production
        return null;
      }

      final updatedRuta = ruta.withUpdatedTime();

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('rute')
            .update(updatedRuta.toMap())
            .eq('id', ruta.id)
            .select()
            .single(),
      );

      if (response == null) return null;

      final result = Ruta.fromMap(response);

      // Očisti cache
      await _clearCacheForId(ruta.id);
      // Debug logging removed for production
      return result;
    } catch (e) {
      // Debug logging removed for production
      return null;
    }
  }

  /// Deaktivira rutu (soft delete sa cache invalidation)
  Future<bool> deactivateRuta(String id) async {
    try {
      await SupabaseSafe.run(
        () => _supabase.from('rute').update({
          'aktivan': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id),
      );

      // Očisti cache
      await _clearCacheForId(id);
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Aktivira rutu
  Future<bool> activateRuta(String id) async {
    try {
      await SupabaseSafe.run(
        () => _supabase.from('rute').update({
          'aktivan': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id),
      );

      // Očisti cache
      await _clearCacheForId(id);
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Briše rutu potpuno (hard delete)
  Future<bool> deleteRuta(String id) async {
    try {
      // Prvo proveri da li postoje povezani putnici
      final hasDependencies = await _checkRutaDependencies(id);
      if (hasDependencies) {
        // Debug logging removed for production
        return false;
      }

      await SupabaseSafe.run(
        () => _supabase.from('rute').delete().eq('id', id),
      );

      // Očisti cache
      await _clearCacheForId(id);
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Proverava da li ruta ima povezane putnici
  Future<bool> _checkRutaDependencies(String rutaId) async {
    try {
      final response = await SupabaseSafe.run(
        () => _supabase
            .from('dnevni_putnici')
            .select('id')
            .eq('ruta_id', rutaId)
            .limit(1),
        fallback: <dynamic>[],
      );

      return response is List && response.isNotEmpty;
    } catch (e) {
      // Debug logging removed for production
      return true; // Sigurnost - pretpostavi da ima zavisnosti
    }
  }

  /// Napredna pretraga ruta
  Future<List<Ruta>> searchRute({
    String? query,
    bool? aktivan,
    double? minUdaljenost,
    double? maxUdaljenost,
    int? minVremeMinuti,
    int? maxVremeMinuti,
    String? polazak,
    String? dolazak,
    int limit = 100,
  }) async {
    try {
      // Keširaj jednostavne pretrage
      String? cacheKey;
      if (query != null &&
          query.length > 2 &&
          aktivan == null &&
          minUdaljenost == null &&
          maxUdaljenost == null) {
        cacheKey = _getSearchCacheKey(query);
        final cached = CacheService.getFromMemory<List<Ruta>>(cacheKey);
        if (cached != null) {
          // Debug logging removed for production
          return cached;
        }
      }

      final response = await SupabaseSafe.run(
        () {
          var q = _supabase.from('rute').select();

          // Tekstualna pretraga
          if (query != null && query.isNotEmpty) {
            q = q.or(
              'naziv.ilike.%$query%,polazak.ilike.%$query%,dolazak.ilike.%$query%,opis.ilike.%$query%',
            );
          }

          // Filteri
          if (aktivan != null) {
            q = q.eq('aktivan', aktivan);
          }
          if (polazak != null) {
            q = q.eq('polazak', polazak);
          }
          if (dolazak != null) {
            q = q.eq('dolazak', dolazak);
          }
          if (minUdaljenost != null) {
            q = q.gte('udaljenost_km', minUdaljenost);
          }
          if (maxUdaljenost != null) {
            q = q.lte('udaljenost_km', maxUdaljenost);
          }
          if (minVremeMinuti != null) {
            q = q.gte(
              'prosecno_vreme',
              minVremeMinuti * 60,
            ); // Konvertuj u sekunde
          }
          if (maxVremeMinuti != null) {
            q = q.lte(
              'prosecno_vreme',
              maxVremeMinuti * 60,
            ); // Konvertuj u sekunde
          }

          return q.order('naziv').limit(limit);
        },
        fallback: <dynamic>[],
      );

      if (response is List) {
        final results = response
            .map<Ruta>((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();

        // Keširaj jednostavne pretrage
        if (cacheKey != null) {
          CacheService.saveToMemory(cacheKey, results);
        }

        return results;
      }
      return [];
    } catch (e) {
      // Debug logging removed for production
      return [];
    }
  }

  /// Traži rute po nazivu, polasku ili destinaciji (stara metoda za kompatibilnost)
  Future<List<Ruta>> searchRuteSimple(String query) async {
    return searchRute(query: query, aktivan: true);
  }

  /// Dohvata rute između dva grada (poboljšana verzija)
  Future<List<Ruta>> getRuteIzmedju(
    String polazak,
    String destinacija, {
    bool sameAktivan = true,
  }) async {
    try {
      final response = await SupabaseSafe.run(
        () {
          var q = _supabase
              .from('rute')
              .select()
              .eq('polazak', polazak)
              .eq('dolazak', destinacija);

          if (sameAktivan) {
            q = q.eq('aktivan', true);
          }

          return q.order('naziv');
        },
        fallback: <dynamic>[],
      );

      if (response is List) {
        return response
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      // Debug logging removed for production
      return [];
    }
  }

  /// Dohvata sve rute koje kreću iz određenog grada
  Future<List<Ruta>> getRuteOdGrada(String grad) async {
    return searchRute(polazak: grad, aktivan: true);
  }

  /// Dohvata sve rute koje dolaze u određeni grad
  Future<List<Ruta>> getRuteDoGrada(String grad) async {
    return searchRute(dolazak: grad, aktivan: true);
  }

  /// Dohvata kratke rute (manje od 30km)
  Future<List<Ruta>> getKratkeRute() async {
    return searchRute(aktivan: true, maxUdaljenost: 30);
  }

  /// Dohvata dugačke rute (više od 100km)
  Future<List<Ruta>> getDugackeRute() async {
    return searchRute(aktivan: true, minUdaljenost: 100);
  }

  /// Dohvata brze rute (manje od 30min)
  Future<List<Ruta>> getBrzeRute() async {
    return searchRute(aktivan: true, maxVremeMinuti: 30);
  }

  /// Dohvata spore rute (više od 2h)
  Future<List<Ruta>> getSporeRute() async {
    return searchRute(aktivan: true, minVremeMinuti: 120);
  }

  /// Stream za realtime ažuriranja ruta (poboljšana verzija)
  Stream<List<Ruta>> get ruteStream {
    return _supabase
        .from('rute')
        .stream(primaryKey: ['id'])
        .order('naziv')
        .map((data) => data.map((json) => Ruta.fromMap(json)).toList());
  }

  /// Stream samo za aktivne rute
  Stream<List<Ruta>> get activeRuteStream {
    return _supabase
        .from('rute')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('naziv')
        .map((data) => data.map((json) => Ruta.fromMap(json)).toList());
  }

  // 📦 BATCH OPERACIJE
  /// Kreira više ruta odjednom
  Future<List<Ruta>> batchCreateRute(List<Ruta> rute) async {
    try {
      // Validacija svih ruta
      for (final ruta in rute) {
        final validation = ruta.validateFull();
        if (validation.isNotEmpty) {
          // Debug logging removed for production
          return [];
        }
      }

      final maps = rute.map((r) => r.toMap()).toList();

      final response = await SupabaseSafe.run(
        () => _supabase.from('rute').insert(maps).select(),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final results = response
            .map<Ruta>((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();

        // Očisti cache
        await _clearCache();
        // Debug logging removed for production
        return results;
      }
      return [];
    } catch (e) {
      // Debug logging removed for production
      return [];
    }
  }

  /// Ažurira više ruta odjednom
  Future<List<Ruta>> batchUpdateRute(List<Ruta> rute) async {
    try {
      final results = <Ruta>[];

      for (final ruta in rute) {
        final result = await updateRutaObject(ruta);
        if (result != null) {
          results.add(result);
        }
      }
      // Debug logging removed for production
      return results;
    } catch (e) {
      // Debug logging removed for production
      return [];
    }
  }

  /// Deaktivira više ruta odjednom
  Future<bool> batchDeactivateRute(List<String> ids) async {
    try {
      await SupabaseSafe.run(
        () => _supabase.from('rute').update({
          'aktivan': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).inFilter('id', ids),
      );

      // Očisti cache
      await _clearCache();
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Aktivira više ruta odjednom
  Future<bool> batchActivateRute(List<String> ids) async {
    try {
      await SupabaseSafe.run(
        () => _supabase.from('rute').update({
          'aktivan': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).inFilter('id', ids),
      );

      // Očisti cache
      await _clearCache();
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  // 📊 STATISTIKE I ANALITIKE
  /// Dohvata detaljne statistike za sve rute
  Future<Map<String, dynamic>> getRuteStatistics() async {
    try {
      // Pokušaj cache
      final cacheKey = _getStatsCacheKey();
      final cached = await CacheService.getFromDisk<Map<String, dynamic>>(
        cacheKey,
        maxAge: const Duration(minutes: 30),
      );
      if (cached != null) {
        // Debug logging removed for production
        return cached;
      }

      final rute = await getAllRute();
      final aktivneRute = rute.where((r) => r.aktivan).toList();
      final neaktivneRute = rute.where((r) => !r.aktivan).toList();

      // Osnovne statistike (bez udaljenosti i vremena)
      final ukupnoRuta = rute.length;
      final aktivnihRuta = aktivneRute.length;
      final neaktivnihRuta = neaktivneRute.length;

      final stats = {
        'ukupno_ruta': ukupnoRuta,
        'aktivne_rute': aktivnihRuta,
        'neaktivne_rute': neaktivnihRuta,
        'procenat_aktivnih':
            ukupnoRuta > 0 ? (aktivnihRuta / ukupnoRuta * 100).round() : 0,
        'poslednja_izmena': rute.isNotEmpty
            ? rute
                .map((r) => r.updatedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
                .toIso8601String()
            : null,
      };

      // Keširaj statistike
      await CacheService.saveToDisk(cacheKey, stats);

      return stats;
    } catch (e) {
      // Debug logging removed for production
      return {};
    }
  }

  /// Dohvata statistike za specifičnu rutu
  Future<Map<String, dynamic>> getRutaStatistics(String rutaId) async {
    try {
      // Dobij info o ruti
      final ruta = await getRutaById(rutaId);
      if (ruta == null) return {};

      // Dobij putnici na ovoj ruti
      final putnici = await SupabaseSafe.run(
        () => _supabase
            .from('dnevni_putnici')
            .select('cena, datum, status')
            .eq('ruta_id', rutaId),
        fallback: <dynamic>[],
      );

      if (putnici is! List) return {'ruta_info': ruta.toMap()};

      // Kalkuliši statistike putnika
      final ukupnoPutnika = putnici.length;
      final ukupnaZarada = putnici.fold<double>(
        0,
        (sum, p) => sum + ((p['cena'] as num?)?.toDouble() ?? 0),
      );

      final prosecnaZarada =
          ukupnoPutnika > 0 ? ukupnaZarada / ukupnoPutnika : 0.0;

      // Status distribucija
      final statusCount = <String, int>{};
      for (final p in putnici) {
        final status = p['status'] as String? ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      return {
        'ruta_info': ruta.toMap(),
        'ukupno_putnika': ukupnoPutnika,
        'ukupna_zarada': ukupnaZarada,
        'prosecna_zarada_po_putniku':
            double.parse(prosecnaZarada.toStringAsFixed(2)),
        'status_distribution': statusCount,
        'putnica_po_danu': ukupnoPutnika > 0 && putnici.isNotEmpty
            ? _calculateDailyPassengers(putnici)
            : <String, int>{},
        'generirano': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Debug logging removed for production
      return {};
    }
  }

  /// Pomoćna metoda za kalkulaciju putnika po danima
  Map<String, int> _calculateDailyPassengers(List<dynamic> putnici) {
    final dailyCount = <String, int>{};

    for (final p in putnici) {
      final datum = p['datum'] as String?;
      if (datum != null) {
        final dan = datum.split('T')[0]; // Uzmi samo datum deo
        dailyCount[dan] = (dailyCount[dan] ?? 0) + 1;
      }
    }

    return dailyCount;
  }

  // 📄 EXPORT FUNKCIONALNOST
  /// Exportuje rute u CSV format
  Future<String> exportRuteToCSV({bool sameAktivne = true}) async {
    try {
      final rute = sameAktivne ? await getActiveRute() : await getAllRute();

      final csvLines = <String>[];

      // Header
      csvLines.add(
        'ID,Naziv,Polazak,Dolazak,Opis,Udaljenost (km),Prosečno vreme (min),Aktivan,Kreiran',
      );

      // Data rows
      for (final ruta in rute) {
        csvLines.add(
          [
            ruta.id,
            '"${ruta.naziv}"',
            '"${ruta.opis ?? ''}"',
            ruta.aktivan ? 'Da' : 'Ne',
            ruta.createdAt.toIso8601String(),
          ].join(','),
        );
      }

      final csvContent = csvLines.join('\n');
      // Debug logging removed for production
      return csvContent;
    } catch (e) {
      // Debug logging removed for production
      return '';
    }
  }

  // 🧹 MAINTENANCE FUNKCIJE
  /// Čišćenje starih neaktivnih ruta
  Future<void> cleanupOldInactiveRute({int daysToKeep = 365}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffDateStr = cutoffDate.toIso8601String();

      await SupabaseSafe.run(
        () => _supabase
            .from('rute')
            .delete()
            .eq('aktivan', false)
            .lt('updated_at', cutoffDateStr),
      );

      await _clearCache();
      // Debug logging removed for production
    } catch (e) {
      // Debug logging removed for production
    }
  }

  /// Cache statistike
  Map<String, dynamic> getCacheStats() {
    return CacheService.getStats();
  }
}
