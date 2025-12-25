import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Servis za statistiku
/// ✅ ISPRAVKA: Čita iz polasci_po_danu JSON-a u registrovani_putnici tabeli
/// 🚀 Realtime stream direktno iz Supabase
class StatistikaService {
  static final _supabase = Supabase.instance.client;

  /// Stream pazara za sve vozače
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  /// ✅ ISPRAVKA: Čita iz polasci_po_danu JSON-a
  static Stream<Map<String, double>> streamPazarZaSveVozace({
    required DateTime from,
    required DateTime to,
  }) {
    // Koristi realtime stream iz registrovani_putnici
    return _supabase
        .from('registrovani_putnici')
        .stream(primaryKey: ['id']).map((records) => _izracunajPazarIzPolasciPoDanu(records, from, to));
  }

  /// ✅ NOVA LOGIKA: Izračunaj pazar iz polasci_po_danu JSON-a
  static Map<String, double> _izracunajPazarIzPolasciPoDanu(
    List<Map<String, dynamic>> records,
    DateTime from,
    DateTime to,
  ) {
    final Map<String, double> pazar = {};
    double ukupno = 0;

    // Dobij kraticu dana iz target datuma
    // from.weekday vraća 1=Pon, 2=Uto, itd.
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[from.weekday - 1];

    for (final record in records) {
      // Preskoči neaktivne putnike
      if (record['aktivan'] != true || record['obrisan'] == true) continue;

      final polasciRaw = record['polasci_po_danu'];
      if (polasciRaw == null) continue;

      Map<String, dynamic>? polasci;
      if (polasciRaw is String) {
        try {
          polasci = jsonDecode(polasciRaw) as Map<String, dynamic>?;
        } catch (_) {
          continue;
        }
      } else if (polasciRaw is Map) {
        polasci = Map<String, dynamic>.from(polasciRaw);
      }

      if (polasci == null) continue;

      final dayData = polasci[danKratica];
      if (dayData == null || dayData is! Map) continue;

      // Proveri oba smera (bc i vs)
      for (final place in ['bc', 'vs']) {
        final placenoKey = '${place}_placeno';
        final vozacKey = '${place}_placeno_vozac';
        final iznosKey = '${place}_placeno_iznos';

        final placenoTimestamp = dayData[placenoKey] as String?;
        if (placenoTimestamp == null || placenoTimestamp.isEmpty) continue;

        try {
          final placenoDate = DateTime.parse(placenoTimestamp).toLocal();

          // Proveri da li je plaćeno u traženom periodu (danas)
          if (placenoDate.isBefore(from) || placenoDate.isAfter(to)) continue;

          final vozacIme = dayData[vozacKey] as String? ?? 'Nepoznat';
          final iznos = (dayData[iznosKey] as num?)?.toDouble() ?? 0;

          if (iznos > 0) {
            pazar[vozacIme] = (pazar[vozacIme] ?? 0) + iznos;
            ukupno += iznos;
          }
        } catch (_) {
          continue;
        }
      }
    }

    pazar['_ukupno'] = ukupno;
    return pazar;
  }

  /// Singleton instance for compatibility
  static final StatistikaService instance = StatistikaService._internal();
  StatistikaService._internal();

  /// Stream pazara za određenog vozača
  static Stream<double> streamPazarZaVozaca({
    required String vozac,
    required DateTime from,
    required DateTime to,
  }) {
    return streamPazarZaSveVozace(from: from, to: to).map((pazar) {
      return pazar[vozac] ?? 0.0;
    });
  }

  /// Stream broja mesečnih karata koje je vozač naplatio DANAS
  static Stream<int> streamBrojRegistrovanihZaVozaca({required String vozac}) {
    final now = DateTime.now();
    final danPocetak = DateTime(now.year, now.month, now.day);
    final danKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return streamPazarZaSveVozace(from: danPocetak, to: danKraj).map((pazar) {
      // Vraća broj uplata za vozača (aproksimacija)
      final iznos = pazar[vozac] ?? 0.0;
      // Pretpostavljamo prosečnu cenu od 500 RSD
      return iznos > 0 ? (iznos / 500).round() : 0;
    });
  }

  /// Stream broja dužnika
  static Stream<int> streamBrojDuznikaZaVozaca({required String vozac}) {
    return Stream.value(0);
  }

  /// Detaljne statistike po vozačima
  Future<Map<String, Map<String, dynamic>>> detaljneStatistikePoVozacima(
    List<dynamic> putnici,
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final Map<String, Map<String, dynamic>> stats = {};

    for (final putnik in putnici) {
      if (putnik is! Map) continue;
      final vozacId = putnik['vozac_id']?.toString() ?? 'nepoznat';

      stats.putIfAbsent(
          vozacId,
          () => {
                'putnika': 0,
                'pazar': 0.0,
              });

      stats[vozacId]!['putnika'] = (stats[vozacId]!['putnika'] as int) + 1;
      final cena = (putnik['cena'] as num?)?.toDouble() ?? 0;
      stats[vozacId]!['pazar'] = (stats[vozacId]!['pazar'] as double) + cena;
    }

    return stats;
  }

  /// Dohvati kilometražu za vozača
  Future<double> getKilometrazu(String vozac, DateTime from, DateTime to) async {
    // Placeholder - kilometraža se ne prati trenutno
    return 0.0;
  }
}
