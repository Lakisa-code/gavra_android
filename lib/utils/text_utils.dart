/// Utilities za rad sa tekstom u aplikaciji
class TextUtils {
  /// Normalizuje tekst - konvertuje kvačice u obična slova
  /// Ovo omogućava poređenje "godišnji" i "godisnji" kao istih
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('ć', 'c')
        .replaceAll('č', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'd');
  }

  /// Normalizuje tip putnika (npr. "djak" ili "student") u "ucenik".
  ///
  /// Centralizovana logika čini lako prilagođavanje sinonima bez menjanja
  /// logike u više fajlova.
  static String normalizeTip(String tip) {
    final normalized = normalizeText(tip);
    if (normalized.contains('ucenik')) return 'ucenik';
    if (normalized.contains('djak') || normalized.contains('student')) {
      return 'ucenik';
    }
    return normalized;
  }

  /// Poredi dva statusa uzimajući u obzir kvačice
  /// "godišnji" == "godisnji" vraća true
  static bool statusEquals(String status1, String status2) {
    return normalizeText(status1) == normalizeText(status2);
  }

  /// Proverava da li status pripada određenoj kategoriji
  static bool isStatusInCategory(String? status, List<String> category) {
    if (status == null) return false;
    final normalized = normalizeText(status);
    return category.any((cat) => normalizeText(cat) == normalized);
  }

  /// Kategorije statusa za lakše korišćenje
  static const List<String> bolovanjeGodisnji = [
    'bolovanje',
    'godišnji',
    'godisnji',
  ];
  static const List<String> otkazani = ['otkazano', 'otkazan'];
  static const List<String> pokupljeni = ['pokupljen'];
  static const List<String> neaktivni = ['obrisan', 'neaktivan'];

  /// Proverava da li je putnik u aktivnom statusu (nije otkazan, na bolovanju itd.)
  /// Koristi se za BROJANJE zauzetih mesta
  static bool isStatusActive(String? status) {
    if (status == null) return true;
    final normalized = normalizeText(status);

    return !otkazani.any((s) => normalizeText(s) == normalized) &&
        !bolovanjeGodisnji.any((s) => normalizeText(s) == normalized) &&
        !neaktivni.any((s) => normalizeText(s) == normalized);
  }

  /// Proverava da li putnik treba da bude VIDLJIV u listi
  /// Uključuje bolovanje/godišnji (prikazuju se žutom bojom)
  /// Koristi se za FILTRIRANJE liste za prikaz
  static bool isStatusVisible(String? status) {
    if (status == null) return true;
    final normalized = normalizeText(status);

    // Isključi samo otkazane i obrisane, ALI PRIKAŽI bolovanje/godišnji
    return !otkazani.any((s) => normalizeText(s) == normalized) &&
        !neaktivni.any((s) => normalizeText(s) == normalized);
  }
}
