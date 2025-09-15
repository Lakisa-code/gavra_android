/// Klasa za upravljanje sezonskim rasporedom autobusa
class SeasonalScheduleManager {
  /// Određuje da li je trenutno letnji period
  /// Letnji period: 1. jul - 31. avgust
  /// Zimski period: 1. septembar - 30. jun
  static bool isLetniPeriod([DateTime? datum]) {
    final date = datum ?? DateTime.now();
    final month = date.month;

    // Letnji period: jul (7) i avgust (8)
    return month >= 7 && month <= 8;
  }

  /// Vraća naziv trenutne sezone
  static String getCurrentSeasonName([DateTime? datum]) {
    return isLetniPeriod(datum) ? 'Letnji' : 'Zimski';
  }

  /// Vraća opis trenutnog perioda
  static String getCurrentPeriodDescription([DateTime? datum]) {
    if (isLetniPeriod(datum)) {
      return 'Letnji red vožnje (1. jul - 31. avgust)';
    } else {
      return 'Zimski red vožnje (1. septembar - 30. jun)';
    }
  }

  /// Vraća datum kada počinje sledeća sezona
  static DateTime getNextSeasonStartDate([DateTime? datum]) {
    final date = datum ?? DateTime.now();

    if (isLetniPeriod(date)) {
      // Trenutno je letnji period (jul-avgust), sledeći zimski počinje 1. septembra
      return DateTime(date.year, 9, 1);
    } else {
      // Trenutno je zimski period, sledeći letnji počinje 1. jula
      if (date.month >= 7) {
        // Već je prošao jul ove godine, sledeći jul je sledeće godine
        return DateTime(date.year + 1, 7, 1);
      } else {
        // Još uvek čekamo jul ove godine
        return DateTime(date.year, 7, 1);
      }
    }
  }

  /// Vraća broj dana do početka sledeće sezone
  static int getDaysUntilNextSeason([DateTime? datum]) {
    final date = datum ?? DateTime.now();
    final nextSeasonStart = getNextSeasonStartDate(date);
    return nextSeasonStart.difference(date).inDays;
  }

  /// Letnji polasci iz Bele Crkve
  static const List<String> letnjiBcPolasci = [
    '5:00',
    '6:00',
    '8:00',
    '10:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00'
  ];

  /// Zimski polasci iz Bele Crkve
  static const List<String> zimskiBcPolasci = [
    '5:00',
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00'
  ];

  /// Letnji polasci iz Vršca
  static const List<String> letnjiVsPolasci = [
    '6:00',
    '7:00',
    '9:00',
    '11:00',
    '13:00',
    '14:00',
    '15:30',
    '16:15',
    '19:00'
  ];

  /// Zimski polasci iz Vršca
  static const List<String> zimskiVsPolasci = [
    '6:00',
    '7:00',
    '8:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '17:00',
    '19:00'
  ];

  /// Vraća polazak za određeni grad i sezonu
  static List<String> getPolasciForGradAndSeason(String grad,
      [DateTime? datum]) {
    final isLetnji = isLetniPeriod(datum);

    if (grad.toLowerCase().contains('bela') ||
        grad.toLowerCase().contains('bc')) {
      return isLetnji ? letnjiBcPolasci : zimskiBcPolasci;
    } else if (grad.toLowerCase().contains('vršac') ||
        grad.toLowerCase().contains('vs')) {
      return isLetnji ? letnjiVsPolasci : zimskiVsPolasci;
    }

    // Default fallback
    return isLetnji ? letnjiBcPolasci : zimskiBcPolasci;
  }

  /// Vraća sve polazak za trenutnu sezonu
  static Map<String, List<String>> getAllPolasciForCurrentSeason(
      [DateTime? datum]) {
    return {
      'Bela Crkva': getPolasciForGradAndSeason('Bela Crkva', datum),
      'Vršac': getPolasciForGradAndSeason('Vršac', datum),
    };
  }
}
