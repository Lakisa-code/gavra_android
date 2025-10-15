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
  static bool isStatusActive(String? status) {
    if (status == null) return true;
    final normalized = normalizeText(status);

    return !otkazani.any((s) => normalizeText(s) == normalized) &&
        !bolovanjeGodisnji.any((s) => normalizeText(s) == normalized) &&
        !neaktivni.any((s) => normalizeText(s) == normalized);
  }
}





