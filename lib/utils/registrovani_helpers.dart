import 'grad_adresa_validator.dart';

enum RegistrovaniStatus { active, canceled, vacation, unknown }

class RegistrovaniHelpers {
  // Normalize time using GradAdresaValidator for consistency across the app
  static String? normalizeTime(String? raw) {
    return GradAdresaValidator.normalizeTime(raw);
  }

  // ⚠️ SSOT: Polasci po danu se sada čuvaju ISKLJUČIVO u seat_requests tabeli.
  // Ove metode su zadržane radi kompatibilnosti interfejsa, ali više ne koriste JSON kolone.

  // Get broj mesta from raw map (usually a seat_request)
  static int getBrojMestaForDay(Map<String, dynamic> rawMap, String dayKratica, String place) {
    if (rawMap.containsKey('broj_mesta') && rawMap['broj_mesta'] != null) {
      final bm = rawMap['broj_mesta'];
      if (bm is num) return bm.toInt();
      if (bm is String) return int.tryParse(bm) ?? 1;
    }
    return 1;
  }

  // Get polazak for a day and place ('bc' or 'vs') from seat_request
  static String? getPolazakForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place, {
    bool isWinter = false,
  }) {
    if (rawMap.containsKey('zeljeno_vreme') && rawMap['zeljeno_vreme'] != null) {
      final grad = rawMap['grad']?.toString().toLowerCase();
      final targetGrad = (place.toLowerCase() == 'vs' || place.toLowerCase() == 'vrsac') ? 'vs' : 'bc';
      if (grad == targetGrad) {
        return normalizeTime(rawMap['zeljeno_vreme'].toString());
      }
    }
    return null;
  }

  /// Proveri da li je putnik otkazan
  static bool isOtkazanForDayAndPlace(Map<String, dynamic> rawMap, String dayKratica, String place) {
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

  static bool isActive(Map<String, dynamic> map) {
    return map['is_active'] == true || map['is_active'] == 1;
  }
}
