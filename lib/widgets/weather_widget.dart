import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/weather_service.dart';

/// Lokacija za weather widget
enum WeatherLocation { belaCrkva, vrsac }

/// 🌤️ Animated Weather Widget za AppBar
/// Prikazuje Lottie animaciju trenutnog vremena za BC ili VS
/// 🚨 Trepće kad ima vremensko upozorenje!
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

class _WeatherWidgetState extends State<WeatherWidget> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _weatherData;
  WeatherAlert? _alert;
  bool _isLoading = true;

  // 🚨 Animacija za trepćenje
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Setup blink animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _loadWeather();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    try {
      // Učitaj vreme i alerte paralelno
      final weatherFuture =
          widget.location == WeatherLocation.belaCrkva ? WeatherService.getWeatherBC() : WeatherService.getWeatherVS();

      final alertFuture =
          widget.location == WeatherLocation.belaCrkva ? WeatherService.getAlertBC() : WeatherService.getAlertVS();

      final results = await Future.wait([weatherFuture, alertFuture]);

      if (mounted) {
        setState(() {
          _weatherData = results[0] as Map<String, dynamic>;
          _alert = results[1] as WeatherAlert?;
          _isLoading = false;
        });

        // Pokreni trepćenje ako ima alert
        if (_alert != null) {
          _blinkController.repeat(reverse: true);
        } else {
          _blinkController.stop();
          _blinkController.value = 0; // Reset to full opacity
        }
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
    final hasAlert = _alert != null;

    Widget weatherIcon = Lottie.asset(
      assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      repeat: true,
    );

    // 🚨 Ako ima alert, dodaj trepćenje i warning overlay
    if (hasAlert) {
      weatherIcon = AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Osnovna weather ikona sa trepćenjem
              Opacity(
                opacity: _blinkAnimation.value,
                child: child,
              ),
              // Mali warning indikator u uglu
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    color: _alert!.severity == AlertSeverity.severe ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.size * 0.25,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: weatherIcon,
      );
    }

    return GestureDetector(
      onTap: widget.onTap ?? () => _showWeatherDetails(context),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: weatherIcon,
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
            // 🚨 Prikaži alert ako postoji
            if (_alert != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _buildAlertSection(),
            ],
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
