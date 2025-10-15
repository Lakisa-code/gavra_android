import 'dart:convert';
import 'time_validator.dart';

enum MesecniStatus { active, canceled, vacation, unknown }

class MesecniHelpers {
  // Normalize time using standardized TimeValidator
  static String? normalizeTime(String? raw) {
    return TimeValidator.normalizeTimeFormat(raw);
  }

  // Parse polasci_po_danu which may be a JSON string or Map.
  // Returns map like {'pon': {'bc': '6:00', 'vs': '14:00'}, ...}
  static Map<String, Map<String, String?>> parsePolasciPoDanu(dynamic raw) {
    Map<String, dynamic>? decoded;
    if (raw == null) return {};
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        decoded = null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return {};

    final Map<String, Map<String, String?>> out = {};
    decoded.forEach((dayKey, val) {
      if (val == null) return;
      if (val is Map) {
        final bc = val['bc'] ??
            val['bela_crkva'] ??
            val['polazak_bc'] ??
            val['bc_time'];
        final vs =
            val['vs'] ?? val['vrsac'] ?? val['polazak_vs'] ?? val['vs_time'];
        out[dayKey] = {
          'bc': normalizeTime(bc?.toString()),
          'vs': normalizeTime(vs?.toString()),
        };
      } else if (val is String) {
        out[dayKey] = {'bc': normalizeTime(val), 'vs': null};
      }
    });
    return out;
  }

  // Get polazak for a day and place (place 'bc' or 'vs').
  // rawMap is the DB row map with either polasci_po_danu or per-day columns polazak_bc_pon etc.
  static String? getPolazakForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final parsed = parsePolasciPoDanu(rawMap['polasci_po_danu']);
    final pday = parsed[dayKratica];
    if (pday != null) {
      final raw = pday[place];
      if (raw != null) return normalizeTime(raw);
    }

    // Try several column name variants that may exist in the DB:
    // Only per-day short names are supported now (canonical):
    // - polazak_bc_pon / polazak_vs_pon
    // - polazak_bc_pon_time / polazak_vs_pon_time (some exports)
    final candidates = <String>[
      // canonical per-day columns
      'polazak_${place}_$dayKratica',
      'polazak_${place}_${dayKratica}_time',
      // alternative export variants
      '${place}_polazak_$dayKratica',
      '${place}_${dayKratica}_polazak',
      '${place}_${dayKratica}_polazak',
      '${place}_${dayKratica}_time',
      'polazak_${dayKratica}_$place',
      'polazak_${dayKratica}_${place}_time',
    ];

    for (final col in candidates) {
      if (rawMap.containsKey(col) && rawMap[col] != null) {
        final rawVal = rawMap[col];
        return normalizeTime(rawVal?.toString());
      }
    }

