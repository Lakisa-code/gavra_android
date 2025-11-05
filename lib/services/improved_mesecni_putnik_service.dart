import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import '../utils/mesecni_filter_fix.dart';

/// 🚀 POBOLJŠANI SERVIS ZA MESEČNE PUTNIKE
/// Koristi nove SQL funkcije i optimizovanu logiku filtriranja
class ImprovedMesecniPutnikService {
  ImprovedMesecniPutnikService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// ✅ POBOLJŠANO: Dohvata mesečne putnike sa SQL optimizacijom
  Future<List<MesecniPutnik>> getFilteredMesecniPutnici({
    String? targetDay,
    String? searchTerm,
    String filterType = 'svi',
    bool activeOnly = true,
  }) async {
    try {
      // Koristi SQL funkciju za optimalno filtriranje
      final response = await _supabase.rpc<List<dynamic>>(
        'get_filtered_mesecni_putnici',
        params: {
          'target_day': targetDay,
          'search_term': searchTerm,
          'filter_type': filterType,
          'active_only': activeOnly,
        },
      );

      return response.map((json) => MesecniPutnik.fromMap(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback na standardnu logiku ako SQL funkcija nije dostupna
      print('⚠️ SQL funkcija nije dostupna, koristim fallback: $e');
      return await _getFallbackFiltered(
        targetDay: targetDay,
        searchTerm: searchTerm,
        filterType: filterType,
        activeOnly: activeOnly,
      );
    }
  }

  /// 📊 POBOLJŠANO: Stream sa optimizovanim filtriranjem
  Stream<List<MesecniPutnik>> streamFilteredMesecniPutnici({
    String? targetDay,
    String? searchTerm,
    String filterType = 'svi',
    bool activeOnly = true,
  }) {
    return _supabase.from('mesecni_putnici').stream(primaryKey: ['id']).order('putnik_ime').map((data) {
          final listRaw = data as List<dynamic>;

          return listRaw
              .map((row) => row as Map<String, dynamic>)
              .where((putnikMap) {
                return MesecniFilterFix.shouldIncludeMesecniPutnik(
                  putnik: putnikMap,
                  targetDay: targetDay,
                  searchTerm: searchTerm,
                  filterType: filterType != 'svi' ? filterType : null,
                );
              })
              .map((json) => MesecniPutnik.fromMap(json))
              .toList();
        });
  }

  /// 🔍 POBOLJŠANO: Pretraga mesečnih putnika
  Future<List<MesecniPutnik>> searchMesecniPutnici(String query) async {
    if (query.trim().isEmpty) {
      return await getFilteredMesecniPutnici();
    }

    return await getFilteredMesecniPutnici(
      searchTerm: query.trim(),
    );
  }

  /// 📅 POBOLJŠANO: Dohvata putnike za specifičan dan
  Future<List<MesecniPutnik>> getMesecniPutniciZaDan(String dan) async {
    return await getFilteredMesecniPutnici(
      targetDay: MesecniFilterFix.getDayAbbreviationFromName(dan),
    );
  }

  /// 🎯 POBOLJŠANO: Dohvata putnike po tipu
  Future<List<MesecniPutnik>> getMesecniPutniciPoTipu(String tip) async {
    return await getFilteredMesecniPutnici(
      filterType: tip,
    );
  }

  /// 📊 NOVE METODE: Statistike mesečnih putnika
  Future<Map<String, int>> getStatistikeMesecnihPutnika() async {
    try {
      final sviPutnici = await _supabase.from('mesecni_putnici').select('tip, status, aktivan, obrisan');

      final stats = <String, int>{
        'ukupno': 0,
        'aktivni': 0,
        'radnici': 0,
        'ucenici': 0,
        'bolovanje': 0,
        'godisnje': 0,
      };

      for (final putnik in sviPutnici) {
        stats['ukupno'] = (stats['ukupno'] ?? 0) + 1;

        if (putnik['aktivan'] == true && putnik['obrisan'] != true) {
          stats['aktivni'] = (stats['aktivni'] ?? 0) + 1;
        }

        final tip = putnik['tip']?.toString().toLowerCase() ?? '';
        if (tip == 'radnik') {
          stats['radnici'] = (stats['radnici'] ?? 0) + 1;
        } else if (tip == 'ucenik') {
          stats['ucenici'] = (stats['ucenici'] ?? 0) + 1;
        }

        final status = putnik['status']?.toString().toLowerCase() ?? '';
        if (status == 'bolovanje') {
          stats['bolovanje'] = (stats['bolovanje'] ?? 0) + 1;
        } else if (status.contains('godišnje') || status.contains('godisnji')) {
          stats['godisnje'] = (stats['godisnje'] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Greška pri dohvatanju statistika: $e');
      return <String, int>{};
    }
  }

  /// 🔄 Fallback metoda kada SQL funkcije nisu dostupne
  Future<List<MesecniPutnik>> _getFallbackFiltered({
    String? targetDay,
    String? searchTerm,
    String filterType = 'svi',
    bool activeOnly = true,
  }) async {
    var query = _supabase.from('mesecni_putnici').select();

    if (activeOnly) {
      query = query.eq('aktivan', true).eq('obrisan', false);
    }

    if (targetDay != null) {
      query = query.like('radni_dani', '%$targetDay%');
    }

    if (filterType != 'svi') {
      query = query.eq('tip', filterType);
    }

    final response = await query.order('putnik_ime') as List<dynamic>;

    var putnici = response.map((json) => MesecniPutnik.fromMap(json as Map<String, dynamic>)).toList();

    // Dodatno Dart filtriranje za search
    if (searchTerm != null && searchTerm.isNotEmpty) {
      final searchLower = searchTerm.toLowerCase();
      putnici = putnici.where((putnik) {
        return putnik.putnikIme.toLowerCase().contains(searchLower) ||
            putnik.tip.toLowerCase().contains(searchLower) ||
            (putnik.tipSkole?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    return putnici;
  }

  /// 🧪 METODA ZA TESTIRANJE: Validacija poboljšanja
  Future<Map<String, dynamic>> validateImprovements() async {
    final startTime = DateTime.now();

    try {
      // Test osnovnog dohvatanja
      final sviPutnici = await getFilteredMesecniPutnici();

      // Test filtriranja po danu
      final ponedeljak = await getFilteredMesecniPutnici(targetDay: 'pon');

      // Test pretrage
      final searchResults = await searchMesecniPutnici('test');

      // Test statistika
      final stats = await getStatistikeMesecnihPutnika();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      return {
        'success': true,
        'ukupno_putnika': sviPutnici.length,
        'ponedeljak_putnika': ponedeljak.length,
        'search_rezultata': searchResults.length,
        'statistike': stats,
        'vreme_izvrsavanja_ms': duration,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
