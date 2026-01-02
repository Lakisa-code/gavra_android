import 'package:supabase_flutter/supabase_flutter.dart';

/// Servis za autocomplete imena putnika - koristi realna imena iz baze
class ImenaService {
  static final _supabase = Supabase.instance.client;

  /// Pretražuje imena iz baze koja počinju sa datim stringom
  static Future<List<String>> pretraziImena(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Pretraži realna imena putnika iz baze
      final response = await _supabase
          .from('registrovani_putnici')
          .select('putnik_ime')
          .ilike('putnik_ime', '${query.trim()}%')
          .limit(20);

      final Set<String> imena = {};

      for (final row in response as List) {
        final punoIme = row['putnik_ime'] as String?;
        if (punoIme != null && punoIme.isNotEmpty) {
          // Izvuci samo prvo ime (pre prvog razmaka)
          final prvoIme = punoIme.split(' ').first.trim();
          if (prvoIme.toLowerCase().startsWith(query.toLowerCase())) {
            imena.add(_formatirajIme(prvoIme));
          }
        }
      }

      return imena.take(10).toList();
    } catch (e) {
      // Fallback na default imena ako baza nije dostupna
      return _getDefaultImena(query);
    }
  }

  /// Dohvata najčešća imena iz baze (za inicijalni prikaz)
  static Future<List<String>> getCestaImena() async {
    try {
      final response =
          await _supabase.from('registrovani_putnici').select('putnik_ime').not('putnik_ime', 'is', null).limit(100);

      final Map<String, int> imenaCount = {};

      for (final row in response as List) {
        final punoIme = row['putnik_ime'] as String?;
        if (punoIme != null && punoIme.isNotEmpty) {
          final prvoIme = _formatirajIme(punoIme.split(' ').first.trim());
          if (prvoIme.isNotEmpty) {
            imenaCount[prvoIme] = (imenaCount[prvoIme] ?? 0) + 1;
          }
        }
      }

      // Sortiraj po učestalosti
      final sortirana = imenaCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      return sortirana.take(30).map((e) => e.key).toList();
    } catch (e) {
      return _defaultImena;
    }
  }

  /// Dodaje ime - sada ne radi ništa jer se imena čitaju iz putnika
  static Future<void> dodajIme(String ime) async {
    // Nije potrebno - imena se automatski dodaju kad se kreira putnik
  }

  /// Ažurira imena - sada ne radi ništa jer se čitaju direktno iz baze
  static Future<void> azurirajImenaIzPutnika(List<dynamic> putnici) async {
    // Nije potrebno - imena se čitaju direktno iz baze
  }

  static String _formatirajIme(String ime) {
    if (ime.trim().isEmpty) return '';
    final trimmed = ime.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  /// Fallback default imena ako baza nije dostupna
  static List<String> _getDefaultImena(String query) {
    final queryLower = query.toLowerCase();
    return _defaultImena.where((ime) => ime.toLowerCase().startsWith(queryLower)).take(10).toList();
  }

  static const List<String> _defaultImena = [
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
    'Dragana',
    'Marina',
    'Ivan',
    'David',
    'Sofija',
    'Tanja',
  ];
}