    return null;
  }

  // Is active (soft delete handling)
  static bool isActiveFromMap(Map<String, dynamic>? m) {
    if (m == null) return true;
    final obrisan = m['obrisan'] ?? m['deleted'] ?? m['deleted_at'];
    if (obrisan != null) {
      if (obrisan is bool) return !obrisan;
      final s = obrisan.toString().toLowerCase();
      if (s == 'true' || s == '1' || s == 't') return false;
      if (s.isNotEmpty && RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return false;
      }
    }

    final aktivan = m['aktivan'];
    if (aktivan != null) {
      if (aktivan is bool) return aktivan;
      final s = aktivan.toString().toLowerCase();
      if (s == 'false' || s == '0' || s == 'f') return false;
      return true;
    }

    return true;
  }

  // Status converter
  static MesecniStatus statusFromString(String? raw) {
    if (raw == null) return MesecniStatus.unknown;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return MesecniStatus.unknown;

    final map = {
      'otkazano': MesecniStatus.canceled,
      'otkazan': MesecniStatus.canceled,
      'otkazana': MesecniStatus.canceled,
      'otkaz': MesecniStatus.canceled,
      'godišnji': MesecniStatus.vacation,
      'godisnji': MesecniStatus.vacation,
      'godisnji_odmor': MesecniStatus.vacation,
      'aktivan': MesecniStatus.active,
      'active': MesecniStatus.active,
      'placeno': MesecniStatus.active,
    };
    for (final k in map.keys) {
      if (s.contains(k)) return map[k]!;
    }
    return MesecniStatus.unknown;
  }

  // Price paid check - flexible and safe
  static bool priceIsPaid(Map<String, dynamic>? m) {
    if (m == null) return false;

    final placeno = m['placeno'];
    if (placeno != null) {
      if (placeno is bool) return placeno;
      final s = placeno.toString().toLowerCase();
      if (s == 'true' || s == '1' || s == 't') return true;
      if (s == 'false' || s == '0' || s == 'f') return false;
    }

    final pm = m['placeni_mesec'] ?? m['placeniMesec'];
    final pg = m['placena_godina'] ?? m['placenaGodina'];
    if (pm != null || pg != null) {
      if ((pm is String && pm.trim().isNotEmpty) || pm is num) return true;
      if ((pg is String && pg.trim().isNotEmpty) || pg is num) return true;
    }

    double? tryParse(dynamic x) {
      if (x == null) return null;
      if (x is num) return x.toDouble();
      final s = x.toString().replaceAll(',', '.').trim();
      return double.tryParse(s);
    }

    final ukupna = tryParse(m['ukupnaCenaMeseca'] ?? m['ukupna_cena_meseca']);
    if (ukupna != null && ukupna > 0) return true;

    final cena = tryParse(m['cena']);
    if (cena != null && cena > 0) return true;

    return false;
  }

  // Build a simple statistics map from known fields.
  // Example keys: trips_total, trips_cancelled, last_trip_at
  static Map<String, dynamic> buildStatistics(Map<String, dynamic>? m) {
    if (m == null) return <String, dynamic>{};
    final out = <String, dynamic>{};
    try {
      final trips = m['broj_putovanja'] ?? m['brojPutovanja'] ?? 0;
      final cancelled = m['broj_otkazivanja'] ?? m['brojOtkazivanja'] ?? 0;
      final last = m['poslednje_putovanje'] ?? m['poslednjePutovanje'];
      out['trips_total'] =
          (trips is num) ? trips : int.tryParse(trips?.toString() ?? '0') ?? 0;
      out['trips_cancelled'] = (cancelled is num)
          ? cancelled
          : int.tryParse(cancelled?.toString() ?? '0') ?? 0;
      if (last != null) out['last_trip_at'] = last.toString();
    } catch (_) {
      // swallow parse errors and return minimal map
    }
    return out;
  }

  // Normalize polasci map into canonical structure for sending to DB.
  // Accepts either Map or JSON string; returns Map<String, Map<String,String?>>
  static Map<String, Map<String, String?>> normalizePolasciForSend(
    dynamic raw,
  ) {
    // Support client-side shape Map<String, List<String>> (e.g. {'pon': ['6:00 BC','14:00 VS']})
    if (raw is Map) {
      final hasListValues = raw.values.any((v) => v is List);
      if (hasListValues) {
        final temp = <String, Map<String, String?>>{};
        raw.forEach((key, val) {
          if (val is List) {
            String? bc;
            String? vs;
            for (final entry in val) {
              if (entry == null) continue;
              final s = entry.toString().trim();
              if (s.isEmpty) continue;
              final parts = s.split(RegExp(r'\s+'));
              final valPart = parts[0];
              final suffix = parts.length > 1 ? parts[1].toLowerCase() : '';
              if (suffix.startsWith('bc')) {
                bc = normalizeTime(valPart) ?? valPart;
              } else if (suffix.startsWith('vs')) {
                vs = normalizeTime(valPart) ?? valPart;
              } else {
                bc = normalizeTime(valPart) ?? valPart;
              }
            }
            if ((bc != null && bc.isNotEmpty) ||
                (vs != null && vs.isNotEmpty)) {
              temp[key.toString()] = {'bc': bc, 'vs': vs};
            }
          }
        });
        final days = ['pon', 'uto', 'sre', 'cet', 'pet'];
        final out = <String, Map<String, String?>>{};
        for (final d in days) {
          if (temp.containsKey(d)) out[d] = temp[d]!;
        }
        return out;
      }
    }

    final parsed = parsePolasciPoDanu(raw);
    final days = ['pon', 'uto', 'sre', 'cet', 'pet'];
    final out = <String, Map<String, String?>>{};
    for (final d in days) {
      final p = parsed[d];
      if (p == null) continue;
      final bc = p['bc'];
      final vs = p['vs'];
      if ((bc != null && bc.isNotEmpty) || (vs != null && vs.isNotEmpty)) {
        out[d] = {'bc': bc, 'vs': vs};
      }
    }
    return out;
  }
}




