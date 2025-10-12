import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import '../models/putovanja_istorija.dart';
import '../utils/logging.dart';
import 'cache_service.dart';
import 'realtime_service.dart';
import 'supabase_safe.dart';

// Use centralized logger

class PutovanjaIstorijaService {
  static final _supabase = Supabase.instance.client;

  // Cache configuration
  static const String _cacheKeyPrefix = 'putovanja_istorija';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Cache keys
  static String _getAllCacheKey() => '${_cacheKeyPrefix}_all';
  static String _getByDateCacheKey(DateTime date) =>
      '${_cacheKeyPrefix}_date_${date.toIso8601String().split('T')[0]}';
  static String _getByMesecniCacheKey(String mesecniPutnikId) =>
      '${_cacheKeyPrefix}_mesecni_$mesecniPutnikId';
  static String _getSearchCacheKey(String query) =>
      '${_cacheKeyPrefix}_search_$query';

  // Clear cache methods
  static Future<void> _clearCache() async {
    await CacheService.clearAll();
  }

  static Future<void> _clearCacheForDate(DateTime date) async {
    final cacheKey = _getByDateCacheKey(date);
    await CacheService.clearFromDisk(cacheKey);
    await CacheService.clearFromDisk(_getAllCacheKey());
  }

  static Future<void> _clearCacheForMesecni(String mesecniPutnikId) async {
    final cacheKey = _getByMesecniCacheKey(mesecniPutnikId);
    await CacheService.clearFromDisk(cacheKey);
    await CacheService.clearFromDisk(_getAllCacheKey());
  }

  // 📱 REALTIME STREAM svih putovanja
  static Stream<List<PutovanjaIstorija>> streamPutovanjaIstorija() {
    try {
      return RealtimeService.instance.putovanjaStream.map((data) {
        try {
          final list =
              data.map((json) => PutovanjaIstorija.fromMap(json)).toList();
          list.sort((a, b) {
            final cmp = b.datum.compareTo(a.datum);
            if (cmp != 0) return cmp;
            return b.vremePolaska.compareTo(a.vremePolaska);
          });
          return list;
        } catch (e) {
          dlog(
            '❌ [PUTOVANJA ISTORIJA SERVICE] Error mapping realtime data: $e',
          );
          return <PutovanjaIstorija>[];
        }
      });
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream: $e');
      return Stream.value([]);
    }
  }

  // 📱 REALTIME STREAM putovanja za određeni datum
  static Stream<List<PutovanjaIstorija>> streamPutovanjaZaDatum(
    DateTime datum,
  ) {
    try {
      final targetDate = datum.toIso8601String().split('T')[0];

      return RealtimeService.instance.putovanjaStream.map((data) {
        try {
          final list = data
              .map((json) => PutovanjaIstorija.fromMap(json))
              .where(
                (p) => p.datum.toIso8601String().split('T')[0] == targetDate,
              )
              .toList();
          list.sort((a, b) => a.vremePolaska.compareTo(b.vremePolaska));
          return list;
        } catch (e) {
          dlog(
            '❌ [PUTOVANJA ISTORIJA SERVICE] Error mapping realtime data for date: $e',
          );
          return <PutovanjaIstorija>[];
        }
      });
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream za datum: $e');
      return Stream.value([]);
    }
  }

