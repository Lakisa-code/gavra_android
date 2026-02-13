import 'vozac_service.dart';

/// Servis za mapiranje imena vozača u UUID-ove i obrnuto
class VozacMappingService {
  static final VozacService _vozacService = VozacService();

  static Map<String, String>? _vozacNameToUuid;
  static Map<String, String>? _vozacUuidToName;
  static bool _isInitialized = false;

  // Expose status
  static bool get isInitialized => _isInitialized;

  /// 🚀 INICIJALIZACIJA NA STARTUP
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _loadMappingFromDatabase();
      _isInitialized = true;
    } catch (e) {
      _vozacNameToUuid = {};
      _vozacUuidToName = {};
      _isInitialized = true;
    }
  }

  /// Osveži mapiranje vozača
  static Future<void> refreshMapping() async {
    await _loadMappingFromDatabase();
  }

  /// Učitava mapiranje vozača iz baze podataka
  static Future<void> _loadMappingFromDatabase() async {
    try {
      final vozaci = await _vozacService.getAllVozaci();

      _vozacNameToUuid = {};
      _vozacUuidToName = {};

      for (var vozac in vozaci) {
        _vozacNameToUuid![vozac.ime] = vozac.id;
        _vozacUuidToName![vozac.id] = vozac.ime;

        _vozacNameToUuid![vozac.punoIme] = vozac.id;
      }
    } catch (e) {
      _vozacNameToUuid = {};
      _vozacUuidToName = {};
      rethrow;
    }
  }

  /// Dobij UUID vozača na osnovu imena
  static Future<String?> getVozacUuid(String ime) async {
    if (_vozacNameToUuid == null) {
      await _loadMappingFromDatabase();
    }
    return _vozacNameToUuid?[ime];
  }

  /// Dobij ime vozača na osnovu UUID-a
  static Future<String?> getVozacIme(String uuid) async {
    await initialize();
    return _vozacUuidToName?[uuid];
  }

  /// Dobij ime vozača sa fallback na null (trebalo bi da se koristi samo u debug slučajevima)
  static Future<String?> getVozacImeWithFallback(String? uuid) async {
    if (uuid == null || uuid.isEmpty) {
      return null; // Vrati null umesto fallback stringa
    }
    return await getVozacIme(uuid); // Može biti null
  }

  // KOMPATIBILNOST: Sinhrone metode za modele i mesta gde async nije moguć

  /// Dobij ime vozača sa fallback sinhron
  static String? getVozacImeWithFallbackSync(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;

    if (!_isInitialized || _vozacUuidToName == null) {
      return null;
    }

    return _vozacUuidToName?[uuid]; // Može biti null
  }

  /// Dobij UUID vozača sinhron
  static String? getVozacUuidSync(String ime) {
    if (!_isInitialized || _vozacNameToUuid == null) {
      return null;
    }
    return _vozacNameToUuid?[ime];
  }

  /// 🆕 Pomoćna metoda: Ako je string UUID, vrati ime. Ako nije UUID (već je ime), vrati taj isti string.
  static String getNameFromUuidOrNameSync(String input) {
    if (input.isEmpty) return input;

    // Proveri da li je input validan UUID format (8-4-4-4-12)
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    if (!uuidRegex.hasMatch(input)) {
      return input; // Nije UUID, verovatno je vec ime
    }

    // Jeste UUID format, pokušaj konverziju
    return getVozacImeWithFallbackSync(input) ?? input;
  }

  /// Proveri da li je UUID vozača valjan sinhron
  static bool isValidVozacUuidSync(String uuid) {
    if (!_isInitialized || _vozacUuidToName == null) {
      return false;
    }
    return _vozacUuidToName?.containsKey(uuid) ?? false;
  }
}
