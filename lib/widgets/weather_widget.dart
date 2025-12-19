import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/weather_service.dart';

/// Lokacija za weather widget
enum WeatherLocation { belaCrkva, vrsac }

/// Animated Weather Widget za AppBar
/// Prikazuje Lottie animaciju trenutnog vremena za BC ili VS
class WeatherWidget extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final WeatherLocation location;

  const WeatherWidget({
    super.key,
    this.size = 40,
    this.onTap,
    this.location = WeatherLocation.belaCrkva,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String _condition = 'cloudy';
  Map<String, dynamic> _weatherData = {};
  WeatherAlert? _alert;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (_isLoaded) return; // Učitaj samo jednom

    try {
      final weather = widget.location == WeatherLocation.belaCrkva
          ? await WeatherService.getWeatherBC()
          : await WeatherService.getWeatherVS();

      final alert = widget.location == WeatherLocation.belaCrkva
          ? await WeatherService.getAlertBC()
          : await WeatherService.getAlertVS();

      if (mounted) {
        setState(() {
          _condition = weather['condition'] ?? 'cloudy';
          _weatherData = weather.isNotEmpty
              ? weather
              : {
                  'condition': 'cloudy',
                  'temp': '--',
                  'description': 'Nije dostupno',
                  'humidity': '--',
                  'windSpeed': '--',
                };
          _alert = alert;
          _isLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _condition = 'cloudy';
          _weatherData = {
            'condition': 'cloudy',
            'temp': '--',
            'description': 'Greška',
            'humidity': '--',
            'windSpeed': '--',
          };
          _isLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = WeatherService.getLottieAsset(_condition);

    return GestureDetector(
      onTap: widget.onTap ?? () => _showWeatherDetails(context),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }

  /// 🔄 Force refresh - ponovo učitava
  Future<void> _forceRefresh() async {
    setState(() => _isLoaded = false);
    await _loadWeather();
  }

  void _showWeatherDetails(BuildContext context) {
    final temp = _weatherData['temp'] ?? '--';
    final description = _weatherData['description'] ?? 'Učitavanje...';
    final humidity = _weatherData['humidity'] ?? '--';
    final windSpeed = _weatherData['windSpeed'] ?? '--';
    final cityName = widget.location == WeatherLocation.belaCrkva ? 'Bela Crkva' : 'Vršac';

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.location == WeatherLocation.belaCrkva
            ? WeatherService.getHourlyForecastBC()
            : WeatherService.getHourlyForecastVS(),
        builder: (context, snapshot) {
          final hourlyForecast = snapshot.data ?? [];

          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Lottie.asset(
                    WeatherService.getLottieAsset(_weatherData['condition'] ?? 'cloudy'),
                    repeat: true,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.wb_cloudy, 'Stanje', description),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.water_drop, 'Vlažnost', '$humidity%'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.air, 'Vetar', '$windSpeed km/h'),

                  // 📅 SATNA PROGNOZA ZA DANAS
                  if (hourlyForecast.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    const Text(
                      '📅 Prognoza za danas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHourlyForecast(hourlyForecast),
                  ],

                  // Prikaži alert ako postoji
                  if (_alert != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    _buildAlertSection(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _forceRefresh(); // Refresh
                },
                child: const Text('OSVEŽI', style: TextStyle(color: Colors.blue)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 📅 Satna prognoza widget
  Widget _buildHourlyForecast(List<Map<String, dynamic>> hours) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length > 12 ? 12 : hours.length, // Max 12 sati
        itemBuilder: (context, index) {
          final hour = hours[index];
          final hourNum = hour['hour'] as int;
          final temp = hour['temp'];
          final condition = hour['condition'] as String;
          final precipProb = hour['precipProb'] as int;
          final isNow = hourNum == DateTime.now().hour;

          return Container(
            width: 60,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isNow ? Colors.blue.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: isNow ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  isNow ? 'Sad' : '${hourNum}h',
                  style: TextStyle(
                    color: isNow ? Colors.blue.shade200 : Colors.white70,
                    fontSize: 12,
                    fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Lottie.asset(
                    WeatherService.getLottieAsset(condition),
                    repeat: true,
                  ),
                ),
                Text(
                  '$temp°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (precipProb > 0)
                  Text(
                    '💧$precipProb%',
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertSection() {
    if (_alert == null) return const SizedBox.shrink();

    final isSevere = _alert!.severity == AlertSeverity.severe;
    final bgColor = isSevere ? Colors.red.shade900 : Colors.orange.shade900;
    final borderColor = isSevere ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _alert!.icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _alert!.title,
                  style: TextStyle(
                    color: isSevere ? Colors.red.shade100 : Colors.orange.shade100,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _alert!.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
