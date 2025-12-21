import 'package:shared_preferences/shared_preferences.dart';

import '../utils/grad_adresa_validator.dart';
import 'geocoding_service.dart';

/// Servis za upravljanje i filtriranje adresa po gradovima - LOCAL IMPLEMENTACIJA
/// 🏘️ OGRANIČENO NA BELA CRKVA I VRŠAC ADRESE SAMO
///
/// KADA KORISTITI:
/// - Za autocomplete adresa u UI forms
/// - Za lokalno cache-ovanje često korišćenih adresa
/// - Za address validation po gradovima
/// - Za geocoding integration
/// - Za putnik adrese (stringovi u forms)
///
/// NE KORISTITI ZA:
/// - Trajno čuvanje struktuirane adrese (koristi AdresaService)
/// - Relacijske veze sa UUID-jima
/// - Admin CRUD operacije na cloud adresama
class AdreseService {
  static const String _kljucAdreseBelaCrkva = 'adrese_bela_crkva';
  static const String _kljucAdreseVrsac = 'adrese_vrsac';

  /// Dobija adrese za određeni grad - 🏘️ SAMO BELA CRKVA I VRŠAC
  static Future<List<String>> getAdreseZaGrad(String grad) async {
    // 🚫 BLOKIRANJE DRUGIH GRADOVA
    if (GradAdresaValidator.isCityBlocked(grad)) {
      return []; // Vraća praznu listu za blokirane gradove
    }

    final prefs = await SharedPreferences.getInstance();
    final String kljuc = grad.toLowerCase() == 'bela crkva' ? _kljucAdreseBelaCrkva : _kljucAdreseVrsac;

    List<String> adrese = prefs.getStringList(kljuc) ?? [];

    if (adrese.isEmpty) {
      adrese = _getDefaultAdrese(grad);
      await _sacuvajAdrese(grad, adrese);
    }

    // 🏘️ FILTRIRAJ ADRESE - ukloni sve što nije iz dozvoljenih gradova
    adrese = adrese
        .where(
          (adresa) => GradAdresaValidator.isAdresaInAllowedCity(adresa, grad),
        )
        .toList();

    return adrese;
  }

  /// Default adrese za svaki grad
  static List<String> _getDefaultAdrese(String grad) {
    if (grad.toLowerCase() == 'bela crkva') {
      return [
        'Zmaj Jovina',
        'Glavna',
        'Đure Jakšića',
        'Svetosavska',
        'Kosovska',
        'Kneza Miloša',
        'Bulvar oslobođenja',
        'Vojvođanska',
        'Doža Đerđa',
        'Cara Dušana',
        'Nemanjina',
        'Kralja Petra',
        'Karađorđeva',
        'Miloša Obilića',
        'Vuka Karadžića',
      ];
    } else {
      // Vršac
      return [
        'Trg pobede',
        'Žarka Zrenjanina',
        'Svetosavska',
        'Abadžijska',
        'Prvomajska',
        'Vuka Karadžića',
        'Sterijina',
        'Kozjačka',
        'Omladinskih brigada',
        'Nemanjina',
        'Karađorđeva',
        'Milutina Milankovića',
        'Feješ Klare',
        'Dositejeva',
        'Heroja Pinkija',
      ];
    }
  }

  /// Dodaje novu adresu u listu za određeni grad - 🏘️ SA VALIDACIJOM
  static Future<void> dodajAdresu(String grad, String adresa) async {
    if (adresa.trim().isEmpty) return;

    // 🚫 VALIDACIJA GRADA
    if (GradAdresaValidator.isCityBlocked(grad)) {
      return; // Ne dodaj adrese za blokirane gradove
    }

    // 🏘️ VALIDACIJA ADRESE
    if (!GradAdresaValidator.validateAdresaForCity(adresa, grad)) {
      return; // Ne dodaj adrese koje nisu iz dozvoljenih gradova
    }

    final adrese = await getAdreseZaGrad(grad);
    final adresaFormatted = _formatirajAdresu(adresa);

    if (adrese.contains(adresaFormatted)) {
      adrese.remove(adresaFormatted);
    }

    adrese.insert(0, adresaFormatted);

    if (adrese.length > 30) {
      adrese.removeRange(30, adrese.length);
    }

    await _sacuvajAdrese(grad, adrese);
  }

