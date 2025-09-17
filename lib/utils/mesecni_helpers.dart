import 'dart:convert';

enum MesecniStatus { active, canceled, vacation, unknown }

class MesecniHelpers {
  // Normalize time: "06:00:00" -> "6:00", "14:05:00" -> "14:05", "6:0" -> "6:00"
  static String? normalizeTime(String? raw) {
    if (raw == null) return null;
    raw = raw.trim();
    if (raw.isEmpty) return null;

    try {
      // Remove timezone or extra trailing tokens (keep first token and AM/PM if present)
      var token = raw.split(RegExp(r"\s+"))[0];
      // But if AM/PM exists separated by space (e.g. "6:00 pm"), capture whole string
      // Normalize common separators (e.g. 06:00:00+00, 06:00:00.000Z)
      token = token.replaceAll(RegExp(r"Z$"), '');
      token = token.split(RegExp(r"[+\-]"))[0];

      // Try to match with optional seconds and optional AM/PM suffix (with optional space)
      final re = RegExp(
          r'^(\d{1,2}):(\d{1,2})(?::\d{1,2}(?:\.\d+)?)?\s*([aApP][mM])?\$');
      var m = re.firstMatch(raw);
      // If not matched against full raw (covers cases like "6:00 pm"), try token + possible suffix
      if (m == null) {
        // Try to capture if AM/PM is separate token, e.g. "6:00 pm"
        final parts = raw.split(RegExp(r"\s+"));
        if (parts.length >= 2 &&
            RegExp(r'^[aApP][mM]\$').hasMatch(parts.last)) {
          final joined =
              '${parts.sublist(0, parts.length - 1).join(' ')}${parts.last}';
          m = re.firstMatch(joined);
        } else {
          m = re.firstMatch(token);
        }
      }

      if (m == null) return raw; // leave as-is if unexpected format

      var hour = int.parse(m.group(1)!);
      var min = int.parse(m.group(2)!);
      final ampm = m.group(3);

      if (ampm != null) {
        final a = ampm.toLowerCase();
        if (a == 'am') {
          if (hour == 12) hour = 0; // 12:00 AM -> 0:00
        } else if (a == 'pm') {
          if (hour < 12) hour += 12; // 1:00 PM -> 13:00
        }
      }

      final minStr = min.toString().padLeft(2, '0');
      final hourStr = hour.toString().padLeft(2, '0');
      return '$hourStr:$minStr';
    } catch (_) {
      return raw;
    }
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
        final bc = val['bc'] ?? val['bela_crkva'] ?? val['polazak_bc'];
        final vs = val['vs'] ?? val['vrsac'] ?? val['polazak_vs'];
        out[dayKey] = {
          'bc': normalizeTime(bc?.toString()),
          'vs': normalizeTime(vs?.toString())
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
      Map<String, dynamic> rawMap, String dayKratica, String place) {
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
      'polazak_${place}_$dayKratica',
      'polazak_${place}_${dayKratica}_time',
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
      'placeno': MesecniStatus.active
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
}
