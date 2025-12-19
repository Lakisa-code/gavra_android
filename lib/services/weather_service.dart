import 'dart:convert';

import 'package:http/http.dart' as http;

/// 🌤️ Weather Service - Open-Meteo ECMWF API
/// Najtačnija besplatna prognoza za Evropu!
/// - Koristi ECMWF model (zlatni standard za Evropu)
/// - Bez registracije, bez API key-a, bez limita
/// - Isti podaci kao premium servisi (Weather & Radar itd.)
/// - Podrška za vremenska upozorenja (alerts) 🚨
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

  // Alert cache - odvojeno za BC i VS
  static WeatherAlert? _cachedAlertBC;
  static WeatherAlert? _cachedAlertVS;
  static DateTime? _alertCacheTimeBC;
  static DateTime? _alertCacheTimeVS;
  static const Duration _alertCacheDuration = Duration(minutes: 15);

  /// WMO Weather interpretation codes -> naši uslovi
  /// https://open-meteo.com/en/docs
  static String _wmoCodeToCondition(int code) {
    // 0: Clear sky
    if (code == 0) {
      // 🌙 Proveri da li je noć (pre 6:00 ili posle 18:00)
      final hour = DateTime.now().hour;
      if (hour < 6 || hour >= 18) {
        return 'night'; // Noću prikaži mesec i zvezde
      }
      return 'sunny';
    }

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
    // Keširani podaci - dostupni i u catch bloku
    final cachedWeather = locationKey == 'BC' ? _cachedWeatherBC : _cachedWeatherVS;
    final cacheTime = locationKey == 'BC' ? _cacheTimeBC : _cacheTimeVS;

    try {
      if (cachedWeather != null && cacheTime != null) {
        final elapsed = DateTime.now().difference(cacheTime);
        if (elapsed < _cacheDuration) {
          return cachedWeather;
        }
      }

      // Open-Meteo API poziv - koristi ECMWF model
      final url = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
          '&timezone=Europe/Belgrade');

      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
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

        return weather;
      } else {
        // 🔧 FIX: Vrati keširane podatke ako API ne radi
        if (cachedWeather != null) return cachedWeather;
        return {};
      }
    } catch (e) {
      // 🔧 FIX: Vrati keširane podatke na greški
      if (cachedWeather != null) return cachedWeather;
      return {};
    }
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
      return {};
    }
  }

  /// Vraća Lottie asset path za dati uslov
  static String getLottieAsset(String condition) {
    switch (condition) {
      case 'sunny':
        return 'assets/weather/sunny.json';
      case 'night':
        return 'assets/weather/night.json';
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 📅 HOURLY FORECAST - Prognoza po satima za ceo dan
  // ═══════════════════════════════════════════════════════════════════════════

  // Cache za satnu prognozu
  static Map<String, dynamic>? _cachedHourlyBC;
  static Map<String, dynamic>? _cachedHourlyVS;
  static DateTime? _hourlyTimeBC;
  static DateTime? _hourlyTimeVS;
  static const Duration _hourlyCacheDuration = Duration(minutes: 30);

  /// Dohvata satnu prognozu za Belu Crkvu
  static Future<List<Map<String, dynamic>>> getHourlyForecastBC() async {
    return _getHourlyForecast(bcLat, bcLon, 'BC');
  }

  /// Dohvata satnu prognozu za Vršac
  static Future<List<Map<String, dynamic>>> getHourlyForecastVS() async {
    return _getHourlyForecast(vsLat, vsLon, 'VS');
  }

  /// Dohvata satnu prognozu - vraća listu sati za danas
  static Future<List<Map<String, dynamic>>> _getHourlyForecast(
    double lat,
    double lon,
    String locationKey,
  ) async {
    final cachedHourly = locationKey == 'BC' ? _cachedHourlyBC : _cachedHourlyVS;
    final cacheTime = locationKey == 'BC' ? _hourlyTimeBC : _hourlyTimeVS;

    try {
      if (cachedHourly != null && cacheTime != null) {
        final elapsed = DateTime.now().difference(cacheTime);
        if (elapsed < _hourlyCacheDuration) {
          return List<Map<String, dynamic>>.from(cachedHourly['hours'] ?? []);
        }
      }

      // Open-Meteo API sa satnom prognozom
      final url = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon'
          '&hourly=temperature_2m,weather_code,precipitation_probability'
          '&timezone=Europe/Belgrade'
          '&forecast_days=1'
          '&models=ecmwf_ifs025');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hours = _parseHourlyData(data);

        // Cache
        if (locationKey == 'BC') {
          _cachedHourlyBC = {'hours': hours};
          _hourlyTimeBC = DateTime.now();
        } else {
          _cachedHourlyVS = {'hours': hours};
          _hourlyTimeVS = DateTime.now();
        }

        return hours;
      } else {
        if (cachedHourly != null) return List<Map<String, dynamic>>.from(cachedHourly['hours'] ?? []);
        return [];
      }
    } catch (e) {
      if (cachedHourly != null) return List<Map<String, dynamic>>.from(cachedHourly['hours'] ?? []);
      return [];
    }
  }

  /// Parsira satne podatke
  static List<Map<String, dynamic>> _parseHourlyData(Map<String, dynamic> data) {
    try {
      final hourly = data['hourly'] ?? {};
      final times = List<String>.from(hourly['time'] ?? []);
      final temps = List<num>.from(hourly['temperature_2m'] ?? []);
      final codes = List<int>.from(hourly['weather_code'] ?? []);
      final precip = List<num>.from(hourly['precipitation_probability'] ?? []);

      final now = DateTime.now();
      final List<Map<String, dynamic>> result = [];

      for (int i = 0; i < times.length; i++) {
        final time = DateTime.parse(times[i]);
        // Samo budući sati i prošli sat (za kontekst)
        if (time.hour >= now.hour - 1) {
          result.add({
            'hour': time.hour,
            'temp': temps[i].round(),
            'condition': _wmoCodeToCondition(codes[i]),
            'description': _wmoCodeToDescription(codes[i]),
            'precipProb': precip[i].round(),
          });
        }
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚨 WEATHER ALERTS - Upozorenja za ekstremne vremenske uslove
  // ═══════════════════════════════════════════════════════════════════════════

  /// Provera da li postoji opasan vremenski uslov na osnovu WMO koda i drugih faktora
  /// Koristi: temperature, vetar, padavine, visibility
  static Future<WeatherAlert?> getAlertBC() async {
    return _getAlertForLocation(bcLat, bcLon, 'BC');
  }

  static Future<WeatherAlert?> getAlertVS() async {
    return _getAlertForLocation(vsLat, vsLon, 'VS');
  }

  /// Dohvata sve aktivne alerte za obe lokacije
  static Future<List<WeatherAlert>> getAllAlerts() async {
    final results = await Future.wait([
      getAlertBC(),
      getAlertVS(),
    ]);
    return results.whereType<WeatherAlert>().toList();
  }

  static Future<WeatherAlert?> _getAlertForLocation(
    double lat,
    double lon,
    String locationKey,
  ) async {
    try {
      // Proveri alert cache
      final cachedAlert = locationKey == 'BC' ? _cachedAlertBC : _cachedAlertVS;
      final cacheTime = locationKey == 'BC' ? _alertCacheTimeBC : _alertCacheTimeVS;

      if (cachedAlert != null && cacheTime != null) {
        final elapsed = DateTime.now().difference(cacheTime);
        if (elapsed < _alertCacheDuration) {
          return cachedAlert.severity != AlertSeverity.none ? cachedAlert : null;
        }
      }

      // Dohvati detaljnije podatke za alert analizu
      final url = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,weather_code,wind_speed_10m,wind_gusts_10m'
          '&hourly=temperature_2m,precipitation_probability,precipitation,visibility,weather_code'
          '&forecast_days=1'
          '&timezone=Europe/Belgrade'
          '&models=ecmwf_ifs025');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alert = _analyzeWeatherForAlert(data, locationKey);

        // Cache rezultat
        if (locationKey == 'BC') {
          _cachedAlertBC = alert;
          _alertCacheTimeBC = DateTime.now();
        } else {
          _cachedAlertVS = alert;
          _alertCacheTimeVS = DateTime.now();
        }

        if (alert.severity != AlertSeverity.none) {
          return alert;
        }
        return null;
      }
    } catch (e) {
      // Error checking alert
    }
    return null;
  }

  /// Analizira vremenske podatke i generiše alert ako je potrebno
  static WeatherAlert _analyzeWeatherForAlert(Map<String, dynamic> data, String locationKey) {
    try {
      final current = data['current'] ?? {};
      final hourly = data['hourly'] ?? {};

      final weatherCode = (current['weather_code'] ?? 0) as int;
      final temp = (current['temperature_2m'] ?? 15).toDouble();
      final windSpeed = (current['wind_speed_10m'] ?? 0).toDouble();
      final windGusts = (current['wind_gusts_10m'] ?? 0).toDouble();

      // Hourly data za narednih 12h
      final hourlyPrecip = (hourly['precipitation'] as List?)?.take(12).toList() ?? [];
      final hourlyVisibility = (hourly['visibility'] as List?)?.take(12).toList() ?? [];
      final hourlyWeatherCode = (hourly['weather_code'] as List?)?.take(12).toList() ?? [];

      final cityName = locationKey == 'BC' ? 'Bela Crkva' : 'Vršac';
      final alerts = <_AlertCandidate>[];

      // ═══════════════════════════════════════════════════════════════════════
      // 🌡️ EKSTREMNE TEMPERATURE
      // ═══════════════════════════════════════════════════════════════════════
      if (temp <= -10) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'EKSTREMNA HLADNOĆA',
          description:
              'Temperatura u $cityName je ${temp.round()}°C!\nOpasnost od smrzavanja. Obucite se toplo, proverite antifriz u vozilu.',
          icon: '🥶',
        ));
      } else if (temp <= -5) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.warning,
          title: 'Jak mraz',
          description: 'Temperatura u $cityName je ${temp.round()}°C.\nMogući problemi sa vozilom pri paljenju.',
          icon: '❄️',
        ));
      } else if (temp >= 38) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'EKSTREMNA VRUĆINA',
          description:
              'Temperatura u $cityName je ${temp.round()}°C!\nOpasnost od toplotnog udara. Pijte dosta tečnosti.',
          icon: '🔥',
        ));
      } else if (temp >= 35) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.warning,
          title: 'Velika vrućina',
          description: 'Temperatura u $cityName je ${temp.round()}°C.\nPreporučuje se izbegavanje direktnog sunca.',
          icon: '☀️',
        ));
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 💨 JAK VETAR
      // ═══════════════════════════════════════════════════════════════════════
      if (windGusts >= 90) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'ORKANSKI VETAR',
          description:
              'Udari vetra u $cityName do ${windGusts.round()} km/h!\nIzbegavajte vožnju, posebno mostove i otvorene puteve.',
          icon: '🌪️',
        ));
      } else if (windGusts >= 70 || windSpeed >= 50) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.warning,
          title: 'Olujni vetar',
          description: 'Vetar u $cityName do ${windGusts.round()} km/h.\nOprez pri vožnji, moguće grane na putu.',
          icon: '💨',
        ));
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ⛈️ NEVREME (thunderstorm codes: 95, 96, 99)
      // ═══════════════════════════════════════════════════════════════════════
      if (weatherCode >= 95) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'GRMLJAVINSKO NEVREME',
          description: 'Aktivno nevreme u $cityName!\nMogući grad i olujni vetar. Sklonite se na sigurno.',
          icon: '⛈️',
        ));
      }

      // Proveri da li dolazi nevreme u narednih 12h
      for (int i = 0; i < hourlyWeatherCode.length; i++) {
        final code = hourlyWeatherCode[i] as int? ?? 0;
        if (code >= 95 && weatherCode < 95) {
          // Nevreme dolazi, ali još nije tu
          alerts.add(_AlertCandidate(
            severity: AlertSeverity.warning,
            title: 'Nevreme na putu',
            description: 'Grmljavinsko nevreme očekuje se u $cityName za ~${i + 1}h.\nPlanirati vožnju na vreme.',
            icon: '⚡',
          ));
          break;
        }
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 🌧️ OBILNE PADAVINE
      // ═══════════════════════════════════════════════════════════════════════
      double maxPrecip = 0;
      for (final p in hourlyPrecip) {
        final val = (p as num?)?.toDouble() ?? 0;
        if (val > maxPrecip) maxPrecip = val;
      }

      if (maxPrecip >= 20) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'OBILNE PADAVINE',
          description: 'Očekuje se do ${maxPrecip.round()}mm padavina u $cityName!\nMogućnost poplava i bujica.',
          icon: '🌊',
        ));
      } else if (maxPrecip >= 10) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.warning,
          title: 'Jače padavine',
          description: 'Očekuje se do ${maxPrecip.round()}mm padavina u $cityName.\nSmanjena vidljivost, klizav put.',
          icon: '🌧️',
        ));
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 🌫️ LOŠA VIDLJIVOST (magla)
      // ═══════════════════════════════════════════════════════════════════════
      double minVisibility = double.infinity;
      for (final v in hourlyVisibility) {
        final val = (v as num?)?.toDouble() ?? 10000;
        if (val < minVisibility) minVisibility = val;
      }

      if (minVisibility < 100) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'GUSTA MAGLA',
          description: 'Vidljivost u $cityName ispod 100m!\nVožnja izuzetno opasna, odložite putovanje.',
          icon: '🌫️',
        ));
      } else if (minVisibility < 500) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.warning,
          title: 'Magla',
          description:
              'Smanjena vidljivost u $cityName (~${minVisibility.round()}m).\nVozite polako, uključite svetla.',
          icon: '🌁',
        ));
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 🧊 POLEDICA (rain when temp near freezing)
      // ═══════════════════════════════════════════════════════════════════════
      if (temp >= -2 && temp <= 3 && (weatherCode >= 51 && weatherCode <= 67)) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'POLEDICA',
          description: 'Kiša pri temperaturi ${temp.round()}°C u $cityName!\nOpasnost od poledice, put klizav.',
          icon: '🧊',
        ));
      }

      // ═══════════════════════════════════════════════════════════════════════
      // ❄️ SNEŽNA MEĆAVA
      // ═══════════════════════════════════════════════════════════════════════
      bool hasHeavySnow = weatherCode == 75 || weatherCode == 86;
      if (hasHeavySnow && windSpeed >= 30) {
        alerts.add(_AlertCandidate(
          severity: AlertSeverity.severe,
          title: 'SNEŽNA MEĆAVA',
          description: 'Jak sneg i vetar u $cityName!\nVidljivost smanjena, putevi neprohodni.',
          icon: '🌨️',
        ));
      }

      // Izaberi najozbiljniji alert
      if (alerts.isEmpty) {
        return WeatherAlert(
          severity: AlertSeverity.none,
          title: '',
          description: '',
          icon: '',
          location: cityName,
        );
      }

      // Sortiraj po ozbiljnosti i vrati najozbiljniji
      alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
      final worst = alerts.first;

      return WeatherAlert(
        severity: worst.severity,
        title: worst.title,
        description: worst.description,
        icon: worst.icon,
        location: cityName,
      );
    } catch (e) {
      return WeatherAlert(
        severity: AlertSeverity.none,
        title: '',
        description: '',
        icon: '',
        location: locationKey == 'BC' ? 'Bela Crkva' : 'Vršac',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🚨 WEATHER ALERT MODEL
// ═══════════════════════════════════════════════════════════════════════════

/// Nivo ozbiljnosti alerta
enum AlertSeverity {
  none, // Nema alerta
  warning, // Upozorenje (žuta)
  severe, // Ozbiljno upozorenje (crvena)
}

/// Model za vremensko upozorenje
class WeatherAlert {
  final AlertSeverity severity;
  final String title;
  final String description;
  final String icon;
  final String location;

  const WeatherAlert({
    required this.severity,
    required this.title,
    required this.description,
    required this.icon,
    required this.location,
  });
}

/// Interni helper za kandidate alertova
class _AlertCandidate {
  final AlertSeverity severity;
  final String title;
  final String description;
  final String icon;

  const _AlertCandidate({
    required this.severity,
    required this.title,
    required this.description,
    required this.icon,
  });
}
