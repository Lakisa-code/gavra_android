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
    // ⚠️ UKLONJENO: Polasci po danu više ne postoje u bazi (JSON kolona obrisana)
    // Ova metoda se zadržava privremeno radi kompatibilnosti, ali uvek vraća prazno.
    return {};
  }

  /// NOVO: Vraća sirove podatke iz polasci_po_danu bez filtriranja ključeva
  static Map<String, dynamic> parsePolasciPoDanuRaw(dynamic raw) {
    return {};
  }

  // Get broj mesta for a day and place (place 'bc' or 'vs').
  static int getBrojMestaForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    // Ako postoji broj_mesta u samom mapu (npr. iz seat_requests join-a), koristi njega
    if (rawMap.containsKey('broj_mesta') && rawMap['broj_mesta'] != null) {
      final bm = rawMap['broj_mesta'];
      if (bm is num) return bm.toInt();
      if (bm is String) return int.tryParse(bm) ?? 1;
    }
    return 1;
  }

  // Get polazak for a day and place ('bc' or 'vs').
  static String? getPolazakForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place, {
    bool isWinter = false,
  }) {
    // ⚠️ UKLONJENO: Više se ne čita iz JSON kolone.
    // Ako je map zapravo seat_request (join-ovan), vreme je u 'zeljeno_vreme'
    if (rawMap.containsKey('zeljeno_vreme') && rawMap['zeljeno_vreme'] != null) {
      final grad = rawMap['grad']?.toString().toLowerCase();
      final targetGrad = (place.toLowerCase() == 'vs' || place.toLowerCase() == 'vrsac') ? 'vs' : 'bc';
      if (grad == targetGrad) {
        return normalizeTime(rawMap['zeljeno_vreme'].toString());
      }
    }
    return null;
  }

  /// 🆕 Čitaj "adresa danas" ID iz polasci_po_danu JSON
  static String? getAdresaDanasIdForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    return null; // Obrisano sa JSON kolonom
  }

  /// 🆕 Čitaj "adresa danas" naziv iz polasci_po_danu JSON
  static String? getAdresaDanasNazivForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    return null; // Obrisano sa JSON kolonom
  }

  /// 🆕 Proveri da li je putnik otkazan
  static bool isOtkazanForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    // Ako je map seat_request, proveri status kolonu
    if (rawMap.containsKey('status')) {
      final status = rawMap['status']?.toString().toLowerCase();
      return status == 'otkazano' || status == 'cancelled';
    }
    return false;
  }

  /// 🆕 Dobij vreme otkazivanja
  static DateTime? getVremeOtkazivanjaForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    if (rawMap.containsKey('processed_at') && isOtkazanForDayAndPlace(rawMap, dayKratica, place)) {
      return DateTime.tryParse(rawMap['processed_at'].toString())?.toLocal();
    }
    return null;
  }

  static String? getOtkazaoVozacForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    if (rawMap.containsKey('vozac_id') && isOtkazanForDayAndPlace(rawMap, dayKratica, place)) {
      return rawMap['vozac_id']?.toString();
    }
    return null;
  }

  static String? getStatusForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    if (rawMap.containsKey('status')) {
      return rawMap['status']?.toString();
    }
    return null;
  }

  static double? getIznosPlacanjaForDayAndPlace(Map<String, dynamic> map, String dan, String place) {
    return null; // Više se ne čita odavde
  }

  static DateTime? getVremePlacanjaForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    return null; // Obrisano sa JSON kolonom
  }

  static String? getNaplatioVozacForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    return null; // Obrisano sa JSON kolonom
  }

  static DateTime? getVremePokupljenjaForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
    if (rawMap.containsKey('status') && rawMap['status'] == 'confirmed') {
      return rawMap['processed_at'] != null ? DateTime.parse(rawMap['processed_at']).toLocal() : null;
    }
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
