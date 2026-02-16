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
    final decoded = _decodePolasciPoDanu(raw);
    if (decoded == null) return {};

    final Map<String, Map<String, String?>> out = {};
    decoded.forEach((dayKey, val) {
      if (val == null) return;
      if (val is Map) {
        final bc = val['bc'] ?? val['bela_crkva'] ?? val['polazak_bc'] ?? val['bc_time'];
        final vs = val['vs'] ?? val['vrsac'] ?? val['polazak_vs'] ?? val['vs_time'];
        final bc2 = val['bc2'];
        final vs2 = val['vs2'];
        out[dayKey] = {
          'bc': normalizeTime(bc?.toString()),
          'vs': normalizeTime(vs?.toString()),
          'bc2': normalizeTime(bc2?.toString()),
          'vs2': normalizeTime(vs2?.toString()),
        };
      } else if (val is String) {
        out[dayKey] = {'bc': normalizeTime(val), 'vs': null};
      }
    });
    return out;
  }

  /// NOVO: Vraća sirove podatke iz polasci_po_danu bez filtriranja ključeva
  static Map<String, dynamic> parsePolasciPoDanuRaw(dynamic raw) {
    return _decodePolasciPoDanu(raw) ?? {};
  }

  static Map<String, dynamic>? _decodePolasciPoDanu(dynamic raw) {
    Map<String, dynamic>? decoded;
    if (raw == null) return null;
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    } else if (raw is Map) {
      decoded = Map<String, dynamic>.from(raw);
    }

    if (decoded == null) return null;

    // Osiguraj da su svi ključevi dana lowercase za konzistentnost
    return decoded.map((key, value) => MapEntry(key.toLowerCase(), value));
  }

  // Get broj mesta for a day and place (place 'bc' or 'vs').
  static int getBrojMestaForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      final key = '${place.toLowerCase()}_mesta';
      final val = dayData[key] ?? dayData['mesta'];
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 1;
    }
    return (rawMap['broj_mesta'] as int?) ?? 1;
  }

  // Get polazak for a day and place ('bc' or 'vs').
  static String? getPolazakForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place, {
    bool isWinter = false,
  }) {
    final polasci = parsePolasciPoDanu(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData != null) {
      return dayData[place.toLowerCase()];
    }

    // Fallback logic for legacy columns
    final candidates = [
      'polazak_${place}_$dayKratica',
      'polazak_${place}_${dayKratica}_time',
      '${place}_polazak_$dayKratica',
      '${place}_${dayKratica}_polazak',
    ];

    for (final col in candidates) {
      if (rawMap.containsKey(col) && rawMap[col] != null) {
        return normalizeTime(rawMap[col]?.toString());
      }
    }
    return null;
  }

  /// 🆕 Čitaj "adresa danas" ID iz polasci_po_danu JSON
  static String? getAdresaDanasIdForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      return dayData['${place.toLowerCase()}_adresa_danas_id'] as String?;
    }
    return null;
  }

  /// 🆕 Čitaj "adresa danas" naziv iz polasci_po_danu JSON
  static String? getAdresaDanasNazivForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      return dayData['${place.toLowerCase()}_adresa_danas'] as String?;
    }
    return null;
  }

  /// 🆕 Proveri da li je putnik otkazan
  static bool isOtkazanForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      final otkazanoTimestamp = dayData['${place.toLowerCase()}_otkazano'] as String?;
      if (otkazanoTimestamp != null && otkazanoTimestamp.isNotEmpty) {
        try {
          DateTime.parse(otkazanoTimestamp).toLocal();
          return true;
        } catch (_) {}
      }
    }
    return false;
  }

  /// 🆕 Dobij vreme otkazivanja
  static DateTime? getVremeOtkazivanjaForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      final val = dayData['${place.toLowerCase()}_otkazano'];
      if (val != null) return DateTime.tryParse(val.toString())?.toLocal();
    }
    return null;
  }

  static String? getOtkazaoVozacForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      return dayData['${place.toLowerCase()}_otkazano_vozac'] as String?;
    }
    return null;
  }

  static String? getStatusForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      return dayData['${place.toLowerCase()}_status'] as String?;
    }
    return null;
  }

  static double? getIznosPlacanjaForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    final polasci = parsePolasciPoDanuRaw(map['polasci_po_danu']);
    final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
    if (danData == null) return null;

    final placeLower = place.toLowerCase();
    final payments = danData['${placeLower}_placanja'] as List?;
    if (payments != null && payments.isNotEmpty) {
      double sum = 0;
      for (var p in payments) {
        if (p is Map) {
          final iznos = p['iznos'];
          if (iznos is num) {
            sum += iznos.toDouble();
          } else if (iznos is String) {
            sum += double.tryParse(iznos) ?? 0;
          }
        }
      }
      return sum > 0 ? sum : null;
    }

    final value = danData['${placeLower}_placeno'] ?? danData['${placeLower}_iznos_placanja'];
    if (value == null) return null;
    if (value is bool) return value ? 600.0 : null; // Legacy true -> 600
    return (value is num) ? value.toDouble() : double.tryParse(value.toString());
  }

  static DateTime? getVremePlacanjaForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    final polasci = parsePolasciPoDanuRaw(map['polasci_po_danu']);
    final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
    if (danData == null) return null;

    final placeLower = place.toLowerCase();
    final payments = danData['${placeLower}_placanja'] as List?;
    if (payments != null && payments.isNotEmpty) {
      String? latest;
      for (var p in payments) {
        if (p is Map && p['vreme'] != null) {
          final pVreme = p['vreme'].toString();
          if (latest == null || pVreme.compareTo(latest) > 0) {
            latest = pVreme;
          }
        }
      }
      return latest != null ? DateTime.tryParse(latest)?.toLocal() : null;
    }

    final value = danData['${placeLower}_vreme_placanja'] ?? danData['${placeLower}_placeno'];
    if (value == null) return null;
    if (value is bool) return value ? DateTime.now() : null; // Legacy true -> now
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String? getNaplatioVozacForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    final polasci = parsePolasciPoDanuRaw(map['polasci_po_danu']);
    final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
    if (danData == null) return null;

    final payments = danData['${place.toLowerCase()}_placanja'] as List?;
    if (payments != null && payments.isNotEmpty) {
      String? driver;
      String? latest;
      for (var p in payments) {
        if (p is Map && p['vozac'] != null) {
          if (latest == null || (p['vreme'] ?? '').toString().compareTo(latest) > 0) {
            latest = (p['vreme'] ?? '').toString();
            driver = p['vozac'] as String;
          }
        }
      }
      return driver;
    }
    return danData['${place.toLowerCase()}_naplatio_vozac'] as String?;
  }

  static DateTime? getVremePokupljenjaForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    final polasci = parsePolasciPoDanuRaw(map['polasci_po_danu']);
    final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
    if (danData == null) return null;

    final value = danData['${place.toLowerCase()}_pokupljeno'];
    if (value == null) return null;

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final today = DateTime.now();
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) return dt;
    } catch (_) {}
    return null;
  }

  static String? getPokupioVozacForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    final polasci = parsePolasciPoDanuRaw(map['polasci_po_danu']);
    final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
    if (danData == null) return null;
    return danData['${place.toLowerCase()}_pokupljeno_vozac'] as String?;
  }

  /// 🆕 Dobij dodeljenog vozača iz polasci_po_danu JSON-a
  static String? getDodeljenVozacForDayAndPlace(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place, {
    String? vreme,
  }) {
    final polasci = parsePolasciPoDanuRaw(rawMap['polasci_po_danu']);
    final dayData = polasci[dayKratica.toLowerCase()];
    if (dayData is Map) {
      // 1. Prioritet: specifičan vozač za to vreme (npr. bc_5:00_vozac)
      if (vreme != null && vreme.isNotEmpty) {
        final timeKey = '${place.toLowerCase()}_${vreme}_vozac';
        if (dayData.containsKey(timeKey)) return dayData[timeKey] as String?;
      }
      // 2. Opšti vozač za taj pravac (npr. bc_vozac)
      final placeKey = '${place.toLowerCase()}_vozac';
      return dayData[placeKey] as String?;
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
