import 'vozac_service.dart';

/// Servis za mapiranje imena vozača u UUID-ove i obrnuto
class VozacMappingService {
  static final VozacService _vozacService = VozacService();

  /// Cache za mapiranje imena vozača u UUID-ove
  static Map<String, String>? _vozacNameToUuid;
  static Map<String, String>? _vozacUuidToName;
  static DateTime? _lastCacheUpdate;
  static bool _isInitialized = false;

  /// Cache validity period (30 minutes)
  static const Duration _cacheValidityPeriod = Duration(minutes: 30);

  /// 🚀 INICIJALIZACIJA CACHE-A NA STARTUP
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _loadMappingFromDatabase();
      _isInitialized = true;
      print('✅ VozacMappingService inicijalizovan uspešno');
    } catch (e) {
      print('❌ Greška pri inicijalizaciji VozacMappingService: $e');
      // Postavi prazan cache da ne crashuje aplikaciju
      _vozacNameToUuid = {};
      _vozacUuidToName = {};
      _isInitialized = true;
    }
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

        // Dodaj i puno ime
        _vozacNameToUuid![vozac.punoIme] = vozac.id;
      }

      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      // Database connection failed - initialize empty cache
      // This will force retry on next access
      _vozacNameToUuid = {};
      _vozacUuidToName = {};
      _lastCacheUpdate = null; // Force refresh on next call
      rethrow; // Propagate error to caller
    }
  }

  /// Proverava da li je cache valjan
  static bool _isCacheValid() {
    if (_lastCacheUpdate == null || _vozacNameToUuid == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(_lastCacheUpdate!) < _cacheValidityPeriod;
  }

  /// Osigurava da je mapiranje učitano i validno
  static Future<void> _ensureMappingLoaded() async {
    if (!_isCacheValid()) {
      await _loadMappingFromDatabase();
    }
  }

  /// Dobij UUID vozača na osnovu imena
  static Future<String?> getVozacUuid(String ime) async {
    await _ensureMappingLoaded();
    return _vozacNameToUuid?[ime];
  }

  /// Dobij ime vozača na osnovu UUID-a
  static Future<String?> getVozacIme(String uuid) async {
    await _ensureMappingLoaded();
    return _vozacUuidToName?[uuid];
  }

  /// Dobij ime vozača sa fallback na null (trebalo bi da se koristi samo u debug slučajevima)
  static Future<String?> getVozacImeWithFallback(String? uuid) async {
    if (uuid == null || uuid.isEmpty) {
      return null; // Ne vraćaj 'Nepoznat', već null
    }
    return await getVozacIme(uuid); // Može biti null
  }

  /// Provjeri da li je ime vozača validno
  static Future<bool> isValidVozacIme(String ime) async {
    await _ensureMappingLoaded();
    return _vozacNameToUuid?.containsKey(ime) ?? false;
  }

  /// Provjeri da li je UUID vozača validan
  static Future<bool> isValidVozacUuid(String uuid) async {
    await _ensureMappingLoaded();
    return _vozacUuidToName?.containsKey(uuid) ?? false;
  }

  /// Dobij listu svih imena vozača
  static Future<List<String>> getAllVozacNames() async {
    await _ensureMappingLoaded();
    return _vozacNameToUuid?.keys.toList() ?? [];
  }

  /// Dobij listu svih UUID-ova vozača
  static Future<List<String>> getAllVozacUuids() async {
    await _ensureMappingLoaded();
    return _vozacNameToUuid?.values.toList() ?? [];
  }

  /// Forsira ponovno učitavanje mapiranja iz baze
  static Future<void> refreshMapping() async {
    _lastCacheUpdate = null;
    await _ensureMappingLoaded();
  }

  // KOMPATIBILNOST: Sinhrone metode za modele i mesta gde async nije moguć
  // Ove metode koriste cache ako je dostupan, inače fallback

  /// Dobij ime vozača sa fallback sinhron (koristi cache ili null)
  static String? getVozacImeWithFallbackSync(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;

    // ⚠️ WARN: Ako cache nije učitan, vrati null umesto crash
    if (!_isInitialized || _vozacUuidToName == null) {
      print('⚠️ WARNING: VozacMappingService cache nije inicijalizovan! Pozovi initialize() na startup.');
      return null;
    }

    return _vozacUuidToName?[uuid]; // Može biti null
  }

  /// Dobij UUID vozača sinhron (koristi cache ili null)
  static String? getVozacUuidSync(String ime) {
    if (!_isInitialized || _vozacNameToUuid == null) {
      print('⚠️ WARNING: VozacMappingService cache nije inicijalizovan! Pozovi initialize() na startup.');
      return null;
    }
    return _vozacNameToUuid?[ime];
  }

  /// Proveri da li je UUID vozača valjan sinhron
  static bool isValidVozacUuidSync(String uuid) {
    if (!_isInitialized || _vozacUuidToName == null) {
      print('⚠️ WARNING: VozacMappingService cache nije inicijalizovan!');
      return false;
    }
    return _vozacUuidToName?.containsKey(uuid) ?? false;
  }

  /// 🔄 CROSS-VALIDATION: Proveri da li se VozacBoja i VozacMappingService slažu
  static Future<Map<String, dynamic>> validateConsistency() async {
    await _ensureMappingLoaded();

    final errors = <String>[];
    final warnings = <String>[];

    // Import VozacBoja da pristupimo validDrivers
    final hardcodedDrivers = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana']; // VozacBoja.validDrivers
    final dynamicDrivers = _vozacNameToUuid?.keys.toList() ?? [];

    // Proveri da li svi hardcoded vozači postoje u bazi
    for (final driver in hardcodedDrivers) {
      if (!dynamicDrivers.contains(driver)) {
        errors.add('Vozač "$driver" postoji u VozacBoja ali ne u bazi!');
      }
    }

    // Proveri da li u bazi postoje vozači koji nisu u VozacBoja
    for (final driver in dynamicDrivers) {
      if (!hardcodedDrivers.contains(driver)) {
        warnings.add('Vozač "$driver" postoji u bazi ali ne u VozacBoja!');
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'hardcodedDrivers': hardcodedDrivers,
      'dynamicDrivers': dynamicDrivers,
    };
  }
}
