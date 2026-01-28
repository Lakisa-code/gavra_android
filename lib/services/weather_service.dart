import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model za vremensku prognozu
class WeatherData {
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final String icon;
  // Dnevna prognoza
  final double? tempMin;
  final double? tempMax;
  final double? precipitationSum; // mm padavina
  final int? precipitationProbability; // procenat verovatnoće padavina (0-100%)
  final int? dailyWeatherCode;
  // Sat kad počinju padavine
  final String? precipitationStartTime;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.icon,
    this.tempMin,
    this.tempMax,
    this.precipitationSum,
    this.precipitationProbability,
    this.dailyWeatherCode,
    this.precipitationStartTime,
  });

  /// Da li se očekuje kiša danas
  bool get willRain =>
      (precipitationSum ?? 0) > 0.5 || (dailyWeatherCode != null && dailyWeatherCode! >= 51 && dailyWeatherCode! <= 82);

  /// Da li se očekuje sneg danas
  bool get willSnow => (dailyWeatherCode != null &&
      ((dailyWeatherCode! >= 71 && dailyWeatherCode! <= 77) || (dailyWeatherCode! >= 85 && dailyWeatherCode! <= 86)));

  /// Konvertuj weather code u ikonu (sa dan/noć podrškom)
  /// Za maglu vraća 'FOG_ASSET' da bi UI mogao da prikaže sliku
  static String getIconForCode(int code, {bool isDay = true}) {
    // WMO Weather interpretation codes
    // https://open-meteo.com/en/docs
    if (code == 0) return isDay ? '☀️' : '🌙'; // Clear sky
    if (code == 1) return isDay ? '🌤️' : '🌙'; // Mainly clear
    if (code == 2) return isDay ? '⛅' : '☁️'; // Partly cloudy
    if (code == 3) return '☁️'; // Overcast
    if (code >= 45 && code <= 48) return 'FOG_ASSET'; // Fog - koristi sliku
    if (code >= 51 && code <= 55) return '🌧️'; // Drizzle
    if (code >= 56 && code <= 57) return '🌧️❄️'; // Freezing drizzle
    if (code >= 61 && code <= 65) return '🌧️'; // Rain
    if (code >= 66 && code <= 67) return '🌧️❄️'; // Freezing rain
    if (code >= 71 && code <= 77) return '❄️'; // Snow
    if (code >= 80 && code <= 82) return '🌧️'; // Rain showers
    if (code >= 85 && code <= 86) return '❄️'; // Snow showers
    if (code >= 95 && code <= 99) return '⛈️'; // Thunderstorm
    return '🌡️'; // Default
  }

  /// Da li ikona treba da bude asset slika
  static bool isAssetIcon(String icon) => icon == 'FOG_ASSET';

  /// Vrati putanju do asset slike
  static String getAssetPath(String icon) {
    if (icon == 'FOG_ASSET') return 'assets/weather/fog.png';
    return '';
  }
}

/// Servis za vremensku prognozu koristeći Open-Meteo API (besplatan, bez API ključa)
class WeatherService {
  // Koordinate gradova
  static const Map<String, Map<String, double>> _gradKoordinate = {
    'BC': {'lat': 44.8989, 'lon': 21.4181}, // Bela Crkva
    'VS': {'lat': 45.1167, 'lon': 21.3036}, // Vršac
  };

  // Cache za podatke (osvežava se svakih 15 minuta)
  static final Map<String, WeatherData?> _dataCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const _cacheDuration = Duration(minutes: 15);

  // Stream controlleri za real-time temperature
  static final _bcController = StreamController<WeatherData?>.broadcast();
  static final _vsController = StreamController<WeatherData?>.broadcast();

  /// Stream za BC - odmah emituje cached vrednost ako postoji
  static Stream<WeatherData?> get bcWeatherStream async* {
    // Prvo emituj cached vrednost ako postoji
    if (_dataCache.containsKey('BC')) {
      yield _dataCache['BC'];
    }
    // Zatim slušaj nove podatke
    yield* _bcController.stream;
  }

  /// Stream za VS - odmah emituje cached vrednost ako postoji
  static Stream<WeatherData?> get vsWeatherStream async* {
    // Prvo emituj cached vrednost ako postoji
    if (_dataCache.containsKey('VS')) {
      yield _dataCache['VS'];
    }
    // Zatim slušaj nove podatke
    yield* _vsController.stream;
  }

  /// Dohvati trenutnu temperaturu za grad (legacy - za kompatibilnost)
  static Future<double?> getTemperature(String grad) async {
    final data = await getWeatherData(grad);
    return data?.temperature;
  }

