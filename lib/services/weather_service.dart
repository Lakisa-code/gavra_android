import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 🌤️ Weather Service - Open-Meteo ECMWF API
/// Najtačnija besplatna prognoza za Evropu!
/// - Koristi ECMWF model (zlatni standard za Evropu)
/// - Bez registracije, bez API key-a, bez limita
/// - Isti podaci kao premium servisi (Weather & Radar itd.)
class WeatherService {
  // Open-Meteo API - BESPLATAN, bez registracije!
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  // Lokacije - Bela Crkva i Vršac
  static const double bcLat = 44.8986;
  static const double bcLon = 21.4181;
  static const double vsLat = 45.1167;
  static const double vsLon = 21.3000;

  // Cache za smanjenje API poziva - odvojeno za BC i VS
  static Map<String, dynamic>? _cachedWeatherBC;
  static Map<String, dynamic>? _cachedWeatherVS;
  static DateTime? _cacheTimeBC;
  static DateTime? _cacheTimeVS;
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// WMO Weather interpretation codes -> naši uslovi
  /// https://open-meteo.com/en/docs
  static String _wmoCodeToCondition(int code) {
    // 0: Clear sky
    if (code == 0) return 'sunny';

    // 1-3: Mainly clear, partly cloudy, overcast
    if (code >= 1 && code <= 3) return 'cloudy';

    // 45, 48: Fog
    if (code == 45 || code == 48) return 'cloudy';

    // 51-57: Drizzle
    if (code >= 51 && code <= 57) return 'rain';

    // 61-67: Rain
    if (code >= 61 && code <= 67) return 'rain';

    // 71-77: Snow
    if (code >= 71 && code <= 77) return 'snow';

    // 80-82: Rain showers
    if (code >= 80 && code <= 82) return 'rain';

    // 85-86: Snow showers
    if (code == 85 || code == 86) return 'snow';

    // 95, 96, 99: Thunderstorm
    if (code >= 95) return 'storm';

    return 'cloudy';
  }

  /// WMO kod -> srpski opis
  static String _wmoCodeToDescription(int code) {
    switch (code) {
      case 0:
        return 'vedro';
      case 1:
        return 'pretežno vedro';
      case 2:
        return 'delimično oblačno';
      case 3:
        return 'oblačno';
      case 45:
        return 'magla';
      case 48:
        return 'magla sa mrazom';
      case 51:
        return 'slaba rosulja';
      case 53:
        return 'umerena rosulja';
      case 55:
        return 'jaka rosulja';
      case 56:
        return 'ledena rosulja';
      case 57:
        return 'jaka ledena rosulja';
      case 61:
        return 'slaba kiša';
      case 63:
        return 'umerena kiša';
      case 65:
        return 'jaka kiša';
      case 66:
        return 'ledena kiša';
      case 67:
        return 'jaka ledena kiša';
      case 71:
        return 'slab sneg';
      case 73:
        return 'umeren sneg';
      case 75:
        return 'jak sneg';
      case 77:
        return 'snežna zrna';
      case 80:
        return 'slabi pljuskovi';
      case 81:
        return 'umereni pljuskovi';
      case 82:
        return 'jaki pljuskovi';
      case 85:
        return 'slabi snežni pljuskovi';
      case 86:
        return 'jaki snežni pljuskovi';
      case 95:
        return 'grmljavina';
      case 96:
        return 'grmljavina sa gradom';
      case 99:
        return 'jaka grmljavina sa gradom';
      default:
        return 'promenljivo';
    }
  }

  /// Dohvata vreme za Belu Crkvu
  static Future<Map<String, dynamic>> getWeatherBC() async {
    return _getWeatherForLocation(bcLat, bcLon, 'BC');
  }

  /// Dohvata vreme za Vršac
  static Future<Map<String, dynamic>> getWeatherVS() async {
    return _getWeatherForLocation(vsLat, vsLon, 'VS');
  }

