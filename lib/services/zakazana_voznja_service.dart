/// ⚔️ BINARYBITCH: Service za zakazane vožnje
/// Self-booking sistem za mesečne putnike

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/zakazana_voznja.dart';

class ZakazanaVoznjaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════════════════
  // 📅 CRUD OPERACIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// Zakaži vožnju za određeni datum
  Future<ZakazanaVoznja?> zakaziVoznju({
    required String putnikId,
    required DateTime datum,
    required String smena,
    String? vremeBc,
    String? vremeVs,
    String? napomena,
  }) async {
    try {
      // Automatski popuni vremena iz smene ako nisu prosleđena
      if (vremeBc == null && vremeVs == null) {
        final smenaVremena = ZakazanaVoznja.smeneVremena[smena];
        vremeBc = smenaVremena?['bc'];
        vremeVs = smenaVremena?['vs'];
      }

      final data = {
        'putnik_id': putnikId,
        'datum': datum.toIso8601String().split('T')[0],
        'smena': smena,
        'vreme_bc': vremeBc,
        'vreme_vs': vremeVs,
        'status': 'zakazano',
        'napomena': napomena,
      };

      final response = await _supabase
          .from('zakazane_voznje')
          .upsert(data, onConflict: 'putnik_id,datum')
          .select()
          .single();

      return ZakazanaVoznja.fromMap(response);
    } catch (e) {
      print('❌ Greška pri zakazivanju vožnje: $e');
      return null;
    }
  }

  /// Zakaži celu nedelju odjednom
  Future<List<ZakazanaVoznja>> zakaziNedelju({
    required String putnikId,
    required DateTime pocetakNedelje,
    required Map<int, String> smenePoDanima, // 0=pon, 1=uto, ... -> smena
  }) async {
    final rezultat = <ZakazanaVoznja>[];

    for (int i = 0; i < 5; i++) {
      // PON-PET
      final datum = pocetakNedelje.add(Duration(days: i));
      final smena = smenePoDanima[i] ?? 'slobodan';

      final voznja = await zakaziVoznju(
        putnikId: putnikId,
        datum: datum,
        smena: smena,
      );

      if (voznja != null) {
        rezultat.add(voznja);
      }
    }

    return rezultat;
  }

  /// Otkaži zakazanu vožnju
  Future<bool> otkaziVoznju(String zakazanaVoznjaId) async {
    try {
      await _supabase
          .from('zakazane_voznje')
          .update({'status': 'otkazano'})
          .eq('id', zakazanaVoznjaId);
      return true;
    } catch (e) {
      print('❌ Greška pri otkazivanju: $e');
      return false;
    }
  }

  /// Obriši zakazanu vožnju
  Future<bool> obrisiVoznju(String zakazanaVoznjaId) async {
    try {
      await _supabase
          .from('zakazane_voznje')
          .delete()
          .eq('id', zakazanaVoznjaId);
      return true;
    } catch (e) {
      print('❌ Greška pri brisanju: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔍 QUERY OPERACIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// Dobij zakazane vožnje za putnika za određenu nedelju
  Future<List<ZakazanaVoznja>> getZakazaneZaNedelju({
    required String putnikId,
    required DateTime pocetakNedelje,
  }) async {
    try {
      final krajNedelje = pocetakNedelje.add(const Duration(days: 6));

      final response = await _supabase
          .from('zakazane_voznje')
          .select()
          .eq('putnik_id', putnikId)
          .gte('datum', pocetakNedelje.toIso8601String().split('T')[0])
          .lte('datum', krajNedelje.toIso8601String().split('T')[0])
          .order('datum');

      return (response as List)
          .map((item) => ZakazanaVoznja.fromMap(item))
          .toList();
    } catch (e) {
      print('❌ Greška pri dohvatanju: $e');
      return [];
    }
  }

  /// Dobij sve zakazane vožnje za određeni datum (za vozača)
  Future<List<ZakazanaVoznja>> getZakazaneZaDatum(DateTime datum) async {
    try {
      final response = await _supabase
          .from('zakazane_voznje_pregled')
          .select()
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('status', 'zakazano')
          .order('vreme_bc');

      return (response as List)
          .map((item) => ZakazanaVoznja.fromMap(item))
          .toList();
    } catch (e) {
      print('❌ Greška pri dohvatanju za datum: $e');
      return [];
    }
  }

  /// Dobij zakazane po vremenu polaska (za vozača)
  Future<Map<String, List<ZakazanaVoznja>>> getZakazaneGrupisanoPoPocetku(
    DateTime datum,
  ) async {
    final sve = await getZakazaneZaDatum(datum);
    final grupisano = <String, List<ZakazanaVoznja>>{};

    for (final voznja in sve) {
      final kljuc = voznja.vremeBc ?? 'ostalo';
      grupisano.putIfAbsent(kljuc, () => []);
      grupisano[kljuc]!.add(voznja);
    }

    return grupisano;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📆 HELPER METODE
  // ═══════════════════════════════════════════════════════════════════════

  /// Dobij početak sledeće nedelje (ponedeljak)
  static DateTime getSledecaNedelja() {
    final now = DateTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }

  /// Dobij početak trenutne nedelje (ponedeljak)
  static DateTime getTrenutnaNedelja() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Lista dana u nedelji sa datumima
  static List<Map<String, dynamic>> getDaniUNedelji(DateTime pocetakNedelje) {
    final dani = ['PON', 'UTO', 'SRE', 'ČET', 'PET', 'SUB', 'NED'];
    return List.generate(7, (i) {
      final datum = pocetakNedelje.add(Duration(days: i));
      return {
        'dan': dani[i],
        'datum': datum,
        'datumStr': '${datum.day}.${datum.month}.',
        'index': i,
      };
    });
  }
}
