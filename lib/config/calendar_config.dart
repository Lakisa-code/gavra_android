/// 📅 Calendar Configuration
///
/// Državni praznici, školski raspusti i posebni dani za Srbiju.
/// Koristi se u ML predviđanjima i smart notifikacijama.

class CalendarConfig {
  // 🇷🇸 Državni praznici Srbije (neradni dani)
  static final Map<String, String> drzavniPraznici = {
    // Januar
    '2026-01-01': 'Nova godina - 1. dan',
    '2026-01-02': 'Nova godina - 2. dan',
    '2026-01-07': 'Božić (pravoslavni)',

    // Februar
    '2026-02-15': 'Dan državnosti - 1. dan',
    '2026-02-16': 'Dan državnosti - 2. dan',

    // April (Uskrs - promenljiv datum)
    '2026-04-17': 'Veliki petak',
    '2026-04-18': 'Velika subota',
    '2026-04-19': 'Uskrs (pravoslavni)',
    '2026-04-20': 'Uskršnji ponedeljak',

    // Maj
    '2026-05-01': 'Praznik rada - 1. dan',
    '2026-05-02': 'Praznik rada - 2. dan',
    '2026-05-09': 'Dan pobede',

    // Novembar
    '2026-11-11': 'Dan primirja',
  };

  // 📚 Školski raspust (približni datumi - proveriti sa lokalnim školama)
  static final Map<String, String> skolskiRaspust = {
    // Zimski raspust (Nova godina)
    '2025-12-29': 'Zimski raspust - početak',
    '2026-01-05': 'Zimski raspust - kraj',

    // Prolećni raspust (Uskrs)
    '2026-04-13': 'Prolećni raspust - početak',
    '2026-04-24': 'Prolećni raspust - kraj',

    // Letnji raspust
    '2026-06-15': 'Letnji raspust - početak',
    '2026-08-31': 'Letnji raspust - kraj',

    // Jesenji raspust
    '2026-11-02': 'Jesenji raspust - početak',
    '2026-11-09': 'Jesenji raspust - kraj',
  };

  // 🎓 Bitni školski datumi
  static final Map<String, String> skolskiDogadjaji = {
    // Prvi i poslednji dan škole
    '2025-09-01': 'Prvi dan škole',
    '2026-06-12': 'Poslednji dan škole / Četvrti klasifikacioni period',

    // Maturu i ispiti
    '2026-06-01': 'Početak mature',
    '2026-06-10': 'Kraj mature',

    // Klasifikacioni periodi
    '2025-11-30': 'Prvi klasifikacioni period',
    '2026-01-31': 'Drugi klasifikacioni period',
    '2026-04-30': 'Treći klasifikacioni period',
  }; // 🚫 Dani kada NE VOZE kombiji (customize per potrebi)
  static final List<String> neradniDaniKombija = [
    '2026-01-01', // Nova godina
    '2026-01-02',
    '2026-01-07', // Božić
    '2026-04-19', // Uskrs
    '2026-04-20',
    '2026-05-01', // Praznik rada
    '2026-05-02',
  ];

  /// Provera da li je datum državni praznik
  static bool isPraznik(DateTime date) {
    final key = _formatDate(date);
    return drzavniPraznici.containsKey(key);
  }

  /// Provera da li je datum u školskom raspustu
  static bool isSkolskiRaspust(DateTime date) {
    // Proveri da li je datum između početka i kraja nekog raspusta
    final raspustPeriods = _getRaspustPeriods();
    for (final period in raspustPeriods) {
      if (date.isAfter(period.start.subtract(const Duration(days: 1))) &&
          date.isBefore(period.end.add(const Duration(days: 1)))) {
        return true;
      }
    }
    return false;
  }

  /// Provera da li kombiji voze tog dana
  static bool kombijNijeRadanDan(DateTime date) {
    final key = _formatDate(date);
    return neradniDaniKombija.contains(key);
  }

  /// Dobavi opis praznika ili događaja
  static String? getOpis(DateTime date) {
    final key = _formatDate(date);
    return drzavniPraznici[key] ?? skolskiRaspust[key] ?? skolskiDogadjaji[key];
  }

  /// Provera da li je poseban dan (prvi dan škole, matura, itd.)
  static bool isPosebanDan(DateTime date) {
    final key = _formatDate(date);
    return skolskiDogadjaji.containsKey(key);
  }

  /// Broj dana do sledećeg praznika
  static int daysUntilNextPraznik(DateTime from) {
    final sortedPraznici = drzavniPraznici.keys.map((k) => DateTime.parse(k)).where((d) => d.isAfter(from)).toList()
      ..sort();

    if (sortedPraznici.isEmpty) return 999; // Nema praznika u bliskoj budućnosti

    return sortedPraznici.first.difference(from).inDays;
  }

  /// Broj dana od početka trenutnog raspusta (0 ako nije raspust)
  static int daysSinceRaspustStart(DateTime date) {
    final raspustPeriods = _getRaspustPeriods();
    for (final period in raspustPeriods) {
      if (date.isAfter(period.start.subtract(const Duration(days: 1))) &&
          date.isBefore(period.end.add(const Duration(days: 1)))) {
        return date.difference(period.start).inDays;
      }
    }
    return 0;
  }

  /// Sledeći praznik (datum i naziv)
  static MapEntry<DateTime, String>? getNextPraznik(DateTime from) {
    final sortedPraznici = drzavniPraznici.entries
        .map((e) => MapEntry(DateTime.parse(e.key), e.value))
        .where((e) => e.key.isAfter(from))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedPraznici.isNotEmpty ? sortedPraznici.first : null;
  }

  /// Sledeći školski raspust
  static MapEntry<DateTime, String>? getNextRaspust(DateTime from) {
    final raspustStarts = skolskiRaspust.entries
        .where((e) => e.value.contains('početak'))
        .map((e) => MapEntry(DateTime.parse(e.key), e.value))
        .where((e) => e.key.isAfter(from))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return raspustStarts.isNotEmpty ? raspustStarts.first : null;
  }

  // Helper metode

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static List<_RaspustPeriod> _getRaspustPeriods() {
    final periods = <_RaspustPeriod>[];
    final entries = skolskiRaspust.entries.toList();

    for (var i = 0; i < entries.length; i += 2) {
      if (i + 1 < entries.length && entries[i].value.contains('početak') && entries[i + 1].value.contains('kraj')) {
        periods.add(_RaspustPeriod(
          start: DateTime.parse(entries[i].key),
          end: DateTime.parse(entries[i + 1].key),
        ));
      }
    }

    return periods;
  }
}

class _RaspustPeriod {
  final DateTime start;
  final DateTime end;

  _RaspustPeriod({required this.start, required this.end});
}
