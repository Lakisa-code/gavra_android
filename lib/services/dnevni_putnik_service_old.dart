import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adresa.dart';
import '../models/dnevni_putnik.dart';
import '../models/putnik.dart';
import '../models/ruta.dart';
import '../utils/logging.dart';
import 'adresa_service.dart';
import 'cache_service.dart';

/// Servis za upravljanje dnevnim putnicima
class DnevniPutnikService {
  DnevniPutnikService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;
  final _cacheService = CacheService();

  // 🚀 NAPREDNI CACHE SISTEM
  static const String _cachePrefix = 'dnevni_putnik';
  static const String _listCachePrefix = 'dnevni_putnik_list';
  static const String _statsCachePrefix = 'dnevni_putnik_stats';
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _listCacheExpiry = Duration(minutes: 5);
  static const Duration _statsCacheExpiry = Duration(minutes: 15);

  // Legacy cache za adrese i rute (zadržavam zbog kompatibilnosti)
  final Map<String, Adresa> _adresaCache = {};
  final Map<String, Ruta> _rutaCache = {};

  // ✅ NAPREDNI CRUD METODE

  /// Dohvata dnevnog putnika po ID-u sa cache-om
  Future<DnevniPutnik?> getDnevniPutnikById(String id) async {
    try {
      // Pokušaj iz cache-a
      final cacheKey = '${_cachePrefix}_$id';
      final cached = await _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        dlog('🟢 Cache hit for dnevni putnik: $id');
        return DnevniPutnik.fromMap(cached);
      }

      dlog('🔵 Cache miss for dnevni putnik: $id, fetching from database');
      final response = await _supabase
          .from('dnevni_putnici')
          .select()
          .eq('id', id)
          .eq('obrisan', false)
          .single();

      final putnik = DnevniPutnik.fromMap(response);
      
      // Sačuvaj u cache
      await _cacheService.set(cacheKey, response, _cacheExpiry);
      
      dlog('✅ Fetched and cached dnevni putnik: ${putnik.ime}');
      return putnik;
    } catch (e) {
      dlog('❌ Error fetching dnevni putnik $id: $e');
      return null;
    }
  }

  /// Kreira novog dnevnog putnika sa validacijom
  Future<DnevniPutnik> createDnevniPutnik(DnevniPutnik putnik) async {
    try {
      // Kompletna validacija
      final validationErrors = putnik.validateFull();
      if (validationErrors.isNotEmpty) {
        throw Exception('Validacijske greške: ${validationErrors.values.join(', ')}');
      }

      // Dodatna business validacija
      if (!await validateNoviPutnik(putnik)) {
        throw Exception('Business validacija neuspešna');
      }

      final data = putnik.toMap();
      data.remove('id'); // ID generiše baza

      final response = await _supabase
          .from('dnevni_putnici')
          .insert(data)
          .select()
          .single();

      final noviPutnik = DnevniPutnik.fromMap(response);
      
      // Očisti cache liste
      await _clearListCaches();
      
      // Sačuvaj u cache
      final cacheKey = '${_cachePrefix}_${noviPutnik.id}';
      await _cacheService.set(cacheKey, response, _cacheExpiry);
      
      dlog('✅ Created dnevni putnik: ${noviPutnik.ime} [${noviPutnik.id}]');
      return noviPutnik;
    } catch (e) {
      dlog('❌ Error creating dnevni putnik: $e');
      rethrow;
    }
  }

  /// Ažurira dnevnog putnika sa validacijom
  Future<DnevniPutnik> updateDnevniPutnik(String id, Map<String, dynamic> updates) async {
    try {
      // Dohvati postojećeg putnika
      final postojeci = await getDnevniPutnikById(id);
      if (postojeci == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      // Kreiraj ažurirani objekat za validaciju
      final updatedData = postojeci.toMap()..addAll(updates);
      updatedData['updated_at'] = DateTime.now().toIso8601String();
      
      final ažuriraniPutnik = DnevniPutnik.fromMap(updatedData);
      
      // Validacija
      final validationErrors = ažuriraniPutnik.validateFull();
      if (validationErrors.isNotEmpty) {
        throw Exception('Validacijske greške: ${validationErrors.values.join(', ')}');
      }

      final response = await _supabase
          .from('dnevni_putnici')
          .update(updates..['updated_at'] = DateTime.now().toIso8601String())
          .eq('id', id)
          .select()
          .single();

      final putnik = DnevniPutnik.fromMap(response);
      
      // Ažuriraj cache
      final cacheKey = '${_cachePrefix}_$id';
      await _cacheService.set(cacheKey, response, _cacheExpiry);
      await _clearListCaches();
      
      dlog('✅ Updated dnevni putnik: ${putnik.ime} [${putnik.id}]');
      return putnik;
    } catch (e) {
      dlog('❌ Error updating dnevni putnik $id: $e');
      rethrow;
    }
  }

  /// Briše putnika (soft delete) sa validacijom
  Future<bool> deleteDnevniPutnik(String id, {String? razlog}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        dlog('⚠️ Pokušaj brisanja nepostojećeg putnika: $id');
        return false;
      }

      // Business logika - da li može biti obrisan
      if (putnik.status == DnevniPutnikStatus.u_vozilu) {
        throw Exception('Ne možete obrisati putnika koji je trenutno u vozilu');
      }

      final updates = {
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (razlog != null) {
        final trenutnaNapomena = putnik.napomena?.isNotEmpty == true ? putnik.napomena! : '';
        updates['napomena'] = trenutnaNapomena.isNotEmpty 
            ? '$trenutnaNapomena\nObrisano: $razlog'
            : 'Obrisano: $razlog';
      }

      await _supabase
          .from('dnevni_putnici')
          .update(updates)
          .eq('id', id);

      // Ukloni iz cache-a
      final cacheKey = '${_cachePrefix}_$id';
      await _cacheService.remove(cacheKey);
      await _clearListCaches();
      
      dlog('✅ Soft deleted dnevni putnik: ${putnik.ime} [${putnik.id}]');
      return true;
    } catch (e) {
      dlog('❌ Error deleting dnevni putnik $id: $e');
      rethrow;
    }
  }

  // ✅ NAPREDNE QUERY METODE

  /// Dohvata sve dnevne putnike za dati datum sa cache-om
  Future<List<DnevniPutnik>> getDnevniPutniciZaDatum(DateTime datum) async {
    try {
      final datumString = datum.toIso8601String().split('T')[0];
      final cacheKey = '${_listCachePrefix}_datum_$datumString';
      
      // Pokušaj iz cache-a
      final cached = await _cacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        dlog('🟢 Cache hit for dnevni putnici datum: $datumString');
        return cached.map((json) => DnevniPutnik.fromMap(json as Map<String, dynamic>)).toList();
      }

      dlog('🔵 Cache miss for dnevni putnici datum: $datumString, fetching from database');
      final response = await _supabase
          .from('dnevni_putnici')
          .select()
          .eq('datum', datumString)
          .eq('obrisan', false)
          .order('polazak');

      final putnici = response.map((json) => DnevniPutnik.fromMap(json)).toList();
      
      // Sačuvaj u cache
      await _cacheService.set(cacheKey, response, _listCacheExpiry);
      
      dlog('✅ Fetched and cached ${putnici.length} dnevni putnici for datum: $datumString');
      return putnici;
    } catch (e) {
      dlog('❌ Error fetching dnevni putnici for datum: $e');
      return [];
    }
  }

  /// Napredna pretraga sa filtriranjem i sortiranjem
  Future<List<DnevniPutnik>> searchDnevniPutnici({
    String? query,
    DateTime? datum,
    String? rutaId,
    String? adresaId,
    DnevniPutnikStatus? status,
    double? minCena,
    double? maxCena,
    bool? jeePlaceno,
    String? vozacId,
    int limit = 100,
    int offset = 0,
    String sortBy = 'datum',
    bool ascending = true,
  }) async {
    try {
      // Kreiranje cache key-a na osnovu parametara
      final cacheKey = '${_listCachePrefix}_search_${_hashSearchParams(
        query, datum, rutaId, adresaId, status, minCena, maxCena, 
        jeePlaceno, vozacId, limit, offset, sortBy, ascending,
      )}';
      
      // Pokušaj iz cache-a
      final cached = await _cacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        dlog('🟢 Cache hit for search dnevni putnici');
        return cached.map((json) => DnevniPutnik.fromMap(json as Map<String, dynamic>)).toList();
      }

      var queryBuilder = _supabase.from('dnevni_putnici').select().eq('obrisan', false);

      // Tekstualna pretraga
      if (query != null && query.trim().isNotEmpty) {
        queryBuilder = queryBuilder.or('ime.ilike.%$query%,broj_telefona.ilike.%$query%');
      }

      // Datum filter
      if (datum != null) {
        final datumString = datum.toIso8601String().split('T')[0];
        queryBuilder = queryBuilder.eq('datum', datumString);
      }

      // Ruta filter
      if (rutaId != null) {
        queryBuilder = queryBuilder.eq('ruta_id', rutaId);
      }

      // Adresa filter  
      if (adresaId != null) {
        queryBuilder = queryBuilder.eq('adresa_id', adresaId);
      }

      // Status filter
      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.value);
      }

      // Cena filter
      if (minCena != null) {
        queryBuilder = queryBuilder.gte('cena', minCena);
      }
      if (maxCena != null) {
        queryBuilder = queryBuilder.lte('cena', maxCena);
      }

      // Plaćanje filter
      if (jeePlaceno != null) {
        if (jeePlaceno) {
          queryBuilder = queryBuilder.not('vreme_placanja', 'is', null);
        } else {
          queryBuilder = queryBuilder.is_('vreme_placanja', null);
        }
      }

      // Vozač filter
      if (vozacId != null) {
        queryBuilder = queryBuilder.or(
          'pokupio_vozac_id.eq.$vozacId,naplatio_vozac_id.eq.$vozacId,dodao_vozac_id.eq.$vozacId',
        );
      }

      // Sortiranje
      switch (sortBy) {
        case 'ime':
          queryBuilder = queryBuilder.order('ime', ascending: ascending);
          break;
        case 'cena':
          queryBuilder = queryBuilder.order('cena', ascending: ascending);
          break;
        case 'status':
          queryBuilder = queryBuilder.order('status', ascending: ascending);
          break;
        case 'polazak':
          queryBuilder = queryBuilder.order('polazak', ascending: ascending);
          break;
        default:
          queryBuilder = queryBuilder.order('datum', ascending: ascending);
      }

      // Pagination
      queryBuilder = queryBuilder.range(offset, offset + limit - 1);

      final response = await queryBuilder;
      final putnici = response.map((json) => DnevniPutnik.fromMap(json)).toList();
      
      // Sačuvaj u cache
      await _cacheService.set(cacheKey, response, _listCacheExpiry);
      
      dlog('✅ Search found ${putnici.length} dnevni putnici');
      return putnici;
    } catch (e) {
      dlog('❌ Error searching dnevni putnici: $e');
      return [];
    }
  }

  /// Brza pretraga po imenu i broju telefona
  Future<List<DnevniPutnik>> quickSearch(String query, {DateTime? datum}) async {
    if (query.trim().isEmpty) {
      return datum != null ? await getDnevniPutniciZaDatum(datum) : [];
    }

    return await searchDnevniPutnici(
      query: query,
      datum: datum,
      limit: 50,
      sortBy: 'polazak',
    );
  }

  /// Dohvata putnike za određenu rutu i datum
  Future<List<DnevniPutnik>> getPutniciZaRutu(String rutaId, DateTime datum) async {
    return await searchDnevniPutnici(
      rutaId: rutaId,
      datum: datum,
      sortBy: 'polazak',
    );
  }

  /// Dohvata sve aktivne putnike
  Future<List<DnevniPutnik>> getAktivniPutnici({DateTime? datum}) async {
    return await searchDnevniPutnici(
      datum: datum,
      sortBy: 'polazak',
    );
  }

  /// Dohvata neplaćene putnike
  Future<List<DnevniPutnik>> getNeplaceniPutnici({DateTime? datum}) async {
    final putnici = await searchDnevniPutnici(
      datum: datum,
      jeePlaceno: false,
      sortBy: 'polazak',
    );
    
    // Filtriranje samo završenih putovanja
    return putnici.where((p) => p.status == DnevniPutnikStatus.zavrseno).toList();
  }

  // ✅ BATCH OPERACIJE

  /// Kreira više putnika odjednom sa validacijom
  Future<List<DnevniPutnik>> createMultipleDnevniPutnici(List<DnevniPutnik> putnici) async {
    if (putnici.isEmpty) return [];

    try {
      // Validacija svih putnika
      for (final putnik in putnici) {
        final errors = putnik.validateFull();
        if (errors.isNotEmpty) {
          throw Exception('Putnik ${putnik.ime}: ${errors.values.join(', ')}');
        }
      }

      // Pripremi podatke
      final data = putnici.map((p) {
        final map = p.toMap();
        map.remove('id'); // ID generiše baza
        return map;
      }).toList();

      final response = await _supabase
          .from('dnevni_putnici')
          .insert(data)
          .select();

      final noviPutnici = response.map((json) => DnevniPutnik.fromMap(json)).toList();
      
      // Očisti cache
      await _clearListCaches();
      
      dlog('✅ Batch created ${noviPutnici.length} dnevni putnici');
      return noviPutnici;
    } catch (e) {
      dlog('❌ Error batch creating dnevni putnici: $e');
      rethrow;
    }
  }

  /// Ažurira više putnika odjednom
  Future<List<DnevniPutnik>> updateMultipleDnevniPutnici(Map<String, Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return [];

    try {
      final List<DnevniPutnik> ažuriraniPutnici = [];

      // Batch ažuriranje u transakciji
      for (final entry in updates.entries) {
        final id = entry.key;
        final updateData = entry.value;
        
        try {
          final putnik = await updateDnevniPutnik(id, updateData);
          ažuriraniPutnici.add(putnik);
        } catch (e) {
          dlog('⚠️ Failed to update putnik $id: $e');
          // Nastavi sa ostalima
        }
      }
      
      dlog('✅ Batch updated ${ažuriraniPutnici.length}/${updates.length} dnevni putnici');
      return ažuriraniPutnici;
    } catch (e) {
      dlog('❌ Error batch updating dnevni putnici: $e');
      rethrow;
    }
  }

  /// Briše više putnika odjednom
  Future<int> deleteMultipleDnevniPutnici(List<String> ids, {String? razlog}) async {
    if (ids.isEmpty) return 0;

    try {
      int uspešno = 0;
      
      for (final id in ids) {
        try {
          final success = await deleteDnevniPutnik(id, razlog: razlog);
          if (success) uspešno++;
        } catch (e) {
          dlog('⚠️ Failed to delete putnik $id: $e');
          // Nastavi sa ostalima
        }
      }
      
      dlog('✅ Batch deleted $uspešno/${ids.length} dnevni putnici');
      return uspešno;
    } catch (e) {
      dlog('❌ Error batch deleting dnevni putnici: $e');
      rethrow;
    }
  }

  /// Batch status promene
  Future<List<DnevniPutnik>> batchUpdateStatus(
    List<String> ids, 
    DnevniPutnikStatus newStatus, 
    {String? vozacId, String? napomena,}
  ) async {
    if (ids.isEmpty) return [];

    try {
      final updates = <String, Map<String, dynamic>>{};
      
      for (final id in ids) {
        final updateData = <String, dynamic>{
          'status': newStatus.value,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (vozacId != null) {
          switch (newStatus) {
            case DnevniPutnikStatus.pokupljen:
              updateData['pokupio_vozac_id'] = vozacId;
              updateData['vreme_pokupljenja'] = DateTime.now().toIso8601String();
              break;
            case DnevniPutnikStatus.potvrdjen:
              updateData['dodao_vozac_id'] = vozacId;
              break;
            default:
              // Ne radi ništa za ostale statuse
              break;
          }
        }

        if (napomena != null) {
          updateData['napomena'] = napomena;
        }

        updates[id] = updateData;
      }

      return await updateMultipleDnevniPutnici(updates);
    } catch (e) {
      dlog('❌ Error batch updating status: $e');
      rethrow;
    }
  }

  // ✅ BUSINESS LOGIKA METODE

  /// Označava putnika kao pokupljenog sa validacijom
  Future<DnevniPutnik> oznaciKaoPokupio(String id, String vozacId, {String? napomena}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (!putnik.mozeBitiPokupljen) {
        throw Exception('Putnik ${putnik.ime} ne može biti pokupljen u trenutnom stanju: ${putnik.statusOpis}');
      }

      final ažuriraniPutnik = putnik.oznacikaoPoukpljen(vozacId: vozacId, napomena: napomena);
      
      return await updateDnevniPutnik(id, {
        'status': ažuriraniPutnik.status.value,
        'vreme_pokupljenja': ažuriraniPutnik.vremePokupljenja!.toIso8601String(),
        'pokupio_vozac_id': ažuriraniPutnik.pokupioVozacId,
        'napomena': ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error marking putnik as picked up: $e');
      rethrow;
    }
  }

  /// Označava putnika kao plaćenog sa validacijom
  Future<DnevniPutnik> oznaciKaoPlacen(String id, String vozacId, {double? iznos, String? napomena}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (putnik.status != DnevniPutnikStatus.zavrseno) {
        throw Exception('Putnik ${putnik.ime} mora biti završen da bi bio označen kao plaćen');
      }

      final ažuriraniPutnik = putnik.oznacikaoPlaceno(vozacId: vozacId, iznos: iznos);
      
      return await updateDnevniPutnik(id, {
        'vreme_placanja': ažuriraniPutnik.vremePlacanja!.toIso8601String(),
        'naplatio_vozac_id': ažuriraniPutnik.naplatioVozacId,
        'cena': ažuriraniPutnik.cena,
        'napomena': napomena ?? ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error marking putnik as paid: $e');
      rethrow;
    }
  }

  /// Otkazuje putnika sa validacijom
  Future<DnevniPutnik> otkaziPutnika(String id, {String? razlog}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (!putnik.mozeBitiOtkazano) {
        throw Exception('Putnik ${putnik.ime} ne može biti otkazan u trenutnom stanju: ${putnik.statusOpis}');
      }

      final ažuriraniPutnik = putnik.otkazi(razlog: razlog);
      
      return await updateDnevniPutnik(id, {
        'status': ažuriraniPutnik.status.value,
        'napomena': ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error canceling putnik: $e');
      rethrow;
    }
  }

  /// Završava putovanje
  Future<DnevniPutnik> zavrsiPutovanje(String id, {String? napomena}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (putnik.status != DnevniPutnikStatus.u_vozilu) {
        throw Exception('Putnik ${putnik.ime} mora biti u vozilu da bi se završilo putovanje');
      }

      final ažuriraniPutnik = putnik.zavrsi(napomena: napomena);
      
      return await updateDnevniPutnik(id, {
        'status': ažuriraniPutnik.status.value,
        'napomena': ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error finishing journey: $e');
      rethrow;
    }
  }

  /// Označava da je putnik ušao u vozilo
  Future<DnevniPutnik> uVozilo(String id, {String? napomena}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (putnik.status != DnevniPutnikStatus.pokupljen) {
        throw Exception('Putnik ${putnik.ime} mora biti pokupljen da bi ušao u vozilo');
      }

      final ažuriraniPutnik = putnik.uVozilo(napomena: napomena);
      
      return await updateDnevniPutnik(id, {
        'status': ažuriraniPutnik.status.value,
        'napomena': ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error moving putnik to vehicle: $e');
      rethrow;
    }
  }

  /// Potvrđuje rezervaciju putnika
  Future<DnevniPutnik> potvrdiRezervaciju(String id, String vozacId, {String? napomena}) async {
    try {
      final putnik = await getDnevniPutnikById(id);
      if (putnik == null) {
        throw Exception('Putnik sa ID $id ne postoji');
      }

      if (putnik.status != DnevniPutnikStatus.rezervisan) {
        throw Exception('Putnik ${putnik.ime} mora biti rezervisan da bi bio potvrđen');
      }

      final ažuriraniPutnik = putnik.potvrdi(vozacId: vozacId, napomena: napomena);
      
      return await updateDnevniPutnik(id, {
        'status': ažuriraniPutnik.status.value,
        'dodao_vozac_id': ažuriraniPutnik.dodaoVozacId,
        'napomena': ažuriraniPutnik.napomena,
      });
    } catch (e) {
      dlog('❌ Error confirming reservation: $e');
      rethrow;
    }
  }

  // ✅ STATISTIKE I EKSPORT

  /// Dobija detaljne statistike za dnevne putnike
  Future<Map<String, dynamic>> getDetailedStatistike(DateTime datum) async {
    try {
      final cacheKey = '${_statsCachePrefix}_detailed_${datum.toIso8601String().split('T')[0]}';
      
      // Pokušaj iz cache-a
      final cached = await _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        dlog('🟢 Cache hit for detailed statistike: ${datum.toIso8601String().split('T')[0]}');
        return cached;
      }

      final putnici = await getDnevniPutniciZaDatum(datum);
      
      final ukupno = putnici.length;
      final poStatusu = <String, int>{};
      final poRutama = <String, int>{};
      final poAdresama = <String, int>{};
      final poVozacima = <String, int>{};
      
      double ukupnaZarada = 0;
      double neplacenaZarada = 0;
      int brojMesta = 0;
      int naVreme = 0;
      
      for (final putnik in putnici) {
        // Status statistike
        final status = putnik.status.value;
        poStatusu[status] = (poStatusu[status] ?? 0) + 1;
        
        // Ruta statistike
        poRutama[putnik.rutaId] = (poRutama[putnik.rutaId] ?? 0) + 1;
        
        // Adresa statistike
        poAdresama[putnik.adresaId] = (poAdresama[putnik.adresaId] ?? 0) + 1;
        
        // Vozač statistike
        if (putnik.pokupioVozacId != null) {
          poVozacima[putnik.pokupioVozacId!] = (poVozacima[putnik.pokupioVozacId!] ?? 0) + 1;
        }
        
        // Finansijske statistike
        if (putnik.vremePlacanja != null) {
          ukupnaZarada += putnik.cena;
        } else if (putnik.status == DnevniPutnikStatus.zavrseno) {
          neplacenaZarada += putnik.cena;
        }
        
        // Mesta i performanse
        brojMesta += putnik.brojMesta;
        
        if (putnik.jeNaVreme) {
          naVreme++;
        }
      }

      final pokupljeni = poStatusu['pokupljen'] ?? 0;
      final zavrseni = poStatusu['zavrseno'] ?? 0;
      final otkazani = poStatusu['otkazan'] ?? 0;
      final aktivni = pokupljeni + (poStatusu['u_vozilu'] ?? 0);

      final statistike = {
        'datum': datum.toIso8601String().split('T')[0],
        'ukupno_putnici': ukupno,
        'aktivni_putnici': aktivni,
        'zavrseni_putnici': zavrseni,
        'otkazani_putnici': otkazani,
        'ukupno_mesta': brojMesta,
        'ukupna_zarada': ukupnaZarada,
        'neplacena_zarada': neplacenaZarada,
        'procenat_završenih': ukupno > 0 ? ((zavrseni / ukupno) * 100).round() : 0,
        'procenat_otkazanih': ukupno > 0 ? ((otkazani / ukupno) * 100).round() : 0,
        'procenat_na_vreme': pokupljeni > 0 ? ((naVreme / pokupljeni) * 100).round() : 0,
        'po_statusu': poStatusu,
        'po_rutama': poRutama,
        'po_adresama': poAdresama,
        'po_vozacima': poVozacima,
        'prosecna_cena': ukupno > 0 ? (ukupnaZarada / ukupno).round() : 0,
        'vreme_generisanja': DateTime.now().toIso8601String(),
      };

      // Sačuvaj u cache
      await _cacheService.set(cacheKey, statistike, _statsCacheExpiry);
      
      dlog('✅ Generated detailed statistike for ${statistike['datum']}');
      return statistike;
    } catch (e) {
      dlog('❌ Error generating detailed statistike: $e');
      return {};
    }
  }

  /// Eksportuje putnike u CSV format
  Future<String> exportToCSV(List<DnevniPutnik> putnici) async {
    try {
      if (putnici.isEmpty) return '';

      final headers = [
        'ID', 'Ime', 'Broj telefona', 'Adresa ID', 'Ruta ID',
        'Datum', 'Polazak', 'Broj mesta', 'Cena', 'Status',
        'Napomena', 'Vreme pokupljenja', 'Pokupljen od',
        'Vreme plaćanja', 'Naplateno od', 'Dodao vozač',
        'Kreiran', 'Ažuriran',
      ];

      final rows = <List<String>>[headers];

      for (final putnik in putnici) {
        rows.add([
          putnik.id,
          putnik.ime,
          putnik.brojTelefona ?? '',
          putnik.adresaId,
          putnik.rutaId,
          putnik.formatiraniDatum,
          putnik.vremePolaska,
          putnik.brojMesta.toString(),
          putnik.cena.toString(),
          putnik.statusOpis,
          putnik.napomena ?? '',
          putnik.vremePokupljenja?.toIso8601String() ?? '',
          putnik.pokupioVozacId ?? '',
          putnik.vremePlacanja?.toIso8601String() ?? '',
          putnik.naplatioVozacId ?? '',
          putnik.dodaoVozacId ?? '',
          putnik.createdAt.toIso8601String(),
          putnik.updatedAt.toIso8601String(),
        ]);
      }

      // Kreiraj CSV
      final csv = rows.map((row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',')).join('\n');
      
      dlog('✅ Exported ${putnici.length} dnevni putnici to CSV');
      return csv;
    } catch (e) {
      dlog('❌ Error exporting to CSV: $e');
      rethrow;
    }
  }

  /// Generiše izveštaj za period
  Future<Map<String, dynamic>> generateReport(DateTime startDate, DateTime endDate) async {
    try {
      final dani = <DateTime>[];
      var trenutniDan = startDate;
      
      while (trenutniDan.isBefore(endDate) || trenutniDan.isAtSameMomentAs(endDate)) {
        dani.add(trenutniDan);
        trenutniDan = trenutniDan.add(const Duration(days: 1));
      }

      final dnevneStatistike = <Map<String, dynamic>>[];
      var ukupniPutnici = 0;
      var ukupnaZarada = 0.0;
      var ukupnoMesta = 0;

      for (final dan in dani) {
        final statistike = await getDetailedStatistike(dan);
        if (statistike.isNotEmpty) {
          dnevneStatistike.add(statistike);
          ukupniPutnici += statistike['ukupno_putnici'] as int;
          ukupnaZarada += statistike['ukupna_zarada'] as double;
          ukupnoMesta += statistike['ukupno_mesta'] as int;
        }
      }

      return {
        'period': '${startDate.toIso8601String().split('T')[0]} - ${endDate.toIso8601String().split('T')[0]}',
        'broj_dana': dani.length,
        'ukupni_putnici': ukupniPutnici,
        'ukupna_zarada': ukupnaZarada,
        'ukupno_mesta': ukupnoMesta,
        'prosecni_putnici_po_danu': dani.isNotEmpty ? (ukupniPutnici / dani.length).round() : 0,
        'prosecna_zarada_po_danu': dani.isNotEmpty ? (ukupnaZarada / dani.length).round() : 0,
        'dnevne_statistike': dnevneStatistike,
        'vreme_generisanja': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      dlog('❌ Error generating report: $e');
      return {};
    }
  }

  // ✅ HELPER METODE

  /// Čisti sve cache-ove
  Future<void> clearAllCaches() async {
    try {
      await _cacheService.clearByPrefix(_cachePrefix);
      await _cacheService.clearByPrefix(_listCachePrefix);
      await _cacheService.clearByPrefix(_statsCachePrefix);
      _adresaCache.clear();
      _rutaCache.clear();
      dlog('🧹 Cleared all dnevni putnik caches');
    } catch (e) {
      dlog('❌ Error clearing caches: $e');
    }
  }

  /// Čisti cache liste (poziva se nakon promenja)
  Future<void> _clearListCaches() async {
    try {
      await _cacheService.clearByPrefix(_listCachePrefix);
      await _cacheService.clearByPrefix(_statsCachePrefix);
    } catch (e) {
      dlog('❌ Error clearing list caches: $e');
    }
  }

  /// Hash parametara za cache key
  String _hashSearchParams(
    String? query, DateTime? datum, String? rutaId, String? adresaId,
    DnevniPutnikStatus? status, double? minCena, double? maxCena,
    bool? jeePlaceno, String? vozacId, int limit, int offset,
    String sortBy, bool ascending,
  ) {
    final params = [
      query ?? '', datum?.toIso8601String() ?? '', rutaId ?? '', adresaId ?? '',
      status?.value ?? '', minCena?.toString() ?? '', maxCena?.toString() ?? '',
      jeePlaceno?.toString() ?? '', vozacId ?? '', limit.toString(), offset.toString(),
      sortBy, ascending.toString(),
    ].join('_');
    
    return params.hashCode.abs().toString();
  }

  /// Stream za realtime ažuriranja dnevnih putnika
  Stream<List<DnevniPutnik>> dnevniPutniciStreamZaDatum(DateTime datum) {
    final datumString = datum.toIso8601String().split('T')[0];

    return _supabase
        .from('dnevni_putnici')
        .stream(primaryKey: ['id'])
        .order('polazak')
        .map((data) => data
            .where((putnik) => 
                putnik['datum'] == datumString && 
                putnik['obrisan'] == false,)
            .map((json) => DnevniPutnik.fromMap(json))
            .toList(),);
  }
  // static final _logger = Logger();

  // Cache za adrese i rute
  final Map<String, Adresa> _adresaCache = {};
  final Map<String, Ruta> _rutaCache = {};

  // Instanciranje servisa
  late final AdresaService _adresaService = AdresaService();

  /// Dohvata sve dnevne putnike za dati datum
  Future<List<DnevniPutnik>> getDnevniPutniciZaDatum(DateTime datum) async {
    final datumString = datum.toIso8601String().split('T')[0];

    final response = await _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('datum', datumString).eq('obrisan', false).order('polazak');

    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Dohvata dnevnog putnika po ID-u
  Future<DnevniPutnik?> getDnevniPutnikById(String id) async {
    final response = await _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('id', id).single();

    return DnevniPutnik.fromMap(response);
  }

  /// Kreira novog dnevnog putnika
  Future<DnevniPutnik> createDnevniPutnik(DnevniPutnik putnik) async {
    final response = await _supabase.from('dnevni_putnici').insert(putnik.toMap()).select('''
          *
        ''').single();

    return DnevniPutnik.fromMap(response);
  }

  /// Ažurira dnevnog putnika
  Future<DnevniPutnik> updateDnevniPutnik(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase.from('dnevni_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    return DnevniPutnik.fromMap(response);
  }

  /// Označava putnika kao pokupljenog
  Future<void> oznaciKaoPokupio(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'status': 'pokupljen',
      'vreme_pokupljenja': DateTime.now().toIso8601String(),
      'pokupio_vozac_id': vozacId,
    });
  }

  /// Označava putnika kao plaćenog
  Future<void> oznaciKaoPlacen(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'vreme_placanja': DateTime.now().toIso8601String(),
      'naplatio_vozac_id': vozacId,
    });
  }

  /// Otkaži putnika
  Future<void> otkaziPutnika(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'status': 'otkazan',
      'otkazao_vozac_id': vozacId,
      'vreme_otkazivanja': DateTime.now().toIso8601String(),
    });
  }

  /// Briše putnika (soft delete)
  Future<void> obrisiPutnika(String id) async {
    await _supabase.from('dnevni_putnici').update({
      'obrisan': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži dnevne putnike po imenu, prezimenu ili broju telefona
  Future<List<DnevniPutnik>> searchDnevniPutnici(
    String query, {
    DateTime? datum,
  }) async {
    var queryBuilder = _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('obrisan', false).or('ime.ilike.%$query%,prezime.ilike.%$query%,broj_telefona.ilike.%$query%');

    if (datum != null) {
      final datumString = datum.toIso8601String().split('T')[0];
      queryBuilder = queryBuilder.eq('datum', datumString);
    }

    final response = await queryBuilder.order('polazak');
    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Dohvata putnike za datu rutu i datum
  Future<List<DnevniPutnik>> getPutniciZaRutu(
    String rutaId,
    DateTime datum,
  ) async {
    final datumString = datum.toIso8601String().split('T')[0];

    final response = await _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('ruta_id', rutaId).eq('datum', datumString).eq('obrisan', false).order('polazak');

    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja dnevnih putnika
  Stream<List<DnevniPutnik>> dnevniPutniciStreamZaDatum(DateTime datum) {
    final datumString = datum.toIso8601String().split('T')[0];

    return _supabase.from('dnevni_putnici').stream(primaryKey: ['id']).order('polazak').map(
          (data) => data
              .where(
                (putnik) => putnik['datum'] == datumString && putnik['obrisan'] == false,
              )
              .map((json) => DnevniPutnik.fromMap(json))
              .toList(),
        );
  }

  // ✅ RELATIONSHIP HELPER METODE

  /// Dohvata adresu po ID-u sa cache-om
  Future<Adresa?> _getAdresaById(String adresaId) async {
    if (_adresaCache.containsKey(adresaId)) {
      return _adresaCache[adresaId];
    }

    try {
      final adresa = await _adresaService.getAdresaById(adresaId);
      if (adresa != null) {
        _adresaCache[adresaId] = adresa;
      }
      return adresa;
    } catch (e) {
      dlog('❌ Error fetching adresa $adresaId: $e');
      return null;
    }
  }

  /// Dohvata rutu po ID-u sa cache-om
  Future<Ruta?> _getRutaById(String rutaId) async {
    if (_rutaCache.containsKey(rutaId)) {
      return _rutaCache[rutaId];
    }

    try {
      final response = await _supabase.from('rute').select().eq('id', rutaId).single();

      final ruta = Ruta.fromMap(response);
      _rutaCache[rutaId] = ruta;
      return ruta;
    } catch (e) {
      dlog('❌ Error fetching ruta $rutaId: $e');
      return null;
    }
  }

  /// Konvertuje DnevniPutnik u Putnik sa relationship podacima
  Future<Putnik?> dnevniPutnikToPutnik(DnevniPutnik dnevniPutnik) async {
    try {
      final adresa = await _getAdresaById(dnevniPutnik.adresaId);
      final ruta = await _getRutaById(dnevniPutnik.rutaId);

      if (adresa == null || ruta == null) {
        dlog('⚠️ Missing relationships for putnik ${dnevniPutnik.ime}');
        return null;
      }

      return dnevniPutnik.toPutnikWithRelations(adresa, ruta);
    } catch (e) {
      dlog('❌ Error converting dnevni putnik to putnik: $e');
      return null;
    }
  }

  /// Dohvata dnevne putnike kao Putnik objekte sa relationship podacima
  Future<List<Putnik>> getDnevniPutniciKaoPutnici(DateTime datum) async {
    try {
      final dnevniPutnici = await getDnevniPutniciZaDatum(datum);
      final List<Putnik> putnici = [];

      for (final dnevniPutnik in dnevniPutnici) {
        final putnik = await dnevniPutnikToPutnik(dnevniPutnik);
        if (putnik != null) {
          putnici.add(putnik);
        }
      }

      dlog('✅ Converted ${putnici.length}/${dnevniPutnici.length} dnevni putnici to Putnik objects');
      return putnici;
    } catch (e) {
      dlog('❌ Error getting dnevni putnici as Putnik: $e');
      return [];
    }
  }

  /// Batch operacije - dodavanje više putnika odjednom
  Future<List<DnevniPutnik>> dodajViseputnika(List<DnevniPutnik> putnici) async {
    try {
      final List<Map<String, dynamic>> data = putnici.map((p) => p.toMap()).toList();

      final response = await _supabase.from('dnevni_putnici').insert(data).select();

      final dodatiPutnici = response.map((json) => DnevniPutnik.fromMap(json)).toList();
      dlog('✅ Batch added ${dodatiPutnici.length} dnevni putnici');

      return dodatiPutnici;
    } catch (e) {
      dlog('❌ Error batch adding dnevni putnici: $e');
      rethrow;
    }
  }

  /// Dohvata statistike za dnevne putnike
  Future<Map<String, dynamic>> getStatistike(DateTime datum) async {
    try {
      final putnici = await getDnevniPutniciZaDatum(datum);

      final ukupno = putnici.length;
      final pokupljeni = putnici.where((p) => p.isPokupljen).length;
      final placeni = putnici.where((p) => p.isPlacen).length;
      final otkazani = putnici.where((p) => p.status == DnevniPutnikStatus.otkazan).length;
      final ukupnaZarada = putnici.fold<double>(0, (sum, p) => sum + (p.isPlacen ? p.cena : 0));

      return {
        'ukupno': ukupno,
        'pokupljeni': pokupljeni,
        'placeni': placeni,
        'otkazani': otkazani,
        'ukupna_zarada': ukupnaZarada,
        'procenat_pokupljenosti': ukupno > 0 ? (pokupljeni / ukupno * 100).round() : 0,
        'procenat_placenos': ukupno > 0 ? (placeni / ukupno * 100).round() : 0,
      };
    } catch (e) {
      dlog('❌ Error getting statistike: $e');
      return {};
    }
  }

  /// Čisti cache (korisno za memory management)
  void clearCache() {
    _adresaCache.clear();
    _rutaCache.clear();
    dlog('🧹 Cleared dnevni putnik cache');
  }

  /// Validacija pre dodavanja novog putnika
  Future<bool> validateNoviPutnik(DnevniPutnik putnik) async {
    if (!putnik.isValid) {
      dlog('⚠️ Invalid putnik data: ${putnik.toString()}');
      return false;
    }

    // Proveri da li adresa i ruta postoje
    final adresa = await _getAdresaById(putnik.adresaId);
    final ruta = await _getRutaById(putnik.rutaId);

    if (adresa == null) {
      dlog('⚠️ Adresa ${putnik.adresaId} not found');
      return false;
    }

    if (ruta == null) {
      dlog('⚠️ Ruta ${putnik.rutaId} not found');
      return false;
    }

    // Proveri duplikate za isti datum i vreme
    final postojeciPutnici = await getDnevniPutniciZaDatum(putnik.datumPutovanja);
    final duplikat = postojeciPutnici.any(
      (p) =>
          p.ime.toLowerCase() == putnik.ime.toLowerCase() &&
          p.vremePolaska == putnik.vremePolaska &&
          p.adresaId == putnik.adresaId,
    );

    if (duplikat) {
      dlog('⚠️ Duplicate putnik detected: ${putnik.ime} at ${putnik.vremePolaska}');
      return false;
    }

    return true;
  }
}
