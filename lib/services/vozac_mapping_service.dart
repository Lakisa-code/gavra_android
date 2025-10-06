import '../utils/logging.dart';

/// Servis za mapiranje imena vozača u UUID-ove i obrnuto
class VozacMappingService {
  /// Mapiranje imena vozača u UUID-ove - STVARNI VOZAČI APLIKACIJE
  static const Map<String, String> _vozacNameToUuid = {
    'Bilevski': '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
    'Bruda': '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f',
    'Bojan': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
    'Svetlana': '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
  };

  /// Obrnuto mapiranje UUID-ova u imena vozača
  static final Map<String, String> _vozacUuidToName = {
    for (var entry in _vozacNameToUuid.entries) entry.value: entry.key,
  };

  /// Dobij UUID vozača na osnovu imena
  static String? getVozacUuid(String ime) {
    final uuid = _vozacNameToUuid[ime];
    if (uuid == null) {
      dlog('⚠️ [VOZAC MAPPING] Nepoznato ime vozača: $ime');
    }
    return uuid;
  }

  /// Dobij ime vozača na osnovu UUID-a
  static String? getVozacIme(String uuid) {
    final ime = _vozacUuidToName[uuid];
    if (ime == null) {
      dlog('⚠️ [VOZAC MAPPING] Nepoznat UUID vozača: $uuid');
    }
    return ime;
  }

  /// Dobij ime vozača sa fallback na 'Nepoznat'
  static String getVozacImeWithFallback(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return 'Nepoznat';
    }
    return getVozacIme(uuid) ?? 'Nepoznat';
  }

  /// Provjeri da li je ime vozača validno
  static bool isValidVozacIme(String ime) {
    return _vozacNameToUuid.containsKey(ime);
  }

  /// Provjeri da li je UUID vozača validan
  static bool isValidVozacUuid(String uuid) {
    return _vozacUuidToName.containsKey(uuid);
  }

  /// Dobij listu svih imena vozača
  static List<String> getAllVozacNames() {
    return _vozacNameToUuid.keys.toList();
  }

  /// Dobij listu svih UUID-ova vozača
  static List<String> getAllVozacUuids() {
    return _vozacNameToUuid.values.toList();
  }

  /// Debug funkcija za ispis mapiranja
  static void printMapping() {
    dlog('🚗 [VOZAC MAPPING] Imena -> UUID:');
    _vozacNameToUuid.forEach((ime, uuid) {
      dlog('  $ime -> $uuid');
    });
  }
}
