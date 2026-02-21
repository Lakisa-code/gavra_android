import '../utils/vozac_cache.dart';

/// VozacMappingService — backwards-compat wrapper oko VozacCache.
///
/// Novi kod treba koristiti VozacCache direktno.
@Deprecated('Koristiti VozacCache')
class VozacMappingService {
  static bool get isInitialized => VozacCache.isInitialized;

  static Future<void> initialize() => VozacCache.initialize();
  static Future<void> refreshMapping() => VozacCache.refresh();

  static String? getVozacColorSync(String? uuid) {
    final v = VozacCache.getVozacByUuid(uuid);
    return v?.boja;
  }

  static Future<String?> getVozacUuid(String ime) => VozacCache.getUuidByImeAsync(ime);

  static Future<String?> getVozacIme(String uuid) => VozacCache.getImeByUuidAsync(uuid);

  static Future<String?> getVozacImeWithFallback(String? uuid) =>
      VozacCache.getImeByUuidAsync(uuid);

  static String? getVozacImeWithFallbackSync(String? uuid) => VozacCache.getImeByUuid(uuid);

  static String? getVozacUuidSync(String? ime) => VozacCache.getUuidByIme(ime);

  static String? getNameFromUuidOrNameSync(String? input) => VozacCache.resolveIme(input);

  static bool isValidVozacUuidSync(String uuid) => VozacCache.isValidUuid(uuid);
}
