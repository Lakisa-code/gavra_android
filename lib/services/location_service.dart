import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'geocoding_service.dart';
import 'package:logger/logger.dart';

class LocationService {
  static final Logger _logger = Logger();

  /// Proverava i traži permisije za lokaciju
  static Future<bool> requestLocationPermission() async {
    try {
      // Proveri da li je lokacija omogućena
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('📍 Location services su onemogućeni');
        return false;
      }

      // Proveri postojeće permisije
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('📍 Location permisije su odbačene');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.e('📍 Location permisije su trajno odbačene');
        return false;
      }

      _logger.i('📍 Location permisije odobrene');
      return true;
    } catch (e) {
      _logger.e('❌ Greška kod permisija: $e');
      return false;
    }
  }

  /// Dobija trenutnu poziciju korisnika
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _logger.i(
          '📍 Trenutna pozicija: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _logger.e('❌ Greška dobijanja pozicije: $e');
      return null;
    }
  }

  /// Reverse geocoding - koordinate u adresu
  static Future<String?> getAddressFromPosition(Position position) async {
    try {
      // Koristi Nominatim API za reverse geocoding
      final coords = '${position.latitude},${position.longitude}';
      final address =
          await _reverseGeocode(position.latitude, position.longitude);

      if (address != null) {
        _logger.i('📍 Reverse geocoding: $coords -> $address');
        return address;
      }

      return null;
    } catch (e) {
      _logger.e('❌ Greška reverse geocoding: $e');
      return null;
    }
  }

  /// Poziva Nominatim reverse geocoding API
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      const String baseUrl = 'https://nominatim.openstreetmap.org/reverse';
      final url =
          '$baseUrl?lat=$lat&lon=$lng&format=json&addressdetails=1&accept-language=sr';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'GavraAndroidApp/1.0 (transport app)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Formatiraj adresu iz Nominatim odgovora
        final address = _formatAddress(data);
        return address;
      }

      return null;
    } catch (e) {
      _logger.e('❌ Reverse geocoding API greška: $e');
      return null;
    }
  }

  /// Formatira adresu iz Nominatim JSON odgovora
  static String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return data['display_name'] ?? 'Nepoznata lokacija';

    final components = <String>[];

    // Dodaj broj kuće i ulicu
    if (address['house_number'] != null && address['road'] != null) {
      components.add('${address['road']} ${address['house_number']}');
    } else if (address['road'] != null) {
      components.add(address['road']);
    }

    // Dodaj grad/naselje
    final place = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'];
    if (place != null) {
      if (components.isNotEmpty) {
        components.add(place);
      } else {
        components.add(place);
      }
    }

    return components.isNotEmpty
        ? components.join(', ')
        : data['display_name'] ?? 'Nepoznata lokacija';
  }

  /// Dobija trenutnu adresu korisnika (GPS + reverse geocoding)
  static Future<String?> getCurrentAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      final address = await getAddressFromPosition(position);
      return address;
    } catch (e) {
      _logger.e('❌ Greška dobijanja trenutne adrese: $e');
      return null;
    }
  }

  /// Izračunava distancu između dve koordinate (u metrima)
  static double calculateDistance(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
