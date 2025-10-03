import '../utils/logging.dart';

/// Servis za mapiranje imena vozača u UUID-ove i obrnuto
class VozacMappingService {
  /// Mapiranje imena vozača u UUID-ove
  static const Map<String, String> _vozacNameToUuid = {
    'Gavra': '11111111-1111-1111-1111-111111111111',
    'Jovica': '22222222-2222-2222-2222-222222222222',
    'Bojan': '33333333-3333-3333-3333-333333333333',
    'Stefan': '44444444-4444-4444-4444-444444444444',
    'Milan': '55555555-5555-5555-5555-555555555555',
    'Marko': '66666666-6666-6666-6666-666666666666',
    'Nikola': '77777777-7777-7777-7777-777777777777',
    'Petar': '88888888-8888-8888-8888-888888888888',
    'Aleksandar': '99999999-9999-9999-9999-999999999999',
    'Miloš': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  };

  /// Obrnuto mapiranje UUID-ova u imena vozača
  static final Map<String, String> _vozacUuidToName = {
    for (var entry in _vozacNameToUuid.entries) entry.value: entry.key
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