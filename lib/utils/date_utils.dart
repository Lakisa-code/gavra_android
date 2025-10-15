/// 🎯 JEDINSTVENA VIKEND LOGIKA ZA SVE SCREEN-OVE
///
/// Ova klasa sadrži centralnu logiku za rukovanje vikend datumima
/// u celoj aplikaciji. Svi screen-ovi treba da koriste ove funkcije
/// umesto da implementiraju svoju logiku.
class DateUtils {
  /// 🎯 GLAVNA FUNKCIJA: Vraća target datum za vikend/radni dan
  ///
  /// - Tokom vikenda (subota/nedelja): vraća datum SLEDEĆEG ponedeljka
  /// - Tokom radnih dana: vraća današnji datum
  ///
  /// Ova logika se koristi za:
  /// - Admin screen kada je selektovan "Ponedeljak"
  /// - Danas screen za prikaz putnika
  /// - Home screen za filtriranje
  /// - Svi ostali screen-ovi koji rade sa "danas" konceptom
  static DateTime getWeekendTargetDate([DateTime? inputDate]) {
    final today = inputDate ?? DateTime.now();

    if (today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday) {
      // Vikend: traži ponedeljak koji sledi
      final daysUntilMonday = 8 - today.weekday;
      final targetDate = today.add(Duration(days: daysUntilMonday));

      return targetDate;
    } else {
      // Radni dan: koristi današnji datum
      return today;
    }
  }

  /// 🎯 VIKEND PROVERAVAČ: Da li je danas vikend
  static bool isWeekend([DateTime? inputDate]) {
    final today = inputDate ?? DateTime.now();
    return today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday;
  }

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

    // Ako je vikend (subota/nedelja), vraćamo ponedeljak
    if (isWeekend(today)) {
      return 'Ponedeljak';
    }

    final todayName = dayNames[today.weekday - 1];
    return todayName;
  }

  /// 🎯 DATUM RANGE GENERATOR: Kreiranje from/to datuma za query-je
  static Map<String, DateTime> getDateRange([DateTime? targetDate]) {
    final date = targetDate ?? getWeekendTargetDate();

    return {
      'from': DateTime(date.year, date.month, date.day),
      'to': DateTime(date.year, date.month, date.day, 23, 59, 59),
    };
  }
}




