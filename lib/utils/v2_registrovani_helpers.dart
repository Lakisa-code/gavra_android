import 'v2_grad_adresa_validator.dart';

enum V2RegistrovaniStatus { active, canceled, vacation, unknown }

class V2RegistrovaniHelpers {
  V2RegistrovaniHelpers._();

  // Normalize time using GradAdresaValidator for consistency across the app
  static String? normalizeTime(String? raw) {
    return GradAdresaValidator.normalizeTime(raw);
  }

  // SSOT: Polasci po danu se sada čuvaju ISKLJUČIVO u v2_polasci tabeli.
  // Ove metode su zadržane radi kompatibilnosti interfejsa.

  // Get polazak for a day and place ('bc' or 'vs') from v2_polasci
  static String? getPolazakForDay(
    Map<String, dynamic> rawMap,
    String dayKratica,
    String place, {
    bool isWinter = false,
  }) {
    if (rawMap.containsKey('zeljeno_vreme') && rawMap['zeljeno_vreme'] != null) {
      final gradRaw = rawMap['grad']?.toString();
      final matches = gradRaw?.toUpperCase() == place.toUpperCase();

      if (matches) {
        return normalizeTime(rawMap['zeljeno_vreme'].toString());
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
  static V2RegistrovaniStatus statusFromString(String? raw) {
    if (raw == null) return V2RegistrovaniStatus.unknown;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return V2RegistrovaniStatus.unknown;

    final map = {
      'otkazano': V2RegistrovaniStatus.canceled,
      'otkazan': V2RegistrovaniStatus.canceled,
      'otkazana': V2RegistrovaniStatus.canceled,
      'otkaz': V2RegistrovaniStatus.canceled,
      'godišnji': V2RegistrovaniStatus.vacation,
      'godisnji': V2RegistrovaniStatus.vacation,
      'godisnji_odmor': V2RegistrovaniStatus.vacation,
      'aktivan': V2RegistrovaniStatus.active,
      'active': V2RegistrovaniStatus.active,
      'placeno': V2RegistrovaniStatus.active,
    };
    for (final k in map.keys) {
      if (s.contains(k)) return map[k]!;
    }
    return V2RegistrovaniStatus.unknown;
  }
}