  /// Pretraživanje adresa za određeni grad - 🏘️ SA VALIDACIJOM + GEOCODING
  static Future<List<String>> pretraziAdrese(String grad, String query) async {
    // 🚫 BLOKIRANJE DRUGIH GRADOVA
    if (GradAdresaValidator.isCityBlocked(grad)) {
      return []; // Vraća praznu listu za blokirane gradove
    }

    if (query.trim().isEmpty) {
      return await getAdreseZaGrad(grad);
    }

    final adrese = await getAdreseZaGrad(grad);
    final queryLower = query.toLowerCase();

    final localResults = adrese.where((adresa) => adresa.toLowerCase().contains(queryLower)).toList();

    final isPlaceQuery = _isPlaceQuery(queryLower);

    if (localResults.isEmpty || isPlaceQuery) {
      try {
        final coords = await GeocodingService.getKoordinateZaAdresu(grad, query);
        if (coords != null) {
          final geocodedLocation = query.trim();

          await _sacuvajGeocodedAdresu(grad, geocodedLocation);

          final combinedResults = <String>[geocodedLocation];

          for (final local in localResults) {
            if (!local.toLowerCase().contains(queryLower)) {
              combinedResults.add(local);
            }
          }
          combinedResults.addAll(localResults);

          return combinedResults.take(10).toList();
        }
      } catch (e) {
        // 🔇 Ignore
      }
    }

    return localResults
        .where(
          (adresa) => GradAdresaValidator.isAdresaInAllowedCity(adresa, grad),
        )
        .toList();
  }

  /// Proverava da li query izgleda kao naziv mesta/ustanove
  static bool _isPlaceQuery(String query) {
    const placeKeywords = [
      'bolnica',
      'škola',
      'vrtić',
      'ambulanta',
      'pošta',
      'banka',
      'crkva',
      'park',
      'stadion',
      'centar',
      'market',
      'prodavnica',
      'restoran',
      'kafić',
      'hotel',
      'dom zdravlja',
      'apoteka',
    ];

    return placeKeywords.any((keyword) => query.contains(keyword));
  }

  /// Ažurira adrese na osnovu postojećih putnika
  static Future<void> azurirajAdreseIzBaze() async {}

  static Future<void> _sacuvajAdrese(String grad, List<String> adrese) async {
    final prefs = await SharedPreferences.getInstance();
    final String kljuc = grad.toLowerCase() == 'bela crkva' ? _kljucAdreseBelaCrkva : _kljucAdreseVrsac;
    await prefs.setStringList(kljuc, adrese);
  }

  /// Automatski sačuva pronađenu adresu u lokalnu listu
  static Future<void> _sacuvajGeocodedAdresu(String grad, String adresa) async {
    try {
      final postojeceAdrese = await getAdreseZaGrad(grad);
      final adresaFormatted = _formatirajAdresu(adresa);

      if (postojeceAdrese.contains(adresaFormatted)) {
        postojeceAdrese.remove(adresaFormatted);
      }

      postojeceAdrese.insert(0, adresaFormatted);

      if (postojeceAdrese.length > 30) {
        postojeceAdrese.removeRange(30, postojeceAdrese.length);
      }

      await _sacuvajAdrese(grad, postojeceAdrese);
    } catch (e) {
      // 🔇 Ignore
    }
  }

  static String _formatirajAdresu(String adresa) {
    if (adresa.trim().isEmpty) return '';

    return adresa
        .trim()
        .split(' ')
        .map(
          (word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word,
        )
        .join(' ');
  }

  /// Resetuje adrese za određeni grad na default vrednosti
  static Future<void> resetujAdrese(String grad) async {
    final defaultAdrese = _getDefaultAdrese(grad);
    await _sacuvajAdrese(grad, defaultAdrese);
  }

  /// Briše sve adrese za određeni grad
  static Future<void> obrisiSveAdrese(String grad) async {
    await _sacuvajAdrese(grad, []);
  }
}
