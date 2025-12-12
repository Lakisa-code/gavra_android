import 'package:shared_preferences/shared_preferences.dart';

import '../models/putnik.dart';

class ImenaService {
  static const String _kljucImena = 'cesta_imena';

  /// Dohvata listu čestih imena iz SharedPreferences
  static Future<List<String>> getCestaImena() async {
    final prefs = await SharedPreferences.getInstance();
    final imena = prefs.getStringList(_kljucImena) ?? [];

    // Dodaj neka default imena ako je lista prazna
    if (imena.isEmpty) {
      imena.addAll([
        'Marko',
        'Ana',
        'Petar',
        'Milica',
        'Stefan',
        'Jovana',
        'Miloš',
        'Tamara',

        'Maja',
        'Aleksandar',
        'Jelena',
        'Milan',
        'Nevena',
        'Luka',
        'Kristina',
        'Uroš',
        'Marija',
        'Filip',
        'Teodora',
        'Vladimir',
        'Sanja',
        'Nemanja',
        'Sara',
        'Bojan',
      ]);
      await _sacuvajImena(imena);
    }

    return imena;
  }

  /// Dodaje novo ime u listu čestih imena
  static Future<void> dodajIme(String ime) async {
    if (ime.trim().isEmpty) return;

    final imena = await getCestaImena();
    final imeFormatted = _formatirajIme(ime);

    // Ako ime već postoji, premesti ga na vrh
    if (imena.contains(imeFormatted)) {
      imena.remove(imeFormatted);
    }

    imena.insert(0, imeFormatted);

    // Ograniči na 50 imena
    if (imena.length > 50) {
      imena.removeRange(50, imena.length);
    }

    await _sacuvajImena(imena);
  }

  /// Ažurira česta imena na osnovu postojećih putnika
  static Future<void> azurirajImenaIzPutnika(List<Putnik> putnici) async {
    final Map<String, int> imenaCount = {};

    // Broji koliko puta se koje ime pojavljuje
    for (final putnik in putnici) {
      final ime = _formatirajIme(putnik.ime);
      if (ime.isNotEmpty) {
        imenaCount[ime] = (imenaCount[ime] ?? 0) + 1;
      }
    }

    // Sortira imena po učestalosti
    final sortiranaImena = imenaCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Uzima top 30 imena
    final cestaImena = sortiranaImena.take(30).map((entry) => entry.key).toList();

    // Dodaj postojeća imena da ne izgubimo default-e
    final postojecaImena = await getCestaImena();
    for (final ime in postojecaImena) {
      if (!cestaImena.contains(ime)) {
        cestaImena.add(ime);
      }
    }

    await _sacuvajImena(cestaImena);
  }

  /// Pretražuje imena koja počinju sa datim stringom
  static Future<List<String>> pretraziImena(String query) async {
    if (query.trim().isEmpty) return [];

    final imena = await getCestaImena();
    final queryLower = query.toLowerCase();

    return imena.where((ime) => ime.toLowerCase().startsWith(queryLower)).take(10).toList();
  }

  static Future<void> _sacuvajImena(List<String> imena) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kljucImena, imena);
  }

  static String _formatirajIme(String ime) {
    if (ime.trim().isEmpty) return '';

    // Kapitalizuj prvo slovo
    final trimmed = ime.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }
}
