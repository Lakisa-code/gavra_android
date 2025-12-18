/// JEDINSTVENA LOGIKA ZA SVE SCREEN-OVE
///
/// Ova klasa sadrži centralnu logiku za rukovanje datumima
/// u celoj aplikaciji. Svi screen-ovi treba da koriste ove funkcije
/// umesto da implementiraju svoju logiku.
class DateUtils {
  /// KONVERTER DANA: Pretvara broj dana u string
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

  /// CENTRALNA FUNKCIJA: Konvertuj pun naziv dana u kraticu (pon, uto, sre, cet, pet, sub, ned)
  /// Podržava sve varijante: sa/bez dijakritika, uppercase/lowercase
  static String getDayAbbreviation(String fullDayName) {
    // Normalizuj: lowercase i zameni dijakritike
    final normalized =
        fullDayName.toLowerCase().replaceAll('č', 'c').replaceAll('ć', 'c').replaceAll('š', 's').replaceAll('ž', 'z');

    switch (normalized) {
      case 'ponedeljak':
      case 'pon':
        return 'pon';
      case 'utorak':
      case 'uto':
        return 'uto';
      case 'sreda':
      case 'sre':
        return 'sre';
      case 'cetvrtak':
      case 'cet':
        return 'cet';
      case 'petak':
      case 'pet':
        return 'pet';
      case 'subota':
      case 'sub':
        return 'sub';
      case 'nedelja':
      case 'ned':
        return 'ned';
      default:
        // Ako je već kratica ili nepoznat format, vrati lowercase
        return fullDayName.toLowerCase().substring(0, fullDayName.length >= 3 ? 3 : fullDayName.length);
    }
  }

  /// CENTRALNA FUNKCIJA: Konvertuj pun naziv dana u weekday broj (1=Pon, 2=Uto, ...)
  /// Podržava sve varijante: sa/bez dijakritika, uppercase/lowercase
  static int getDayWeekdayNumber(String fullDayName) {
    final abbr = getDayAbbreviation(fullDayName);
    switch (abbr) {
      case 'pon':
        return 1;
      case 'uto':
        return 2;
      case 'sre':
        return 3;
      case 'cet':
        return 4;
      case 'pet':
        return 5;
      case 'sub':
        return 6;
      case 'ned':
        return 7;
      default:
        return DateTime.now().weekday; // Fallback na današnji dan
    }
  }

  /// ADMIN SCREEN HELPER: Vraća puni naziv dana za dropdown
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

  /// DATUM RANGE GENERATOR: Kreiranje from/to datuma za query-je
  static Map<String, DateTime> getDateRange([DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();

    return {
      'from': DateTime(date.year, date.month, date.day),
      'to': DateTime(date.year, date.month, date.day, 23, 59, 59),
    };
  }
}
