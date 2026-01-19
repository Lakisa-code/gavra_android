import 'dart:convert';

import 'grad_adresa_validator.dart';

enum RegistrovaniStatus { active, canceled, vacation, unknown }

class RegistrovaniHelpers {
  // Normalize time using GradAdresaValidator for consistency across the app
  static String? normalizeTime(String? raw) {
    return GradAdresaValidator.normalizeTime(raw);
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
        final bc = val['bc'] ?? val['bela_crkva'] ?? val['polazak_bc'] ?? val['bc_time'];
        final vs = val['vs'] ?? val['vrsac'] ?? val['polazak_vs'] ?? val['vs_time'];
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

  // Get broj mesta for a day and place (place 'bc' or 'vs').
  static int getBrojMestaForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    // 1. Prvo probaj iz polasci_po_danu JSON (bc_mesta / vs_mesta)
    final parsed = parsePolasciPoDanu(rawMap['polasci_po_danu']);
    final pday = parsed[dayKratica];
    if (pday != null) {
      final mestaKey = '${place}_mesta';
      final raw = rawMap['polasci_po_danu'];
      if (raw is Map) {
        final dayData = raw[dayKratica];
        if (dayData is Map && dayData[mestaKey] != null) {
          return (dayData[mestaKey] as num?)?.toInt() ?? 1;
        }
      }
    }

    // 2. Fallback: koristi globalnu kolonu broj_mesta ako postoji
    final globalBrojMesta = rawMap['broj_mesta'];
    if (globalBrojMesta != null) {
      return (globalBrojMesta as num?)?.toInt() ?? 1;
    }

    return 1; // Default 1 mesto
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

  /// 🆕 Čitaj "adresa danas" ID iz polasci_po_danu JSON za specifičan dan i grad
  /// Vraća UUID adrese ako postoji override za danas, inače null
  static String? getAdresaDanasIdForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_adresa_danas_id' ili 'vs_adresa_danas_id'
    final adresaKey = '${place}_adresa_danas_id';
    return dayData[adresaKey] as String?;
  }

