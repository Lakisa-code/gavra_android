import '../utils/logging.dart';

/// 🔐 ADMIN SECURITY SERVICE
/// Centralizovani servis za upravljanje admin privilegijama
/// Zamenjuje hard-coded admin logiku sa sigurnijim pristupom
class AdminSecurityService {
  // 🔐 SECURE ADMIN LIST - trebalo bi da bude iz backend-a ili encrypted config
  static const Set<String> _adminUsers = {
    'Bojan',
    'Svetlana',
  };

  /// 🔍 Proveri da li je vozač admin
  static bool isAdmin(String? driverName) {
    if (driverName == null || driverName.isEmpty) {
      dlog('⚠️ AdminSecurityService: Driver name is null or empty');
      return false;
    }

    final isAdminUser = _adminUsers.contains(driverName);
    dlog('🔐 AdminSecurityService: Driver "$driverName" admin status: $isAdminUser');
    return isAdminUser;
  }

  /// 🛡️ Proveri da li vozač može da vidi podatke drugog vozača
  static bool canViewDriverData(String? currentDriver, String targetDriver) {
    if (currentDriver == null || currentDriver.isEmpty) {
      return false;
    }

    // Admin može da vidi sve podatke
    if (isAdmin(currentDriver)) {
      return true;
    }

    // Vozač može da vidi samo svoje podatke
    return currentDriver == targetDriver;
  }

  /// 🔒 Filtriraj pazar podatke na osnovu privilegija
  static Map<String, double> filterPazarByPrivileges(
    String? currentDriver,
    Map<String, double> pazarData,
  ) {
    if (currentDriver == null || currentDriver.isEmpty) {
      return {};
    }

    // Admin vidi sve vozače
    if (isAdmin(currentDriver)) {
      return Map.from(pazarData);
    }

    // Vozač vidi samo svoj pazar
    return {
      if (pazarData.containsKey(currentDriver)) currentDriver: pazarData[currentDriver]!,
    };
  }

  /// 🎯 Dobij vozače koji treba da se prikažu na osnovu privilegija
  static List<String> getVisibleDrivers(
    String? currentDriver,
    List<String> allDrivers,
  ) {
    if (currentDriver == null || currentDriver.isEmpty) {
      return [];
    }

    // Admin vidi sve vozače
    if (isAdmin(currentDriver)) {
      return List.from(allDrivers);
    }

    // Vozač vidi samo sebe
    return allDrivers.where((driver) => driver == currentDriver).toList();
  }

  /// 📊 Generiši naslov na osnovu privilegija
  static String generateTitle(String? currentDriver, String baseTitle) {
    if (currentDriver == null || currentDriver.isEmpty) {
      return baseTitle;
    }

    if (isAdmin(currentDriver)) {
      return baseTitle; // Admin vidi standardni naslov
    }

    return 'Moj $baseTitle'; // Vozač vidi personalizovani naslov
  }
}
