import '../utils/logging.dart';
import 'vozac_service.dart';

/// Servis za mapiranje imena vozača u UUID-ove i obrnuto
class VozacMappingService {
  static final VozacService _vozacService = VozacService();

  /// Cache za mapiranje imena vozača u UUID-ove
  static Map<String, String>? _vozacNameToUuid;
  static Map<String, String>? _vozacUuidToName;
  static DateTime? _lastCacheUpdate;

  /// Cache validity period (30 minutes)
  static const Duration _cacheValidityPeriod = Duration(minutes: 30);

  /// Fallback mapiranje za kompatibilnost sa starim kodom
  /// NAPOMENA: Ovo će biti uklonjen kada se svi vozači dodaju u bazu
  static const Map<String, String> _fallbackMapping = {
    'Bilevski': '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
    'Bruda': '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f',
    'Bojan': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
    'Svetlana': '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
  };

  /// Učitava mapiranje vozača iz baze podataka
  static Future<void> _loadMappingFromDatabase() async {
    try {
      dlog('🔄 [VOZAC MAPPING] Učitavam vozače iz baze...');
      final vozaci = await _vozacService.getAllVozaci();

      _vozacNameToUuid = {};
      _vozacUuidToName = {};

      for (var vozac in vozaci) {
        _vozacNameToUuid![vozac.ime] = vozac.id;
        _vozacUuidToName![vozac.id] = vozac.ime;

        // Dodaj i puno ime ako postoji prezime
        if (vozac.prezime != null && vozac.prezime!.isNotEmpty) {
          _vozacNameToUuid![vozac.punoIme] = vozac.id;
        }
      }

      _lastCacheUpdate = DateTime.now();
      dlog('✅ [VOZAC MAPPING] Učitano ${vozaci.length} vozača iz baze');
    } catch (e) {
      dlog('❌ [VOZAC MAPPING] Greška pri učitavanju iz baze: $e');
      // Fallback na hardkodovano mapiranje
      _vozacNameToUuid = Map.from(_fallbackMapping);
      _vozacUuidToName = {
        for (var entry in _fallbackMapping.entries) entry.value: entry.key,
      };
      _lastCacheUpdate = DateTime.now();
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
    final uuid = _vozacNameToUuid?[ime];
    if (uuid == null) {
      dlog('⚠️ [VOZAC MAPPING] Nepoznato ime vozača: $ime');
    }
    return uuid;
  }

  /// Dobij ime vozača na osnovu UUID-a
  static Future<String?> getVozacIme(String uuid) async {
    await _ensureMappingLoaded();
    final ime = _vozacUuidToName?[uuid];
    if (ime == null) {
      dlog('⚠️ [VOZAC MAPPING] Nepoznat UUID vozača: $uuid');
    }
    return ime;
  }

  /// Dobij ime vozača sa fallback na 'Nepoznat'
  static Future<String> getVozacImeWithFallback(String? uuid) async {
    if (uuid == null || uuid.isEmpty) {
      return 'Nepoznat';
    }
    return await getVozacIme(uuid) ?? 'Nepoznat';
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

  /// Debug funkcija za ispis mapiranja
  static Future<void> printMapping() async {
    await _ensureMappingLoaded();
    dlog('🚗 [VOZAC MAPPING] Imena -> UUID:');
    _vozacNameToUuid?.forEach((ime, uuid) {
      dlog('  $ime -> $uuid');
    });
  }

  // KOMPATIBILNOST: Sinhrone metode za modele i mesta gde async nije moguć
  // Ove metode koriste cache ako je dostupan, inače fallback

  /// Dobij UUID vozača sinhron (koristi cache ili fallback)
  static String? getVozacUuidSync(String ime) {
    return _vozacNameToUuid?[ime] ?? _fallbackMapping[ime];
  }

  /// Dobij ime vozača sa fallback sinhron (koristi cache ili fallback)
  static String getVozacImeWithFallbackSync(String? uuid) {
    if (uuid == null || uuid.isEmpty) return 'Nepoznat';

    final fallbackUuidToName = {
      for (var entry in _fallbackMapping.entries) entry.value: entry.key,
    };

    return _vozacUuidToName?[uuid] ?? fallbackUuidToName[uuid] ?? 'Nepoznat';
  }

  /// Proveri da li je UUID vozača valjan sinhron
  static bool isValidVozacUuidSync(String uuid) {
    return _vozacUuidToName?.containsKey(uuid) ??
        _fallbackMapping.containsValue(uuid);
  }
}
