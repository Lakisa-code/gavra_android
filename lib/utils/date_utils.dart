/// 🎯 JEDINSTVENA LOGIKA ZA SVE SCREEN-OVE
///
/// Ova klasa sadrži centralnu logiku za rukovanje datumima
/// u celoj aplikaciji. Svi screen-ovi treba da koriste ove funkcije
/// umesto da implementiraju svoju logiku.
class DateUtils {
  /// 🎯 KONVERTER DANA: Pretvara broj dana u string
  static String weekdayToString(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'ponedeljak';
      case DateTime.tuesday:
        return 'utorak';
      case DateTime.wednesday:
        return 'sreda';
      case DateTime.thursday:
        return 'četvrtak';
      case DateTime.friday:
        return 'petak';
      case DateTime.saturday:
        return 'subota';
      case DateTime.sunday:
        return 'nedelja';
      default:
        return 'nepoznat';
    }
  }

  /// 🎯 ADMIN SCREEN HELPER: Vraća puni naziv dana za dropdown
  static String getTodayFullName([DateTime? inputDate]) {
    final today = inputDate ?? DateTime.now();
    final dayNames = [
      'Ponedeljak',
      'Utorak',
      'Sreda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedelja',
    ];

    final todayName = dayNames[today.weekday - 1];
    return todayName;
  }

  /// 🎯 DATUM RANGE GENERATOR: Kreiranje from/to datuma za query-je
  static Map<String, DateTime> getDateRange([DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();

    return {
      'from': DateTime(date.year, date.month, date.day),
      'to': DateTime(date.year, date.month, date.day, 23, 59, 59),
    };
  }
}
