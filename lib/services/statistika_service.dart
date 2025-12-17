import 'package:supabase_flutter/supabase_flutter.dart';

import 'vozac_mapping_service.dart';

/// Servis za statistiku - koristi SAMO registrovani_putnici tabelu
/// Sve statistike se čuvaju u JSONB kolonama: statistics, action_log
class StatistikaService {
  static final _supabase = Supabase.instance.client;

  /// Stream pazara za sve vozače - SIMPLIFIKOVANO
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  static Stream<Map<String, double>> streamPazarZaSveVozace({
    required DateTime from,
    required DateTime to,
  }) {
    // Koristi registrovani_putnici tabelu
    return _supabase.from('registrovani_putnici').stream(primaryKey: ['id']).map((data) {
      final Map<String, double> pazar = {};
      double ukupno = 0;

      for (final row in data) {
        // Proveri da li je plaćeno u datom periodu
        final datumPlacanja = row['datum_placanja'] as String?;
        if (datumPlacanja == null) continue;

        try {
          final placenoDatum = DateTime.parse(datumPlacanja);
          if (placenoDatum.isAfter(from) && placenoDatum.isBefore(to.add(const Duration(days: 1)))) {
            final cena = (row['cena'] as num?)?.toDouble() ?? 0;

            // Pronađi vozača koji je naplatio
            final actionLog = row['action_log'];
            String vozacIme = 'Nepoznat';

            if (actionLog is List && actionLog.isNotEmpty) {
              // Pronađi poslednju 'paid' akciju
              for (final action in actionLog.reversed) {
                if (action is Map && action['action'] == 'paid') {
                  vozacIme = action['by']?.toString() ?? 'Nepoznat';
                  break;
                }
              }
            }

            pazar[vozacIme] = (pazar[vozacIme] ?? 0) + cena;
            ukupno += cena;
          }
        } catch (_) {}
      }

      pazar['_ukupno'] = ukupno;
      return pazar;
    });
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

    // Dohvati UUID vozača za poređenje
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozac);

    return _supabase.from('registrovani_putnici').stream(primaryKey: ['id']).map((data) {
      int count = 0;
      for (final row in data) {
        // Proveri da li je mesečni putnik (ucenik ili radnik, ne dnevni)
        final tip = row['tip'] as String?;
        if (tip == 'dnevni') continue;

        // Proveri da li je plaćeno danas
        final vremePlacanja = row['vreme_placanja'] as String?;
        if (vremePlacanja == null) continue;

        try {
          final placenoDatum = DateTime.parse(vremePlacanja);
          if (placenoDatum.isAfter(danPocetak) && placenoDatum.isBefore(danKraj)) {
            // Pronađi vozača koji je naplatio iz action_log
            final actionLog = row['action_log'];
            if (actionLog is Map) {
              // Nova struktura: {actions: [...], paid_by: "uuid"}
              final paidBy = actionLog['paid_by']?.toString() ?? '';
              if (paidBy == vozac || paidBy == vozacUuid || paidBy.contains(vozac)) {
                count++;
                continue;
              }
              // Proveri i actions listu
              final actions = actionLog['actions'] as List?;
              if (actions != null) {
                for (final action in actions.reversed) {
                  if (action is Map && action['type'] == 'paid') {
                    final actionBy = action['vozac_id']?.toString() ?? '';
                    if (actionBy == vozac || actionBy == vozacUuid || actionBy.contains(vozac)) {
                      count++;
                      break;
                    }
                  }
                }
              }
            } else if (actionLog is List) {
              // Stara struktura: lista akcija
              for (final action in actionLog.reversed) {
                if (action is Map && (action['action'] == 'paid' || action['type'] == 'paid')) {
                  final paidBy = action['by']?.toString() ?? action['vozac_id']?.toString() ?? '';
                  if (paidBy == vozac || paidBy == vozacUuid || paidBy.contains(vozac)) {
                    count++;
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
      return count;
    });
  }

  /// Stream broja dužnika za vozača
  static Stream<int> streamBrojDuznikaZaVozaca({required String vozac}) {
    return _supabase.from('registrovani_putnici').stream(primaryKey: ['id']).map((data) {
      return data.where((row) {
        return row['aktivan'] == true && row['placeno'] != true;
      }).length;
    });
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
