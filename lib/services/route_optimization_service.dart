import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/putnik.dart';

class RouteOptimizationService {
  static const String _googleMapsApiKey =
      'AIzaSyBOhQKU9YoA1z_h_N_y_XhbOL5gHWZXqPY'; // Tvoj postojeći ključ

  // 🎯 DOZVOLJENI GRADOVI za navigaciju - samo Bela Crkva i Vršac
  static const List<String> _dozvoljeninGradovi = ['Bela Crkva', 'Vršac'];

  /// 🎯 Filtriraj putnike samo za dozvoljene gradove (Bela Crkva i Vršac)
  static List<Putnik> filterByAllowedCities(List<Putnik> putnici) {
    return putnici
        .where((p) =>
            p.adresa != null &&
            p.adresa!.isNotEmpty &&
            _dozvoljeninGradovi.any((grad) => p.adresa!.contains(grad)))
        .toList();
  }

  /// 🗺️ NOVA FUNKCIJA: Prava geografska optimizacija na osnovu GPS lokacije vozača
  static Future<List<Putnik>> optimizeRouteGeographically(
    List<Putnik> putnici, {
    Position? driverPosition, // Trenutna lokacija vozača
    String? startAddress, // Ili početna adresa kao fallback
  }) async {
    if (putnici.isEmpty) return putnici;

    // 🎯 FILTRIRAJ SAMO BELA CRKVA I VRŠAC gradove za navigaciju
    // Filtriraj samo aktivne putnike sa adresama iz dozvoljenih gradova
    final aktivniPutnici = putnici
        .where((p) =>
            p.status != 'otkazan' &&
            p.status != 'Otkazano' &&
            p.adresa != null &&
            p.adresa!.isNotEmpty &&
            _dozvoljeninGradovi.any((grad) => p.adresa!.contains(grad)))
        .toList();

    if (aktivniPutnici.isEmpty) return putnici;
    if (aktivniPutnici.length == 1) return aktivniPutnici;

    try {
      // 1. Određi početnu lokaciju
      Position? startLocation;

      if (driverPosition != null) {
        startLocation = driverPosition;
      } else if (startAddress != null) {
        // Geokodiraj početnu adresu u koordinate
        startLocation = await _geocodeAddress(startAddress);
      } else {
        // Pokušaj da dohvatiš trenutnu GPS lokaciju
        try {
          startLocation = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          return _fallbackToOriginalOrder(aktivniPutnici);
        }
      }

      if (startLocation == null) {
        return _fallbackToOriginalOrder(aktivniPutnici);
      }

      // 2. Geokodiraj sve adrese putnika u koordinate
      final putnikCoordinates = <Putnik, Position>{};

      for (final putnik in aktivniPutnici) {
        final coordinates = await _geocodeAddress(putnik.adresa!);
        if (coordinates != null) {
          putnikCoordinates[putnik] = coordinates;
        }
      }

      if (putnikCoordinates.isEmpty) {
        return _fallbackToOriginalOrder(aktivniPutnici);
      }

      // 3. Koristi Traveling Salesman Problem (TSP) algoritam
      final optimizedRoute = await _solveTSP(
        startLocation,
        putnikCoordinates,
      );

      return optimizedRoute;
    } catch (e) {
      return _fallbackToOriginalOrder(aktivniPutnici);
    }
  }

