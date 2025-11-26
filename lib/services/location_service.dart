import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Proverava i traži permisije za lokaciju
  static Future<bool> requestLocationPermission() async {
    try {
      // Proveri da li je lokacija omogućena
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Logger removed
        return false;
      }

      // Proveri postojeće permisije (traže se samo jednom pri instalaciji u PermissionService)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }

      // Logger removed
      return true;
    } catch (e) {
      // Logger removed
      return false;
    }
  }

  /// Dobija trenutnu poziciju korisnika
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
          // desiredAccuracy: deprecated, use settings parameter
          // timeLimit: const Duration(seconds: 10), // deprecated, use settings parameter
          );

      return position;
    } catch (e) {
      // Logger removed
      return null;
    }
  }

  /// Reverse geocoding - koordinate u adresu
  static Future<String?> getAddressFromPosition(Position position) async {
    try {
      // Koristi Nominatim API za reverse geocoding
      final address =
          await _reverseGeocode(position.latitude, position.longitude);

      if (address != null) {
        // Logger removed
        return address;
      }

      return null;
    } catch (e) {
      // Logger removed
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
        final address = _formatAddress(data as Map<String, dynamic>);
        return address;
      }

      return null;
    } catch (e) {
      // Logger removed
      return null;
    }
  }

  /// Formatira adresu iz Nominatim JSON odgovora
  static String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) {
      return (data['display_name'] as String?) ?? 'Nepoznata lokacija';
    }

    final components = <String>[];

    // Dodaj broj kuće i ulicu
    if (address['house_number'] != null && address['road'] != null) {
      components.add('${address['road']} ${address['house_number']}');
    } else if (address['road'] != null) {
      components.add(address['road'] as String);
    }

    // Dodaj grad/naselje
    final place = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'];
    if (place != null) {
      if (components.isNotEmpty) {
        components.add(place as String);
      } else {
        components.add(place as String);
      }
    }

    return components.isNotEmpty
        ? components.join(', ')
        : (data['display_name'] as String?) ?? 'Nepoznata lokacija';
  }

  /// Dobija trenutnu adresu korisnika (GPS + reverse geocoding)
  static Future<String?> getCurrentAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      final address = await getAddressFromPosition(position);
      return address;
    } catch (e) {
      // Logger removed
      return null;
    }
  }

  /// Izračunava distancu između dve koordinate (u metrima)
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