  /// Dohvata trenutno vreme sa Open-Meteo ECMWF
  /// Vraća: { 'condition': 'rain', 'temp': 5, 'description': 'slaba kiša' }
  static Future<Map<String, dynamic>> _getWeatherForLocation(
    double lat,
    double lon,
    String locationKey,
  ) async {
    try {
      // Proveri cache za ovu lokaciju
      final cachedWeather = locationKey == 'BC' ? _cachedWeatherBC : _cachedWeatherVS;
      final cacheTime = locationKey == 'BC' ? _cacheTimeBC : _cacheTimeVS;

      if (cachedWeather != null && cacheTime != null) {
        final elapsed = DateTime.now().difference(cacheTime);
        if (elapsed < _cacheDuration) {
          debugPrint('🌤️ Weather $locationKey: using cached data (${elapsed.inMinutes}min old)');
          return cachedWeather;
        }
      }

      // Open-Meteo API poziv - koristi ECMWF model
      final url = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
          '&timezone=Europe/Belgrade'
          '&models=ecmwf_ifs025' // ECMWF model - najtačniji za Evropu!
          );

      debugPrint('🌤️ Weather $locationKey: fetching from Open-Meteo ECMWF...');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weather = _parseOpenMeteoData(data);

        // Cache rezultat za ovu lokaciju
        if (locationKey == 'BC') {
          _cachedWeatherBC = weather;
          _cacheTimeBC = DateTime.now();
        } else {
          _cachedWeatherVS = weather;
          _cacheTimeVS = DateTime.now();
        }

        debugPrint('🌤️ Weather $locationKey: ${weather['temp']}°C, ${weather['description']}');
        return weather;
      } else {
        debugPrint('⚠️ Weather $locationKey API error: ${response.statusCode}');
        return _getMockWeather();
      }
    } catch (e) {
      debugPrint('⚠️ Weather $locationKey fetch error: $e');
      return _getMockWeather();
    }
  }

  /// Legacy metoda za kompatibilnost
  static Future<Map<String, dynamic>> getCurrentWeather({
    double? lat,
    double? lon,
  }) async {
    // Default na BC
    return getWeatherBC();
  }

  /// Parsira Open-Meteo response
  static Map<String, dynamic> _parseOpenMeteoData(Map<String, dynamic> data) {
    try {
      final current = data['current'] ?? {};

      final weatherCode = (current['weather_code'] ?? 0) as int;
      final condition = _wmoCodeToCondition(weatherCode);
      final description = _wmoCodeToDescription(weatherCode);

      return {
        'condition': condition,
        'temp': (current['temperature_2m'] ?? 0).round(),
        'description': description,
        'humidity': (current['relative_humidity_2m'] ?? 0).round(),
        'windSpeed': (current['wind_speed_10m'] ?? 0).round(),
        'weatherCode': weatherCode,
      };
    } catch (e) {
      debugPrint('⚠️ Weather parse error: $e');
      return _getMockWeather();
    }
  }

  /// Fallback kada API ne radi - sezonski mock
  static Map<String, dynamic> _getMockWeather() {
    final month = DateTime.now().month;

    // Zima: sneg
    if (month == 12 || month == 1 || month == 2) {
      return {
        'condition': 'snow',
        'temp': -2,
        'description': 'sneg',
        'humidity': 85,
        'windSpeed': 10,
        'weatherCode': 73,
      };
    }

    // Proleće: kiša
    if (month >= 3 && month <= 5) {
      return {
        'condition': 'rain',
        'temp': 12,
        'description': 'slaba kiša',
        'humidity': 70,
        'windSpeed': 15,
        'weatherCode': 61,
      };
    }

    // Leto: sunčano
    if (month >= 6 && month <= 8) {
      return {
        'condition': 'sunny',
        'temp': 28,
        'description': 'vedro',
        'humidity': 45,
        'windSpeed': 8,
        'weatherCode': 0,
      };
    }

    // Jesen: oblačno
    return {
      'condition': 'cloudy',
      'temp': 10,
      'description': 'oblačno',
      'humidity': 65,
      'windSpeed': 12,
      'weatherCode': 3,
    };
  }

  /// Vraća Lottie asset path za dati uslov
  static String getLottieAsset(String condition) {
    switch (condition) {
      case 'sunny':
        return 'assets/weather/sunny.json';
      case 'rain':
        return 'assets/weather/rain.json';
      case 'snow':
        return 'assets/weather/snow.json';
      case 'storm':
        return 'assets/weather/storm.json';
      case 'cloudy':
      default:
        return 'assets/weather/cloudy.json';
    }
  }

  /// Forsira refresh (briše cache)
  static void clearCache() {
    _cachedWeatherBC = null;
    _cachedWeatherVS = null;
    _cacheTimeBC = null;
    _cacheTimeVS = null;
    debugPrint('🌤️ Weather cache cleared');
  }
}