  /// 🌍 Geokodiraj adresu u koordinate pomoću Google Geocoding API
  static Future<Position?> _geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return Position(
            latitude: location['lat'],
            longitude: location['lng'],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }
    } catch (e) {
      // Greška u geocoding procesu
    }
    return null;
  }

  /// 🧮 Reši Traveling Salesman Problem (TSP) - Nearest Neighbor algoritam
  static Future<List<Putnik>> _solveTSP(
    Position start,
    Map<Putnik, Position> destinations,
  ) async {
    final List<Putnik> optimizedRoute = [];
    final unvisited = Set<Putnik>.from(destinations.keys);
    Position currentPosition = start;

    // Nearest Neighbor algoritam
    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      // Pronađi najbližu destinaciju
      for (final putnik in unvisited) {
        final distance = _calculateDistance(
          currentPosition,
          destinations[putnik]!,
        );

        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = putnik;
        }
      }

      if (nearest != null) {
        optimizedRoute.add(nearest);
        currentPosition = destinations[nearest]!;
        unvisited.remove(nearest);
      }
    }

    return optimizedRoute;
  }

  /// 📐 Izračunaj udaljenost između dve geografske tačke (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// � Jednostavno vrati originalni redosled ako GPS optimizacija ne uspe
  static List<Putnik> _fallbackToOriginalOrder(List<Putnik> putnici) {
    // Jednostavno vrati putnice u originalnom redosledu
    // Originalni redosled iz baze je često logičan i pošten (FIFO)
    return List<Putnik>.from(putnici);
  }

  // Optimizuj rutu za određeni polazak (specifično za grad i vreme)
  static Future<List<Putnik>> optimizeRoute(List<Putnik> putnici) async {
    if (putnici.isEmpty) return putnici;

    // Filtriraj samo one koji nisu otkazani
    final aktivniPutnici = putnici
        .where((p) => p.status != 'otkazan' && p.status != 'Otkazano')
        .toList();

    if (aktivniPutnici.isEmpty) return putnici;

    // Zadržava originalni redosled iz baze umesto alfabetskog sortiranja
    // Originalni redosled često prati logiku unosa i registracije putnika
    // što je pravednije i prirodnije za vozače i putnike

    // Dodaj otkazane na kraj
    final otkazaniPutnici = putnici
        .where((p) => p.status == 'otkazan' || p.status == 'Otkazano')
        .toList();

    return [...aktivniPutnici, ...otkazaniPutnici];
  }

  // NOVA FUNKCIJA: Optimizuj rutu za specifičan grad i vreme
  static Future<List<Putnik>> optimizeRouteForCityAndTime(
    List<Putnik> allPutnici,
    String grad,
    String vreme,
    String dan,
  ) async {
    if (allPutnici.isEmpty) return [];

    // 🎯 Dodatna sigurnost - proverava da je grad dozvoljeni
    if (!_dozvoljeninGradovi.contains(grad)) {
      return [];
    }

    // Filtriraj putnike samo za određeni grad, vreme i dan
    final filteredPutnici = allPutnici.where((putnik) {
      // Provjeri osnovne kriterijume
      final matchesBasic =
          putnik.dan == dan && putnik.polazak == vreme && putnik.grad == grad;

      // Isključi otkazane
      final notCanceled =
          putnik.status != 'otkazan' && putnik.status != 'Otkazano';

      return matchesBasic && notCanceled;
    }).toList();

    if (filteredPutnici.isEmpty) return [];

    // Optimizuj rutu samo za filtrirane putnike
    return await optimizeRoute(filteredPutnici);
  }

  // Izračunaj ukupnu distancu (simulacija) - ZASTARELO, koristi se nova geografska optimizacija
  static double calculateTotalDistance(List<Putnik> putnici) {
    if (putnici.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < putnici.length - 1; i++) {
      // Simulacija distance calculation
      final fromIdentifier = putnici[i].adresa ?? putnici[i].ime;
      final toIdentifier = putnici[i + 1].adresa ?? putnici[i + 1].ime;

      if (fromIdentifier.isEmpty || toIdentifier.isEmpty) {
        totalDistance += 1.0;
      } else {
        final diff = (fromIdentifier.length - toIdentifier.length).abs();
        totalDistance += diff * 0.5 + Random().nextDouble() * 2;
      }
    }
    return totalDistance;
  }

  // Generiši rutu string za prikaz
  static Future<String> generateRouteString(List<Putnik> putnici) async {
    return generateRouteStringSync(putnici);
  }

  // 🔄 REAL-TIME ROUTE STRING STREAM
  static Stream<String> streamRouteString(Stream<List<Putnik>> putniciStream) {
    return putniciStream.map((putnici) => generateRouteStringSync(putnici));
  }

  // 📍 SINHRONA GENERACIJA ROUTE STRING-a
  static String generateRouteStringSync(List<Putnik> putnici) {
    if (putnici.isEmpty) return 'Nema putnika';

    final aktivniPutnici = putnici
        .where((p) => p.status != 'otkazan' && p.status != 'Otkazano')
        .toList();

    if (aktivniPutnici.isEmpty) return 'Nema aktivnih putnika';

    // Generiši rutu string koristeći SAMO adrese iz tabele putnici
    final rutaDelovi = aktivniPutnici.map((p) {
      final adresa = p.adresa;
      return adresa != null && adresa.isNotEmpty ? '${p.ime} ($adresa)' : p.ime;
    }).toList();

    return rutaDelovi.join(' → ');
  }

  // NOVA FUNKCIJA: Generiši optimizovan route string za specifičan grad i vreme
  static Future<String> generateOptimizedRouteForCityAndTime(
    List<Putnik> allPutnici,
    String grad,
    String vreme,
    String dan,
  ) async {
    final optimizedPutnici =
        await optimizeRouteForCityAndTime(allPutnici, grad, vreme, dan);

    if (optimizedPutnici.isEmpty) {
      return 'Nema putnika za $grad u $vreme';
    }

    final rutaDelovi = optimizedPutnici.map((p) {
      final adresa = p.adresa;
      return adresa != null && adresa.isNotEmpty ? '${p.ime} ($adresa)' : p.ime;
    }).toList();

    return '🚗 $grad $vreme: ${rutaDelovi.join(' → ')}';
  }

  // NOVA FUNKCIJA: Optimizuj sve rute za sve gradove i vremena odjednom
  static Future<Map<String, List<Putnik>>> optimizeAllRoutes(
    List<Putnik> allPutnici,
    String dan,
  ) async {
    const gradovi = ['Bela Crkva', 'Vršac'];
    const vremena = [
      '05:00',
      '06:00',
      '07:00',
      '08:00',
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
      '21:00',
      '22:00'
    ];

    Map<String, List<Putnik>> optimizedRoutes = {};

    for (String grad in gradovi) {
      for (String vreme in vremena) {
        final routeKey = '${grad}_$vreme';
        final optimizedRoute =
            await optimizeRouteForCityAndTime(allPutnici, grad, vreme, dan);

        if (optimizedRoute.isNotEmpty) {
          optimizedRoutes[routeKey] = optimizedRoute;
        }
      }
    }

    return optimizedRoutes;
  }

  // NOVA FUNKCIJA: Generiši kompletnu rutu za ceo dan
  static Future<String> generateDailyRouteReport(
    List<Putnik> allPutnici,
    String dan,
  ) async {
    final allRoutes = await optimizeAllRoutes(allPutnici, dan);

    if (allRoutes.isEmpty) {
      return 'Nema putnika za $dan';
    }

    List<String> reportLines = [];
    reportLines.add('📅 OPTIMIZOVANE RUTE ZA $dan:');
    reportLines.add('=' * 40);

    for (String routeKey in allRoutes.keys) {
      final parts = routeKey.split('_');
      final grad = parts[0];
      final vreme = parts[1];
      final putnici = allRoutes[routeKey]!;

      final rutaString = putnici.map((p) {
        final adresa = p.adresa;
        return adresa != null && adresa.isNotEmpty
            ? '${p.ime} ($adresa)'
            : p.ime;
      }).join(' → ');

      reportLines.add('🚗 $grad $vreme (${putnici.length}): $rutaString');
    }

    return reportLines.join('\n');
  }

  // Proveri da li je ruta logično organizovana (bez alfabetskog sortiranja)
  static Future<bool> isRouteOptimized(List<Putnik> putnici) async {
    if (putnici.isEmpty) return true;

    final aktivniPutnici = putnici
        .where((p) => p.status != 'otkazan' && p.status != 'Otkazano')
        .toList();

    if (aktivniPutnici.length < 2) return true;

    // Jednostavno proverava da li lista ima logičnu strukturu
    // bez forsiranja alfabetskog redosleda

    // Proveri da li su otkazani putnici na kraju
    final imaAktivnihNaKraju = putnici.any((p) =>
        (p.status == 'otkazan' || p.status == 'Otkazano') &&
        putnici.indexOf(p) < putnici.length - 1 &&
        putnici.sublist(putnici.indexOf(p) + 1).any(
            (next) => next.status != 'otkazan' && next.status != 'Otkazano'));

    return !imaAktivnihNaKraju; // True ako otkazani NISU između aktivnih
  }
}
