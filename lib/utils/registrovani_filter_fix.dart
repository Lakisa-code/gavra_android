/// 🔧 POBOLJŠANA LOGIKA FILTRIRANJA MESEČNIH PUTNIKA
/// Centralizovana logika za konzistentno filtriranje

class RegistrovaniFilterFix {
  /// ✅ ISPRAVKA 1: Tačno matchovanje dana umesto contains()
  static bool matchesDan(String radniDani, String dan) {
    final daniList = radniDani.toLowerCase().split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();

    return daniList.contains(dan.toLowerCase().trim());
  }

  /// ✅ ISPRAVKA 2: Standardizovano mapiranje kratice dana
  static String getDayAbbreviation(DateTime date) {
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[date.weekday - 1];
  }

  static String getDayAbbreviationFromName(String dayName) {
    final dayMap = {
      'ponedeljak': 'pon',
      'utorak': 'uto',
      'sreda': 'sre',
      'četvrtak': 'cet',
      'petak': 'pet',
      'subota': 'sub',
      'nedelja': 'ned',
    };
    return dayMap[dayName.toLowerCase()] ?? 'pon';
  }

  /// ✅ ISPRAVKA 3: Poboljšana validacija vremena polaska
  static bool isValidPolazak(String? polazak) {
    if (polazak == null || polazak.isEmpty) return false;

    final cleaned = polazak.trim().toLowerCase();

    // Isključi nevažeće vrednosti
    final invalidValues = ['00:00:00', '00:00', 'null', 'undefined', ''];
    if (invalidValues.contains(cleaned)) return false;

    // Proveri format vremena (HH:MM ili HH:MM:SS)
    final timeRegex = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');
    return timeRegex.hasMatch(cleaned);
  }

  /// ✅ ISPRAVKA 4: Centralizovana logika aktivnosti
  static bool isAktivan(dynamic putnik) {
    // Za Map objekte iz baze
    if (putnik is Map<String, dynamic>) {
      final aktivan = putnik['aktivan'] ?? false;
      final obrisan = putnik['obrisan'] ?? false;
      return aktivan == true && obrisan != true;
    }

    // Za RegistrovaniPutnik objekte (treba da ima getters)
    try {
      return putnik.aktivan == true && putnik.obrisan != true;
    } catch (e) {
      return false;
    }
  }

  /// ✅ ISPRAVKA 5: Standardizovano filtriranje po statusu
  static bool isValidStatus(String? status) {
    if (status == null) return true;

    final normalizedStatus = status.toLowerCase().trim();
    final invalidStatuses = [
      'bolovanje',
      'godišnje',
      'godisnji',
      'obrisan',
      'otkazan',
      'otkazano',
    ];

    return !invalidStatuses.contains(normalizedStatus);
  }

  /// ✅ ISPRAVKA 6: Kompletan filter za mesečne putnike
  static bool shouldIncludeRegistrovaniPutnik({
    required dynamic putnik,
    String? targetDay,
    String? searchTerm,
    String? filterType,
    bool includeInactiveStatuses = false,
  }) {
    // 1. Proveri aktivnost
    if (!isAktivan(putnik)) return false;

    // 2. Proveri status (osim ako nije eksplicitno dozvoljeno)
    if (!includeInactiveStatuses) {
      final status = putnik is Map ? putnik['status'] as String? : putnik.status as String?;
      if (!isValidStatus(status)) return false;
    }

    // 3. Proveri dan (ako je specifikovan)
    if (targetDay != null) {
      final radniDani = putnik is Map ? (putnik['radni_dani'] ?? '') as String : (putnik.radniDani ?? '') as String;
      if (!matchesDan(radniDani, targetDay)) return false;
    }

    // 4. Proveri search term
    if (searchTerm != null && searchTerm.isNotEmpty) {
      final ime = putnik is Map ? (putnik['putnik_ime'] ?? '') as String : (putnik.putnikIme ?? '') as String;
      final tip = putnik is Map ? (putnik['tip'] ?? '') as String : (putnik.tip ?? '') as String;
      final tipSkole = putnik is Map ? (putnik['tip_skole'] ?? '') as String : (putnik.tipSkole ?? '') as String;

      final searchLower = searchTerm.toLowerCase();
      if (!(ime.toLowerCase().contains(searchLower) ||
          tip.toLowerCase().contains(searchLower) ||
          tipSkole.toLowerCase().contains(searchLower))) {
        return false;
      }
    }

    // 5. Proveri filter type
    if (filterType != null && filterType != 'svi') {
      final tip = putnik is Map ? putnik['tip'] : putnik.tip;
      if (tip != filterType) return false;
    }

    return true;
  }

  /// ✅ ISPRAVKA 7: Optimizovani SQL upit za mesečne putnike
  static String buildOptimizedQuery({
    String? targetDay,
    bool activeOnly = true,
    String? orderBy = 'putnik_ime',
  }) {
    var query = '''
      SELECT * FROM registrovani_putnici 
      WHERE 1=1
    ''';

    if (activeOnly) {
      query += ' AND aktivan = true AND obrisan = false';
    }

    if (targetDay != null) {
      query += " AND radni_dani LIKE '%$targetDay%'";
    }

    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }

    return query;
  }
}
