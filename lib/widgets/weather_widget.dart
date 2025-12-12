import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/weather_service.dart';

/// Lokacija za weather widget
enum WeatherLocation { belaCrkva, vrsac }

/// 🌤️ Animated Weather Widget za AppBar
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
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final data = widget.location == WeatherLocation.belaCrkva
          ? await WeatherService.getWeatherBC()
          : await WeatherService.getWeatherVS();
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      );
    }

    final condition = _weatherData?['condition'] ?? 'sunny';
    final assetPath = WeatherService.getLottieAsset(condition);

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

  void _showWeatherDetails(BuildContext context) {
    if (_weatherData == null) return;

    final temp = _weatherData!['temp'];
    final description = _weatherData!['description'];
    final humidity = _weatherData!['humidity'];
    final windSpeed = _weatherData!['windSpeed'];
    final cityName = widget.location == WeatherLocation.belaCrkva ? 'Bela Crkva' : 'Vršac';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                WeatherService.getLottieAsset(_weatherData!['condition']),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.wb_cloudy, 'Stanje', description),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.water_drop, 'Vlažnost', '$humidity%'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.air, 'Vetar', '$windSpeed km/h'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadWeather(); // Refresh
            },
            child: const Text('OSVEŽI', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
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