  // 📱 REALTIME STREAM putovanja za mesečnog putnika
  static Stream<List<PutovanjaIstorija>> streamPutovanjaMesecnogPutnika(
    String mesecniPutnikId,
  ) {
    try {
      return RealtimeService.instance.putovanjaStream.map((data) {
        try {
          final list = data
              .map((json) => PutovanjaIstorija.fromMap(json))
              .where((p) => p.mesecniPutnikId == mesecniPutnikId)
              .toList();
          list.sort((a, b) => b.datum.compareTo(a.datum));
          return list;
        } catch (e) {
          dlog(
            '❌ [PUTOVANJA ISTORIJA SERVICE] Error mapping realtime data for mesecni: $e',
          );
          return <PutovanjaIstorija>[];
        }
      });
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška u stream za mesečnog putnika: $e',
      );
      return Stream.value([]);
    }
  }

  // 🔍 DOBIJ sva putovanja (with caching)
  static Future<List<PutovanjaIstorija>> getAllPutovanjaIstorija() async {
    try {
      // Try cache first
      final cacheKey = _getAllCacheKey();
      final cached = await CacheService.getFromDisk<List<dynamic>>(
        cacheKey,
        maxAge: _cacheExpiry,
      );
      if (cached != null) {
        dlog('📱 [PUTOVANJA ISTORIJA SERVICE] Returning cached all data');
        return cached
            .map(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();
      }

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .select()
            .order('datum_putovanja', ascending: false)
            .order('vreme_polaska', ascending: false),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final dataList = response.cast<Map<String, dynamic>>();

        // Cache the result
        await CacheService.saveToDisk(cacheKey, dataList);

        return dataList
            .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
            .toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju svih: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja za određeni datum (with caching)
  static Future<List<PutovanjaIstorija>> getPutovanjaZaDatum(
    DateTime datum,
  ) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      // Try cache first
      final cacheKey = _getByDateCacheKey(datum);
      final cached = await CacheService.getFromDisk<List<dynamic>>(
        cacheKey,
        maxAge: _cacheExpiry,
      );
      if (cached != null) {
        dlog(
          '📱 [PUTOVANJA ISTORIJA SERVICE] Returning cached data for date: $datumStr',
        );
        return cached
            .map(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();
      }

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .select()
            .eq('datum_putovanja', datumStr)
            .order('vreme_polaska'),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final dataList = response.cast<Map<String, dynamic>>();

        // Cache the result
        await CacheService.saveToDisk(cacheKey, dataList);

        return dataList
            .map<PutovanjaIstorija>((json) => PutovanjaIstorija.fromMap(json))
            .toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za datum: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja za vremenski opseg
  static Future<List<PutovanjaIstorija>> getPutovanjaZaOpseg(
    DateTime odDatuma,
    DateTime doDatuma,
  ) async {
    try {
      final odStr = odDatuma.toIso8601String().split('T')[0];
      final doStr = doDatuma.toIso8601String().split('T')[0];

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .select()
            .gte('datum', odStr)
            .lte('datum', doStr)
            .order('datum', ascending: false)
            .order('vreme_polaska'),
        fallback: <dynamic>[],
      );

      if (response is List) {
        return response
            .map<PutovanjaIstorija>(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za opseg: $e');
      return [];
    }
  }

  // 🔍 DOBIJ putovanja po ID
  static Future<PutovanjaIstorija?> getPutovanjeById(String id) async {
    try {
      final response = await SupabaseSafe.run(
        () =>
            _supabase.from('putovanja_istorija').select().eq('id', id).single(),
      );

      if (response == null) return null;
      return PutovanjaIstorija.fromMap(response);
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju po ID: $e');
      return null;
    }
  }

  // 🔍 DOBIJ putovanja mesečnog putnika
  static Future<List<PutovanjaIstorija>> getPutovanjaMesecnogPutnika(
    String mesecniPutnikId,
  ) async {
    try {
      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .select()
            .eq('mesecni_putnik_id', mesecniPutnikId)
            .order('datum', ascending: false),
        fallback: <dynamic>[],
      );

      if (response is List) {
        return response
            .map<PutovanjaIstorija>(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dohvatanju za mesečnog putnika: $e',
      );
      return [];
    }
  }

  // ➕ DODAJ novo putovanje (with cache invalidation)
  static Future<PutovanjaIstorija?> dodajPutovanje(
    PutovanjaIstorija putovanje,
  ) async {
    try {
      // Validate before adding
      final validation = putovanje.validateFull();
      if (validation.isNotEmpty) {
        dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Validation failed: ${validation.values.join(', ')}',
        );
        return null;
      }

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .insert(putovanje.toMap())
            .select()
            .single(),
      );

      if (response == null) return null;

      final result = PutovanjaIstorija.fromMap(response);

      // Clear cache
      await _clearCacheForDate(result.datum);
      if (result.mesecniPutnikId != null) {
        await _clearCacheForMesecni(result.mesecniPutnikId!);
      }

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Dodato putovanje: ${putovanje.putnikIme}',
      );

      return result;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju: $e');
      return null;
    }
  }

  // ➕ DODAJ novo putovanje za mesečnog putnika
  static Future<PutovanjaIstorija?> dodajPutovanjeMesecnogPutnika({
    required MesecniPutnik mesecniPutnik,
    required DateTime datum,
    required String vremePolaska,
    required String adresaPolaska,
    String status = 'nije_se_pojavio',
    double cena = 0.0,
  }) async {
    try {
      final putovanje = PutovanjaIstorija(
        id: '', // Biće generisan od strane baze
        mesecniPutnikId: mesecniPutnik.id,
        tipPutnika: 'mesecni',
        datum: datum,
        vremePolaska: vremePolaska,
        vremeAkcije: DateTime.now(),
        adresaPolaska: adresaPolaska,
        status: status,
        pokupljen: status == 'pokupljen',
        putnikIme: mesecniPutnik.putnikIme,
        brojTelefona: mesecniPutnik.brojTelefona,
        cena: cena,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await dodajPutovanje(putovanje);
      if (result != null) {
        await _clearCacheForDate(datum);
        await _clearCacheForMesecni(mesecniPutnik.id);
      }
      return result;
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju mesečnog putovanja: $e',
      );
      return null;
    }
  }

  // ➕ DODAJ novo putovanje za dnevnog putnika
  static Future<PutovanjaIstorija?> dodajPutovanjeDnevnogPutnika({
    required String putnikIme,
    required DateTime datum,
    required String vremePolaska,
    required String adresaPolaska,
    String? brojTelefona,
    String status = 'nije_se_pojavio',
    double cena = 0.0,
  }) async {
    try {
      final putovanje = PutovanjaIstorija(
        id: '', // Biće generisan od strane baze
        tipPutnika: 'dnevni',
        datum: datum,
        vremePolaska: vremePolaska,
        vremeAkcije: DateTime.now(),
        adresaPolaska: adresaPolaska,
        status: status,
        pokupljen: status == 'pokupljen',
        putnikIme: putnikIme,
        brojTelefona: brojTelefona,
        cena: cena,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await dodajPutovanje(putovanje);
      if (result != null) {
        await _clearCacheForDate(datum);
      }
      return result;
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dodavanju dnevnog putovanja: $e',
      );
      return null;
    }
  }

  // ✏️ AŽURIRAJ putovanje (with cache invalidation)
  static Future<PutovanjaIstorija?> azurirajPutovanje(
    PutovanjaIstorija putovanje,
  ) async {
    try {
      // Validate before updating
      final validation = putovanje.validateFull();
      if (validation.isNotEmpty) {
        dlog(
          '❌ [PUTOVANJA ISTORIJA SERVICE] Validation failed: ${validation.values.join(', ')}',
        );
        return null;
      }

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .update(putovanje.toMap())
            .eq('id', putovanje.id)
            .select()
            .single(),
      );

      if (response == null) return null;

      final result = PutovanjaIstorija.fromMap(response);

      // Clear cache
      await _clearCacheForDate(result.datum);
      if (result.mesecniPutnikId != null) {
        await _clearCacheForMesecni(result.mesecniPutnikId!);
      }

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Ažurirano putovanje: ${putovanje.putnikIme}',
      );

      return result;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri ažuriranju: $e');
      return null;
    }
  }

  // ✏️ AŽURIRAJ status putovanja
  static Future<bool> azurirajStatus({
    required String putovanjeId,
    String? statusBelaCrkvaVrsac,
    String? statusVrsacBelaCrkva,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Jednostavno ažuriranje - koristi jednu status kolonu
      if (statusBelaCrkvaVrsac != null || statusVrsacBelaCrkva != null) {
        // Ako je bilo koji status dat, koristi ga kao glavnog statusa
        final noviStatus = statusBelaCrkvaVrsac ?? statusVrsacBelaCrkva;
        updateData['status'] = noviStatus;
        updateData['pokupljen'] = noviStatus == 'pokupljen';

        if (noviStatus == 'pokupljen') {
          updateData['vreme_pokupljenja'] = DateTime.now().toIso8601String();
        }
      }

      await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .update(updateData)
            .eq('id', putovanjeId),
        fallback: <dynamic>[],
      );

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Ažuriran status putovanja: $putovanjeId',
      );

      return true;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri ažuriranju statusa: $e');
      return false;
    }
  }

  // 🗑️ OBRIŠI putovanje (with cache invalidation)
  static Future<bool> obrisiPutovanje(String id) async {
    try {
      // Get the putovanje first to clear specific cache
      final putovanje = await getPutovanjeById(id);

      await SupabaseSafe.run(
        () => _supabase.from('putovanja_istorija').delete().eq('id', id),
        fallback: <dynamic>[],
      );

      // Clear cache
      if (putovanje != null) {
        await _clearCacheForDate(putovanje.datum);
        if (putovanje.mesecniPutnikId != null) {
          await _clearCacheForMesecni(putovanje.mesecniPutnikId!);
        }
      }

      dlog('✅ [PUTOVANJA ISTORIJA SERVICE] Obrisano putovanje: $id');

      return true;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri brisanju: $e');
      return false;
    }
  }

  // 📊 STATISTIKE - ukupan broj putovanja
  static Future<int> getBrojPutovanja({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      final response = await SupabaseSafe.run(
        () {
          var q = _supabase.from('putovanja_istorija').select();
          if (odDatuma != null) {
            q = q.gte('datum', odDatuma.toIso8601String().split('T')[0]);
          }
          if (doDatuma != null) {
            q = q.lte('datum', doDatuma.toIso8601String().split('T')[0]);
          }
          if (tipPutnika != null) {
            q = q.eq('tip_putnika', tipPutnika);
          }
          if (mesecniPutnikId != null) {
            q = q.eq('mesecni_putnik_id', mesecniPutnikId);
          }
          return q;
        },
        fallback: <dynamic>[],
      );

      final list = response is List ? response : <dynamic>[];
      return list.length;
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dobijanju broja putovanja: $e',
      );
      return 0;
    }
  }

  // 📊 STATISTIKE - ukupna zarada
  static Future<double> getUkupnaZarada({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      final response = await SupabaseSafe.run(
        () {
          var q = _supabase.from('putovanja_istorija').select('cena');
          if (odDatuma != null) {
            q = q.gte('datum', odDatuma.toIso8601String().split('T')[0]);
          }
          if (doDatuma != null) {
            q = q.lte('datum', doDatuma.toIso8601String().split('T')[0]);
          }
          if (tipPutnika != null) {
            q = q.eq('tip_putnika', tipPutnika);
          }
          if (mesecniPutnikId != null) {
            q = q.eq('mesecni_putnik_id', mesecniPutnikId);
          }
          return q;
        },
        fallback: <dynamic>[],
      );

      final list = response is List ? response : <dynamic>[];
      double ukupno = 0.0;
      for (final item in list) {
        ukupno += (item['cena'] as num?)?.toDouble() ?? 0.0;
      }

      return ukupno;
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dobijanju ukupne zarade: $e',
      );
      return 0.0;
    }
  }

  // 🔍 NAPREDNA PRETRAGA
  static Future<List<PutovanjaIstorija>> searchPutovanja({
    String? query,
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? status,
    String? mesecniPutnikId,
    bool? pokupljen,
    int limit = 100,
  }) async {
    try {
      // Try cache first if simple query
      String? cacheKey;
      if (query != null && query.length > 2) {
        cacheKey = _getSearchCacheKey(query);
        final cached =
            await CacheService.getFromMemory<List<PutovanjaIstorija>>(cacheKey);
        if (cached != null) {
          dlog(
            '📱 [PUTOVANJA ISTORIJA SERVICE] Returning cached search results',
          );
          return cached;
        }
      }

      final response = await SupabaseSafe.run(
        () {
          var q = _supabase.from('putovanja_istorija').select();

          // Text search
          if (query != null && query.isNotEmpty) {
            q = q.or(
              'putnik_ime.ilike.%$query%,adresa_polaska.ilike.%$query%,broj_telefona.ilike.%$query%',
            );
          }

          // Date range
          if (odDatuma != null) {
            q = q.gte(
              'datum_putovanja',
              odDatuma.toIso8601String().split('T')[0],
            );
          }
          if (doDatuma != null) {
            q = q.lte(
              'datum_putovanja',
              doDatuma.toIso8601String().split('T')[0],
            );
          }

          // Filters
          if (tipPutnika != null) {
            q = q.eq('tip_putnika', tipPutnika);
          }
          if (status != null) {
            q = q.eq('status', status);
          }
          if (mesecniPutnikId != null) {
            q = q.eq('mesecni_putnik_id', mesecniPutnikId);
          }
          if (pokupljen != null) {
            q = q.eq('pokupljen', pokupljen);
          }

          return q
              .order('datum_putovanja', ascending: false)
              .order('vreme_polaska', ascending: false)
              .limit(limit);
        },
        fallback: <dynamic>[],
      );

      if (response is List) {
        final results = response
            .map<PutovanjaIstorija>(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();

        // Cache simple search results
        if (cacheKey != null) {
          CacheService.saveToMemory(cacheKey, results);
        }

        return results;
      }
      return [];
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri pretrazi: $e');
      return [];
    }
  }

  // 📦 BATCH OPERACIJE - dodavanje više putovanja odjednom
  static Future<List<PutovanjaIstorija>> batchDodajPutovanja(
    List<PutovanjaIstorija> putovanja,
  ) async {
    try {
      // Validate all first
      for (final putovanje in putovanja) {
        final validation = putovanje.validateFull();
        if (validation.isNotEmpty) {
          dlog(
            '❌ [PUTOVANJA ISTORIJA SERVICE] Batch validation failed for ${putovanje.putnikIme}: ${validation.values.join(', ')}',
          );
          return [];
        }
      }

      final maps = putovanja.map((p) => p.toMap()).toList();

      final response = await SupabaseSafe.run(
        () => _supabase.from('putovanja_istorija').insert(maps).select(),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final results = response
            .map<PutovanjaIstorija>(
              (json) => PutovanjaIstorija.fromMap(json as Map<String, dynamic>),
            )
            .toList();

        // Clear cache for all affected dates
        final affectedDates = putovanja.map((p) => p.datum).toSet();
        for (final datum in affectedDates) {
          await _clearCacheForDate(datum);
        }

        // Clear cache for all affected mesecni putnici
        final affectedMesecni = putovanja
            .map((p) => p.mesecniPutnikId)
            .where((id) => id != null)
            .cast<String>()
            .toSet();
        for (final mesecniId in affectedMesecni) {
          await _clearCacheForMesecni(mesecniId);
        }

        dlog(
          '✅ [PUTOVANJA ISTORIJA SERVICE] Batch dodano ${results.length} putovanja',
        );
        return results;
      }
      return [];
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri batch dodavanju: $e');
      return [];
    }
  }

  // 📦 BATCH OPERACIJE - ažuriranje više putovanja odjednom
  static Future<List<PutovanjaIstorija>> batchAzurirajPutovanja(
    List<PutovanjaIstorija> putovanja,
  ) async {
    try {
      final results = <PutovanjaIstorija>[];

      for (final putovanje in putovanja) {
        final result = await azurirajPutovanje(putovanje);
        if (result != null) {
          results.add(result);
        }
      }

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Batch ažurirano ${results.length}/${putovanja.length} putovanja',
      );
      return results;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri batch ažuriranju: $e');
      return [];
    }
  }

  // 📦 BATCH OPERACIJE - brisanje više putovanja odjednom
  static Future<bool> batchObrisiPutovanja(List<String> ids) async {
    try {
      // Get all putovanja first for cache clearing
      final putovanja = <PutovanjaIstorija>[];
      for (final id in ids) {
        final putovanje = await getPutovanjeById(id);
        if (putovanje != null) {
          putovanja.add(putovanje);
        }
      }

      await SupabaseSafe.run(
        () => _supabase.from('putovanja_istorija').delete().inFilter('id', ids),
        fallback: <dynamic>[],
      );

      // Clear cache for all affected dates and mesecni putnici
      final affectedDates = putovanja.map((p) => p.datum).toSet();
      for (final datum in affectedDates) {
        await _clearCacheForDate(datum);
      }

      final affectedMesecni = putovanja
          .map((p) => p.mesecniPutnikId)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      for (final mesecniId in affectedMesecni) {
        await _clearCacheForMesecni(mesecniId);
      }

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Batch obrisano ${ids.length} putovanja',
      );
      return true;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri batch brisanju: $e');
      return false;
    }
  }

  // 📊 NAPREDNE STATISTIKE
  static Future<Map<String, dynamic>> getDetailedStatistics({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      final putovanja = await searchPutovanja(
        odDatuma: odDatuma,
        doDatuma: doDatuma,
        tipPutnika: tipPutnika,
        mesecniPutnikId: mesecniPutnikId,
        limit: 10000,
      );

      final ukupno = putovanja.length;
      final pokupljeni = putovanja.where((p) => p.pokupljen).length;
      final nisu_se_pojavili =
          putovanja.where((p) => p.status == 'nije_se_pojavio').length;
      final ukupnaZarada =
          putovanja.fold<double>(0.0, (sum, p) => sum + p.cena);

      final statusDistribution = <String, int>{};
      final tipPutnikaDistribution = <String, int>{};
      final dailyCount = <String, int>{};

      for (final putovanje in putovanja) {
        // Status distribution
        statusDistribution[putovanje.status] =
            (statusDistribution[putovanje.status] ?? 0) + 1;

        // Tip putnika distribution
        tipPutnikaDistribution[putovanje.tipPutnika] =
            (tipPutnikaDistribution[putovanje.tipPutnika] ?? 0) + 1;

        // Daily count
        final dan = putovanje.datum.toIso8601String().split('T')[0];
        dailyCount[dan] = (dailyCount[dan] ?? 0) + 1;
      }

      return {
        'ukupno_putovanja': ukupno,
        'pokupljeni': pokupljeni,
        'nisu_se_pojavili': nisu_se_pojavili,
        'procenat_pokupljenih':
            ukupno > 0 ? (pokupljeni / ukupno * 100).round() : 0,
        'ukupna_zarada': ukupnaZarada,
        'prosecna_zarada_po_putovanju':
            ukupno > 0 ? ukupnaZarada / ukupno : 0.0,
        'status_distribution': statusDistribution,
        'tip_putnika_distribution': tipPutnikaDistribution,
        'daily_count': dailyCount,
        'period_start': odDatuma?.toIso8601String().split('T')[0],
        'period_end': doDatuma?.toIso8601String().split('T')[0],
      };
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri dobijanju detaljnih statistika: $e',
      );
      return {};
    }
  }

  // 📄 EXPORT funkcionalnost
  static Future<String> exportToCSV({
    DateTime? odDatuma,
    DateTime? doDatuma,
    String? tipPutnika,
    String? mesecniPutnikId,
  }) async {
    try {
      final putovanja = await searchPutovanja(
        odDatuma: odDatuma,
        doDatuma: doDatuma,
        tipPutnika: tipPutnika,
        mesecniPutnikId: mesecniPutnikId,
        limit: 10000,
      );

      final csvLines = <String>[];

      // Header
      csvLines.add(
        'ID,Tip Putnika,Datum,Vreme Polaska,Putnik,Telefon,Adresa,Status,Pokupljen,Cena,Kreiran',
      );

      // Data rows
      for (final putovanje in putovanja) {
        csvLines.add(
          [
            putovanje.id,
            putovanje.tipPutnika,
            putovanje.datum.toIso8601String().split('T')[0],
            putovanje.vremePolaska,
            '"${putovanje.putnikIme}"',
            putovanje.brojTelefona ?? '',
            '"${putovanje.adresaPolaska}"',
            putovanje.status,
            putovanje.pokupljen ? 'Da' : 'Ne',
            putovanje.cena.toString(),
            putovanje.createdAt.toIso8601String(),
          ].join(','),
        );
      }

      final csvContent = csvLines.join('\n');
      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Exported ${putovanja.length} records to CSV',
      );

      return csvContent;
    } catch (e) {
      dlog('❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri CSV export: $e');
      return '';
    }
  }

  // 🧹 MAINTENANCE funkcije
  static Future<void> cleanupOldRecords({
    int daysToKeep = 365,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

      await SupabaseSafe.run(
        () => _supabase
            .from('putovanja_istorija')
            .delete()
            .lt('datum_putovanja', cutoffDateStr),
      );

      await _clearCache();

      dlog(
        '✅ [PUTOVANJA ISTORIJA SERVICE] Cleaned up records older than $cutoffDateStr',
      );
    } catch (e) {
      dlog(
        '❌ [PUTOVANJA ISTORIJA SERVICE] Greška pri čišćenju starih zapisa: $e',
      );
    }
  }

  // 📊 CACHE STATISTIKE
  static Map<String, dynamic> getCacheStats() {
    return CacheService.getStats();
  }
}
