import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ruta.dart';
import '../utils/logging.dart';
import 'cache_service.dart';
import 'supabase_safe.dart';

/// Servis za upravljanje rutama
class RutaService {
  RutaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
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

  /// Dohvata sve rute (sa keširanje)
  Future<List<Ruta>> getAllRute() async {
    try {
      // Pokušaj cache prvo
      final cacheKey = _getAllCacheKey();
      final cached = await CacheService.getFromDisk<List<dynamic>>(cacheKey,
          maxAge: _cacheExpiry,);
      if (cached != null) {
        dlog('📱 [RUTA SERVICE] Vraćam keširane sve rute');
        return cached
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      final response = await SupabaseSafe.run(
        () => _supabase.from('rute').select().order('naziv'),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final dataList = response.cast<Map<String, dynamic>>();

        // Keširaj rezultat
        await CacheService.saveToDisk(cacheKey, dataList);

        return dataList.map((json) => Ruta.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri dohvatanju svih ruta: $e');
      return [];
    }
  }

  /// Dohvata samo aktivne rute (sa keširanje)
  Future<List<Ruta>> getActiveRute() async {
    try {
      // Pokušaj cache prvo
      final cacheKey = _getActiveCacheKey();
      final cached = await CacheService.getFromDisk<List<dynamic>>(cacheKey,
          maxAge: _cacheExpiry,);
      if (cached != null) {
        dlog('📱 [RUTA SERVICE] Vraćam keširane aktivne rute');
        return cached
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }

      final response = await SupabaseSafe.run(
        () =>
            _supabase.from('rute').select().eq('aktivan', true).order('naziv'),
        fallback: <dynamic>[],
      );

      if (response is List) {
        final dataList = response.cast<Map<String, dynamic>>();

        // Keširaj rezultat
        await CacheService.saveToDisk(cacheKey, dataList);

        return dataList.map((json) => Ruta.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri dohvatanju aktivnih ruta: $e');
      return [];
    }
  }

  /// Dohvata rutu po ID-u (sa keširanje i error handling)
  Future<Ruta?> getRutaById(String id) async {
    try {
      // Pokušaj cache prvo
      final cacheKey = _getByIdCacheKey(id);
      final cached = await CacheService.getFromMemory<Ruta>(cacheKey);
      if (cached != null) {
        dlog('📱 [RUTA SERVICE] Vraćam keširanu rutu: $id');
        return cached;
      }

      final response = await SupabaseSafe.run(
        () => _supabase.from('rute').select().eq('id', id).single(),
      );

      if (response == null) {
        dlog('⚠️ [RUTA SERVICE] Ruta sa ID $id ne postoji');
        return null;
      }

      final ruta = Ruta.fromMap(response);

      // Keširaj u memory
      CacheService.saveToMemory(cacheKey, ruta);

      return ruta;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri dohvatanju rute $id: $e');
      return null;
    }
  }

  /// Kreira novu rutu (sa validacijom i cache invalidation)
  Future<Ruta?> createRuta(Ruta ruta) async {
    try {
      // Validacija pre dodavanja
      final validation = ruta.validateFull();
      if (validation.isNotEmpty) {
        dlog(
            '❌ [RUTA SERVICE] Validacija neuspešna: ${validation.values.join(', ')}',);
        return null;
      }

      // Proveri duplikate
      final existingRute =
          await _checkForDuplicates(ruta.polazak, ruta.dolazak, ruta.naziv);
      if (existingRute.isNotEmpty) {
        dlog('❌ [RUTA SERVICE] Duplikat rute već postoji');
        return null;
      }

      final response = await SupabaseSafe.run(
        () => _supabase.from('rute').insert(ruta.toMap()).select().single(),
      );

      if (response == null) return null;

      final novaRuta = Ruta.fromMap(response);

      // Očisti cache
      await _clearCache();

      dlog('✅ [RUTA SERVICE] Kreirana nova ruta: ${novaRuta.naziv}');
      return novaRuta;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri kreiranju rute: $e');
      return null;
    }
  }

  /// Proverava duplikate ruta
  Future<List<Ruta>> _checkForDuplicates(
      String polazak, String dolazak, String naziv,) async {
    try {
      final response = await SupabaseSafe.run(
        () => _supabase
            .from('rute')
            .select()
            .or('and(polazak.eq.$polazak,dolazak.eq.$dolazak),naziv.eq.$naziv'),
        fallback: <dynamic>[],
      );

      if (response is List) {
        return response
            .map((json) => Ruta.fromMap(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri proveravanju duplikata: $e');
      return [];
    }
  }

  /// Ažurira rutu (sa validacijom i cache invalidation)
  Future<Ruta?> updateRuta(String id, Map<String, dynamic> updates) async {
    try {
      // Dodaj timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseSafe.run(
        () => _supabase
            .from('rute')
            .update(updates)
            .eq('id', id)
            .select()
            .single(),
      );

      if (response == null) {
        dlog('⚠️ [RUTA SERVICE] Ruta sa ID $id ne postoji za ažuriranje');
        return null;
      }

      final azuriranaRuta = Ruta.fromMap(response);

      // Validacija nakon ažuriranja
      final validation = azuriranaRuta.validateFull();
      if (validation.isNotEmpty) {
        dlog(
            '❌ [RUTA SERVICE] Ažurirana ruta nije validna: ${validation.values.join(', ')}',);
        return null;
      }

      // Očisti cache
      await _clearCacheForId(id);

      dlog('✅ [RUTA SERVICE] Ažurirana ruta: ${azuriranaRuta.naziv}');
      return azuriranaRuta;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri ažuriranju rute $id: $e');
      return null;
    }
  }

  /// Ažurira celu rutu (alternativa sa Ruta objektom)
  Future<Ruta?> updateRutaObject(Ruta ruta) async {
    try {
      // Validacija
      final validation = ruta.validateFull();
      if (validation.isNotEmpty) {
        dlog(
            '❌ [RUTA SERVICE] Validacija neuspešna: ${validation.values.join(', ')}',);
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

      dlog('✅ [RUTA SERVICE] Ažurirana ruta objekat: ${result.naziv}');
      return result;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri ažuriranju rute objekta: $e');
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

      dlog('✅ [RUTA SERVICE] Deaktivirana ruta: $id');
      return true;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri deaktiviranju rute $id: $e');
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

      dlog('✅ [RUTA SERVICE] Aktivirana ruta: $id');
      return true;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri aktiviranju rute $id: $e');
      return false;
    }
  }

  /// Briše rutu potpuno (hard delete)
  Future<bool> deleteRuta(String id) async {
    try {
      // Prvo proveri da li postoje povezani putnici
      final hasDependencies = await _checkRutaDependencies(id);
      if (hasDependencies) {
        dlog(
            '❌ [RUTA SERVICE] Ne može se obrisati ruta $id - ima povezane putnike',);
        return false;
      }

      await SupabaseSafe.run(
        () => _supabase.from('rute').delete().eq('id', id),
      );

      // Očisti cache
      await _clearCacheForId(id);

      dlog('✅ [RUTA SERVICE] Obrisana ruta: $id');
      return true;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri brisanju rute $id: $e');
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
      dlog('❌ [RUTA SERVICE] Greška pri proveravanju zavisnosti: $e');
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
        final cached = await CacheService.getFromMemory<List<Ruta>>(cacheKey);
        if (cached != null) {
          dlog('📱 [RUTA SERVICE] Vraćam keširane rezultate pretrage');
          return cached;
        }
      }

      final response = await SupabaseSafe.run(
        () {
          var q = _supabase.from('rute').select();

          // Tekstualna pretraga
          if (query != null && query.isNotEmpty) {
            q = q.or(
                'naziv.ilike.%$query%,polazak.ilike.%$query%,dolazak.ilike.%$query%,opis.ilike.%$query%',);
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
                'prosecno_vreme', minVremeMinuti * 60,); // Konvertuj u sekunde
          }
          if (maxVremeMinuti != null) {
            q = q.lte(
                'prosecno_vreme', maxVremeMinuti * 60,); // Konvertuj u sekunde
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
      dlog('❌ [RUTA SERVICE] Greška pri pretrazi ruta: $e');
      return [];
    }
  }

  /// Traži rute po nazivu, polasku ili destinaciji (stara metoda za kompatibilnost)
  Future<List<Ruta>> searchRuteSimple(String query) async {
    return searchRute(query: query, aktivan: true);
  }

  /// Dohvata rute između dva grada (poboljšana verzija)
  Future<List<Ruta>> getRuteIzmedju(String polazak, String destinacija,
      {bool sameAktivan = true,}) async {
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
      dlog(
          '❌ [RUTA SERVICE] Greška pri dohvatanju ruta između $polazak i $destinacija: $e',);
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
          dlog(
              '❌ [RUTA SERVICE] Batch validacija neuspešna za ${ruta.naziv}: ${validation.values.join(', ')}',);
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

        dlog('✅ [RUTA SERVICE] Batch kreirano ${results.length} ruta');
        return results;
      }
      return [];
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri batch kreiranju ruta: $e');
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

      dlog(
          '✅ [RUTA SERVICE] Batch ažurirano ${results.length}/${rute.length} ruta',);
      return results;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri batch ažuriranju ruta: $e');
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

      dlog('✅ [RUTA SERVICE] Batch deaktivirano ${ids.length} ruta');
      return true;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri batch deaktiviranju ruta: $e');
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

      dlog('✅ [RUTA SERVICE] Batch aktivirano ${ids.length} ruta');
      return true;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri batch aktiviranju ruta: $e');
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
          maxAge: const Duration(minutes: 30),);
      if (cached != null) {
        dlog('📱 [RUTA SERVICE] Vraćam keširane statistike');
        return cached;
      }

      final rute = await getAllRute();
      final aktivneRute = rute.where((r) => r.aktivan).toList();
      final neaktivneRute = rute.where((r) => !r.aktivan).toList();

      // Kalkuliši statistike
      final ukupnaUdaljenost = aktivneRute
          .where((r) => r.udaljenostKm != null)
          .fold<double>(0, (sum, r) => sum + r.udaljenostKm!);

      final prosecnaUdaljenost =
          aktivneRute.where((r) => r.udaljenostKm != null).isNotEmpty
              ? ukupnaUdaljenost /
                  aktivneRute.where((r) => r.udaljenostKm != null).length
              : 0.0;

      final ukupnoVreme = aktivneRute
          .where((r) => r.prosecnoVreme != null)
          .fold<int>(0, (sum, r) => sum + r.prosecnoVreme!.inMinutes);

      final prosecnoVreme =
          aktivneRute.where((r) => r.prosecnoVreme != null).isNotEmpty
              ? ukupnoVreme /
                  aktivneRute.where((r) => r.prosecnoVreme != null).length
              : 0.0;

      // Grupisanje po gradovima
      final polasciCount = <String, int>{};
      final dolasciCount = <String, int>{};

      for (final ruta in aktivneRute) {
        polasciCount[ruta.polazak] = (polasciCount[ruta.polazak] ?? 0) + 1;
        dolasciCount[ruta.dolazak] = (dolasciCount[ruta.dolazak] ?? 0) + 1;
      }

      final stats = {
        'ukupno_ruta': rute.length,
        'aktivne_rute': aktivneRute.length,
        'neaktivne_rute': neaktivneRute.length,
        'procenat_aktivnih': rute.isNotEmpty
            ? (aktivneRute.length / rute.length * 100).round()
            : 0,
        'ukupna_udaljenost_km': ukupnaUdaljenost,
        'prosecna_udaljenost_km':
            double.parse(prosecnaUdaljenost.toStringAsFixed(1)),
        'ukupno_vreme_minuti': ukupnoVreme,
        'prosecno_vreme_minuti': double.parse(prosecnoVreme.toStringAsFixed(1)),
        'najčešći_polazak': polasciCount.isNotEmpty
            ? polasciCount.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
            : null,
        'najčešći_dolazak': dolasciCount.isNotEmpty
            ? dolasciCount.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
            : null,
        'polasci_distribution': polasciCount,
        'dolasci_distribution': dolasciCount,
        'kratke_rute': aktivneRute.where((r) => r.jeKratkaRuta).length,
        'dugačke_rute': aktivneRute.where((r) => r.jeDugackaRuta).length,
        'brze_rute': aktivneRute.where((r) => r.jeBrzaRuta).length,
        'spore_rute': aktivneRute.where((r) => r.jeSporaRuta).length,
        'generirano': DateTime.now().toIso8601String(),
      };

      // Keširaj statistike
      await CacheService.saveToDisk(cacheKey, stats);

      return stats;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri dobijanju statistika: $e');
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
        'zarada_po_km': ruta.udaljenostKm != null && ruta.udaljenostKm! > 0
            ? double.parse(
                (ukupnaZarada / ruta.udaljenostKm!).toStringAsFixed(2),)
            : 0.0,
        'putnika_po_danu': ukupnoPutnika > 0 && putnici.isNotEmpty
            ? _calculateDailyPassengers(putnici)
            : <String, int>{},
        'generirano': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      dlog(
          '❌ [RUTA SERVICE] Greška pri dobijanju statistika za rutu $rutaId: $e',);
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
          'ID,Naziv,Polazak,Dolazak,Opis,Udaljenost (km),Prosečno vreme (min),Aktivan,Kreiran',);

      // Data rows
      for (final ruta in rute) {
        csvLines.add(
          [
            ruta.id,
            '"${ruta.naziv}"',
            '"${ruta.polazak}"',
            '"${ruta.dolazak}"',
            '"${ruta.opis ?? ''}"',
            ruta.udaljenostKm?.toString() ?? '',
            ruta.prosecnoVreme?.inMinutes.toString() ?? '',
            ruta.aktivan ? 'Da' : 'Ne',
            ruta.createdAt.toIso8601String(),
          ].join(','),
        );
      }

      final csvContent = csvLines.join('\n');
      dlog('✅ [RUTA SERVICE] Exportovano ${rute.length} ruta u CSV');

      return csvContent;
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri CSV export: $e');
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

      dlog(
          '✅ [RUTA SERVICE] Očišćene stare neaktivne rute starije od $cutoffDateStr',);
    } catch (e) {
      dlog('❌ [RUTA SERVICE] Greška pri čišćenju starih ruta: $e');
    }
  }

  /// Cache statistike
  Map<String, dynamic> getCacheStats() {
    return CacheService.getStats();
  }
}
