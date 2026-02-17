import '../constants/day_constants.dart';

/// JEDINSTVENA LOGIKA ZA SVE SCREEN-OVE
///
/// Ova klasa sadrži centralnu logiku za rukovanje datumima
/// u celoj aplikaciji. Svi screen-ovi treba da koriste ove funkcije
/// umesto da implementiraju svoju logiku.
class DateUtils {
  /// KONVERTER DANA: Pretvara broj dana u string
  static String weekdayToString(int weekday) {
    return DayConstants.dayNamesLowercase[DayConstants.weekdayToIndex(weekday)];
  }

  /// CENTRALNA FUNKCIJA: Konvertuj pun naziv dana u kraticu (pon, uto, sre, cet, pet, sub, ned)
  /// Podržava sve varijante: sa/bez dijakritika, uppercase/lowercase
  static String getDayAbbreviation(String fullDayName) {
    final normalized = DayConstants.normalize(fullDayName).toLowerCase();
    return DayConstants
        .dayAbbreviations[DayConstants.getIndexByName(normalized)];
  }

  /// CENTRALNA FUNKCIJA: Konvertuj pun naziv dana u weekday broj (1=Pon, 2=Uto, ...)
  /// Podržava sve varijante: sa/bez dijakritika, uppercase/lowercase
  static int getDayWeekdayNumber(String fullDayName) {
    final index = DayConstants.getIndexByName(fullDayName);
    return DayConstants.indexToWeekday(index);
  }

  /// ADMIN SCREEN HELPER: Vraća puni naziv dana za dropdown
  static String getTodayFullName([DateTime? inputDate]) {
    final today = inputDate ?? DateTime.now();
    final index = DayConstants.weekdayToIndex(today.weekday);
    return DayConstants.dayNamesInternal[index];
  }

  /// DATUM RANGE GENERATOR: Kreiranje from/to datuma za query-je
  static Map<String, DateTime> getDateRange([DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();

    return {
      'from': DateTime(date.year, date.month, date.day),
      'to': DateTime(date.year, date.month, date.day, 23, 59, 59),
    };
  }

  /// CENTRALNA FUNKCIJA: Konvertuj pun naziv dana u ISO datum string
  /// Uvek ide u budućnost - ako je dan prošao ove nedelje, koristi sledeću nedelju
  /// Podržava sve varijante: pune nazive, kratice, sa/bez dijakritika
  static String getIsoDateForDay(String fullDay, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();

    // Koristi getDayWeekdayNumber za konverziju (1=Pon, 7=Ned)
    final targetWeekday = getDayWeekdayNumber(fullDay);
    final currentWeekday = now.weekday;

    // Ako je odabrani dan isto što i današnji dan, koristi današnji datum
    if (targetWeekday == currentWeekday) {
      return now.toIso8601String().split('T')[0];
    }

    int daysToAdd = targetWeekday - currentWeekday;

    // UVEK U BUDUĆNOST: Ako je dan već prošao ove nedelje, idi na sledeću nedelju
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }

    final targetDate = now.add(Duration(days: daysToAdd));
    return targetDate.toIso8601String().split('T')[0];
  }
}