  /// 🆕 Čitaj "adresa danas" naziv iz polasci_po_danu JSON za specifičan dan i grad
  static String? getAdresaDanasNazivForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_adresa_danas' ili 'vs_adresa_danas'
    final adresaKey = '${place}_adresa_danas';
    return dayData[adresaKey] as String?;
  }

  /// 🆕 Dobij dodeljenog vozača za specifičan dan i pravac (bc ili vs)
  /// Vraća ime vozača ako je postavljen u polasci_po_danu JSON-u
  /// Ključ je npr. 'bc_vozac' ili 'vs_vozac'
  static String? getDodeljenVozacForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_vozac' ili 'vs_vozac'
    final vozacKey = '${place}_vozac';
    return dayData[vozacKey] as String?;
  }

  /// 🆕 HELPER: Izračunaj poslednji petak u ponoć (reset point)
  /// Nedelja se resetuje u ponoć petak→subota
  static DateTime _getLastFridayMidnight() {
    final now = DateTime.now();
    // weekday: 1=pon, 2=uto, 3=sre, 4=cet, 5=pet, 6=sub, 7=ned
    int daysToSubtract;
    if (now.weekday == 6) {
      // Subota - petak je bio juče
      daysToSubtract = 1;
    } else if (now.weekday == 7) {
      // Nedelja - petak je bio pre 2 dana
      daysToSubtract = 2;
    } else {
      // Pon-Pet - petak je bio prošle nedelje
      daysToSubtract = now.weekday + 2; // pon=3, uto=4, sre=5, cet=6, pet=7
    }
    final lastFriday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
    // Ponoć petak→subota = petak 24:00 = subota 00:00
    return DateTime(lastFriday.year, lastFriday.month, lastFriday.day, 0, 0, 0);
  }

  /// 🆕 HELPER: Čitaj status polaska iz polasci_po_danu JSON-a
  /// Vraća 'pending', 'confirmed', 'waiting', ili null ako status ne postoji
  static String? getStatusForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_status' ili 'vs_status'
    final statusKey = '${place}_status';
    return dayData[statusKey] as String?;
  }

  /// 🆕 Proveri da li je putnik otkazan za specifičan dan i grad (polazak)
  /// Vraća true ako postoji timestamp otkazivanja POSLE poslednjeg petka u ponoć
  /// (resetuje se svake nedelje petak→subota u ponoć)
  static bool isOtkazanForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return false;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return false;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return false;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return false;

    // Ključ je npr. 'bc_otkazano' ili 'vs_otkazano'
    final otkazanoKey = '${place}_otkazano';
    final otkazanoTimestamp = dayData[otkazanoKey] as String?;

    if (otkazanoTimestamp == null || otkazanoTimestamp.isEmpty) return false;

    // 🆕 FIX: Važi samo ako je otkazano POSLE poslednjeg petka u ponoć
    try {
      final otkazanoDate = DateTime.parse(otkazanoTimestamp).toLocal();
      final resetPoint = _getLastFridayMidnight();
      return otkazanoDate.isAfter(resetPoint);
    } catch (_) {
      return false;
    }
  }

  /// 🆕 Dobij vreme otkazivanja iz polasci_po_danu JSON-a za specifičan dan i grad
  /// Vraća DateTime ako postoji timestamp otkazivanja POSLE poslednjeg petka u ponoć
  static DateTime? getVremeOtkazivanjaForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_otkazano' ili 'vs_otkazano'
    final otkazanoKey = '${place}_otkazano';
    final otkazanoTimestamp = dayData[otkazanoKey] as String?;

    if (otkazanoTimestamp == null || otkazanoTimestamp.isEmpty) return null;

    // 🆕 FIX: Vrati timestamp samo ako je POSLE poslednjeg petka u ponoć
    try {
      final otkazanoDate = DateTime.parse(otkazanoTimestamp).toLocal();
      final resetPoint = _getLastFridayMidnight();
      if (otkazanoDate.isAfter(resetPoint)) {
        return otkazanoDate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 🆕 Dobij ime vozača koji je otkazao iz polasci_po_danu JSON-a za specifičan dan i grad
  static String? getOtkazaoVozacForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_otkazao_vozac' ili 'vs_otkazao_vozac'
    final vozacKey = '${place}_otkazao_vozac';
    return dayData[vozacKey] as String?;
  }

  /// 🆕 Dobij vreme pokupljanja iz polasci_po_danu JSON-a za specifičan dan i grad
  /// Vraća DateTime ako postoji timestamp pokupljanja POSLE poslednjeg petka u ponoć
  static DateTime? getVremePokupljenjaForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_pokupljeno' ili 'vs_pokupljeno'
    final pokupljenoKey = '${place}_pokupljeno';
    final pokupljenoTimestamp = dayData[pokupljenoKey] as String?;

    if (pokupljenoTimestamp == null || pokupljenoTimestamp.isEmpty) return null;

    // 🆕 FIX: Vrati timestamp samo ako je POSLE poslednjeg petka u ponoć
    try {
      final pokupljenoDate = DateTime.parse(pokupljenoTimestamp).toLocal();
      final resetPoint = _getLastFridayMidnight();
      if (pokupljenoDate.isAfter(resetPoint)) {
        return pokupljenoDate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 🆕 Dobij ime vozača koji je pokupio iz polasci_po_danu JSON-a za specifičan dan i grad
  /// Vraća ime vozača samo ako je pokupljeno POSLE poslednjeg petka u ponoć
  static String? getPokupioVozacForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_pokupljeno_vozac' ili 'vs_pokupljeno_vozac'
    final vozacKey = '${place}_pokupljeno_vozac';
    return dayData[vozacKey] as String?;
  }

  /// 🆕 Dobij vreme plaćanja iz polasci_po_danu JSON-a za specifičan dan i grad
  /// Vraća DateTime ako postoji timestamp plaćanja za DANAS, inače null
  static DateTime? getVremePlacanjaForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_placeno' ili 'vs_placeno'
    // 🆕 FALLBACK LOGIKA: Proveri i drugi grad jer je dnevna karta validna za oba
    var placenoTimestamp = dayData['${place}_placeno'] as String?;
    if (placenoTimestamp == null) {
      final otherPlace = place == 'bc' ? 'vs' : 'bc';
      placenoTimestamp = dayData['${otherPlace}_placeno'] as String?;
    }

    if (placenoTimestamp == null || placenoTimestamp.isEmpty) return null;

    try {
      final placenoDate = DateTime.parse(placenoTimestamp).toLocal();
      final danas = DateTime.now();
      // Vrati samo ako je DANAS
      if (placenoDate.year == danas.year && placenoDate.month == danas.month && placenoDate.day == danas.day) {
        return placenoDate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 🆕 Dobij ime vozača koji je naplatio iz polasci_po_danu JSON-a
  /// NAPOMENA: Plaćanje važi za ceo mesec, pa tražimo vozača u SVIM danima
  /// Koristi jednostavno polje 'placeno_vozac' (bez bc/vs prefiksa)
  static String? getNaplatioVozacForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    // Traži u SVIM danima jer plaćanje važi za ceo mesec
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    for (final dan in dani) {
      final data = decoded[dan];
      if (data != null && data is Map) {
        // 1. Prvo probaj jednostavno 'placeno_vozac'
        if (data['placeno_vozac'] != null) {
          return data['placeno_vozac'] as String?;
        }
        // 2. Fallback na stare ključeve bc_placeno_vozac / vs_placeno_vozac
        if (data['bc_placeno_vozac'] != null) {
          return data['bc_placeno_vozac'] as String?;
        }
        if (data['vs_placeno_vozac'] != null) {
          return data['vs_placeno_vozac'] as String?;
        }
      }
    }

    return null;
  }

  /// 🆕 Dobij iznos plaćanja iz polasci_po_danu JSON-a za specifičan dan i grad
  static double? getIznosPlacanjaForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place,
  ) {
    final raw = rawMap['polasci_po_danu'];
    if (raw == null) return null;

    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }
    if (decoded == null) return null;

    final dayData = decoded[dayKratica];
    if (dayData == null || dayData is! Map) return null;

    // Ključ je npr. 'bc_placeno_iznos' ili 'vs_placeno_iznos'
    // 🆕 FALLBACK LOGIKA: Proveri i drugi grad
    var iznos = dayData['${place}_placeno_iznos'];
    if (iznos == null) {
      final otherPlace = place == 'bc' ? 'vs' : 'bc';
      iznos = dayData['${otherPlace}_placeno_iznos'];
    }

    if (iznos == null) return null;
    if (iznos is num) return iznos.toDouble();
    return double.tryParse(iznos.toString());
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
  static RegistrovaniStatus statusFromString(String? raw) {
    if (raw == null) return RegistrovaniStatus.unknown;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return RegistrovaniStatus.unknown;

    final map = {
      'otkazano': RegistrovaniStatus.canceled,
      'otkazan': RegistrovaniStatus.canceled,
      'otkazana': RegistrovaniStatus.canceled,
      'otkaz': RegistrovaniStatus.canceled,
      'godišnji': RegistrovaniStatus.vacation,
      'godisnji': RegistrovaniStatus.vacation,
      'godisnji_odmor': RegistrovaniStatus.vacation,
      'aktivan': RegistrovaniStatus.active,
      'active': RegistrovaniStatus.active,
      'placeno': RegistrovaniStatus.active,
    };
    for (final k in map.keys) {
      if (s.contains(k)) return map[k]!;
    }
    return RegistrovaniStatus.unknown;
  }

  // Price paid check - flexible and safe
  // NAPOMENA: Ovo se sada koristi samo za polasci_po_danu JSON polja
  // Prava provera plaćanja se radi iz voznje_log tabele
  static bool priceIsPaid(Map<String, dynamic>? m) {
    if (m == null) return false;

    // Provera placeno polja u polasci_po_danu JSON
    final placeno = m['placeno'];
    if (placeno != null) {
      if (placeno is bool) return placeno;
      final s = placeno.toString().toLowerCase();
      if (s == 'true' || s == '1' || s == 't') return true;
      // Ako je timestamp, znači da je plaćeno
      if (s.contains('2025') || s.contains('2024') || s.contains('2026')) return true;
    }

    return false;
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
            if ((bc != null && bc.isNotEmpty) || (vs != null && vs.isNotEmpty)) {
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
