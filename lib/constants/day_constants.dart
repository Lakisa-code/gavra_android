/// 🌍 GLOBALNA REŠENJA ZA DANE - KORISTI SAMO OVO FILE-A
/// ⚠️ VAŽNO: Sve vrednosti su BEZ DIJAKRITIKA (cetvrtak, ne četvrtak)
/// To osigurava kompatibilnost sa svim dropdownima i bazom
library;

class DayConstants {
  // 📅 PUNI NAZIVI DANA - INTERNAL (bez dijakritika)
  static const List<String> dayNamesInternal = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Cetvrtak',
    'Petak',
  ];

  // 🎨 PUNI NAZIVI DANA - UI (sa dijakritikom za prikaz)
  static const List<String> dayNamesUI = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Četvrtak',
    'Petak',
  ];

  // 📝 KRATICE DANA
  static const List<String> dayAbbreviations = [
    'pon',
    'uto',
    'sre',
    'cet',
    'pet',
  ];

  // 🔤 MALA SLOVA DANA
  static const List<String> dayNamesLowercase = [
    'ponedeljak',
    'utorak',
    'sreda',
    'cetvrtak',
    'petak',
  ];

  /// Konvertuj bilo koji format dana u standardni INTERNAL format (bez dijakritika)
  static String normalize(String dayName) {
    final normalized = dayName
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .trim();

    // Pronađi u listi
    for (int i = 0; i < dayNamesLowercase.length; i++) {
      if (dayNamesLowercase[i] == normalized || dayAbbreviations[i] == normalized) {
        return dayNamesInternal[i];
      }
    }

    // Ako nije pronađen, vrati originalni
    return dayName;
  }

  /// Dobij index dana (0=Ponedeljak, ..., 6=Nedelja)
  static int getIndexByName(String dayName) {
    final normalized = normalize(dayName).toLowerCase();
    for (int i = 0; i < dayNamesLowercase.length; i++) {
      if (dayNamesLowercase[i] == normalized) {
        return i;
      }
    }
    return 0; // Fallback
  }

  /// Dobij puni INTERNAL naziv po indexu
  static String getNameByIndex(int index) {
    if (index < 0 || index >= dayNamesInternal.length) {
      return dayNamesInternal[0];
    }
    return dayNamesInternal[index];
  }

  /// Dobij kraticu po indexu
  static String getAbbreviationByIndex(int index) {
    if (index < 0 || index >= dayAbbreviations.length) {
      return dayAbbreviations[0];
    }
    return dayAbbreviations[index];
  }

  /// Konvertuj DateTime.weekday (1=Monday) na naš index (0=Ponedeljak)
  static int weekdayToIndex(int weekday) {
    // 🛡️ Rezilijentnost na vikend: Subota/Nedelja -> Ponedeljak
    if (weekday > 5) return 0;
    return weekday - 1;
  }

  /// Konvertuj naš index (0=Ponedeljak) na DateTime.weekday (1=Monday)
  static int indexToWeekday(int index) {
    // 🛡️ Ne dozvoljavamo index van opsega radnih dana (0-4)
    if (index > 4) return 1;
    return index + 1;
  }
}