  /// Dohvati kompletne vremenske podatke za grad
  static Future<WeatherData?> getWeatherData(String grad) async {
    // Proveri cache
    if (_dataCache.containsKey(grad) &&
        _cacheTime.containsKey(grad) &&
        DateTime.now().difference(_cacheTime[grad]!) < _cacheDuration) {
      return _dataCache[grad];
    }

    try {
      final coords = _gradKoordinate[grad];
      if (coords == null) return null;

      // Open-Meteo API - besplatan, bez ključa
      // Dodato is_day za razlikovanje dan/noć ikona + daily za prognozu dana + hourly za vreme padavina
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=${coords['lat']}&longitude=${coords['lon']}'
        '&current=temperature_2m,weather_code,is_day'
        '&daily=temperature_2m_min,temperature_2m_max,precipitation_sum,precipitation_probability_max,weather_code'
        '&hourly=weather_code'
        '&timezone=Europe/Belgrade'
        '&forecast_days=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = (data['current']['temperature_2m'] as num).toDouble();
        final code = (data['current']['weather_code'] as num).toInt();
        final isDay = (data['current']['is_day'] as num).toInt() == 1;

        // Dnevni podaci
        double? tempMin;
        double? tempMax;
        double? precipSum;
        int? precipProb;
        int? dailyCode;
        String? precipStartTime;

        if (data['daily'] != null) {
          final daily = data['daily'];
          if (daily['temperature_2m_min'] != null && (daily['temperature_2m_min'] as List).isNotEmpty) {
            tempMin = (daily['temperature_2m_min'][0] as num?)?.toDouble();
          }
          if (daily['temperature_2m_max'] != null && (daily['temperature_2m_max'] as List).isNotEmpty) {
            tempMax = (daily['temperature_2m_max'][0] as num?)?.toDouble();
          }
          if (daily['precipitation_sum'] != null && (daily['precipitation_sum'] as List).isNotEmpty) {
            precipSum = (daily['precipitation_sum'][0] as num?)?.toDouble();
          }
          if (daily['precipitation_probability_max'] != null &&
              (daily['precipitation_probability_max'] as List).isNotEmpty) {
            precipProb = (daily['precipitation_probability_max'][0] as num?)?.toInt();
          }
          if (daily['weather_code'] != null && (daily['weather_code'] as List).isNotEmpty) {
            dailyCode = (daily['weather_code'][0] as num?)?.toInt();
          }
        }

        // Nađi prvi sat sa padavinama (kiša: 51-82, sneg: 71-77, 85-86)
        if (data['hourly'] != null && data['hourly']['weather_code'] != null && data['hourly']['time'] != null) {
          final hourlyTimes = data['hourly']['time'] as List;
          final hourlyCodes = data['hourly']['weather_code'] as List;
          final now = DateTime.now();

          for (int i = 0; i < hourlyCodes.length && i < hourlyTimes.length; i++) {
            final hourCode = (hourlyCodes[i] as num?)?.toInt() ?? 0;
            // Proveri da li je padavina (kiša ili sneg)
            final isPrecip = (hourCode >= 51 && hourCode <= 82) || (hourCode >= 85 && hourCode <= 86);
            if (isPrecip) {
              // Parsiraj vreme i proveri da li je u budućnosti
              try {
                final timeStr = hourlyTimes[i] as String;
                final hourTime = DateTime.parse(timeStr);
                if (hourTime.isAfter(now.subtract(const Duration(hours: 1)))) {
                  precipStartTime = '${hourTime.hour.toString().padLeft(2, '0')}:00';
                  break;
                }
              } catch (e) {
                debugPrint('⚠️ Error fetching weather: $e');
              }
            }
          }
        }

        final weatherData = WeatherData(
          temperature: temp,
          weatherCode: code,
          isDay: isDay,
          icon: WeatherData.getIconForCode(code, isDay: isDay),
          tempMin: tempMin,
          tempMax: tempMax,
          precipitationSum: precipSum,
          precipitationProbability: precipProb,
          dailyWeatherCode: dailyCode,
          precipitationStartTime: precipStartTime,
        );

        // Sačuvaj u cache
        _dataCache[grad] = weatherData;
        _cacheTime[grad] = DateTime.now();

        // Emituj na stream
        if (grad == 'BC') {
          _bcController.add(weatherData);
        } else if (grad == 'VS') {
          _vsController.add(weatherData);
        }

        return weatherData;
      }
    } catch (e) {
      // Greška - vrati cached vrednost ako postoji
      return _dataCache[grad];
    }

    return null;
  }

  /// Osveži podatke za oba grada
  static Future<void> refreshAll() async {
    await Future.wait([
      getWeatherData('BC'),
      getWeatherData('VS'),
    ]);
  }

  /// Pokreni periodično osvežavanje (svakih 15 min)
  static Timer? _refreshTimer;

  static void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    refreshAll(); // Odmah učitaj
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      refreshAll();
    });
  }

  static void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Cleanup
  static void dispose() {
    stopPeriodicRefresh();
    _bcController.close();
    _vsController.close();
  }
}
