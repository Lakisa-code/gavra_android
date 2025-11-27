import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/gps_manager.dart';
import '../services/offline_map_service.dart';
import '../theme.dart';
import '../widgets/custom_back_button.dart';

class GpsMapaScreen extends StatefulWidget {
  const GpsMapaScreen({Key? key}) : super(key: key);

  @override
  State<GpsMapaScreen> createState() => _GpsMapaScreenState();
}

class _GpsMapaScreenState extends State<GpsMapaScreen> {
  final GpsManager _gps = GpsManager.instance;
  Position? _currentPosition;
  double _speed = 0.0;
  bool _isTracking = false;
  String _statusMessage = 'Pritisni START za GPS praćenje';
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _speedSubscription;

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _speedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    final hasPermission = await _gps.ensurePermissions();
    if (!hasPermission && mounted) {
      setState(() {
        _statusMessage = '⚠️ GPS dozvole nisu odobrene';
      });
    }
  }

  Future<void> _startTracking() async {
    final started = await _gps.startTracking();
    if (!started) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Nije moguće pokrenuti GPS';
        });
      }
      return;
    }

    _positionSubscription = _gps.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _statusMessage = '📍 ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }
    });

    _speedSubscription = _gps.speedStream.listen((speed) {
      if (mounted) {
        setState(() {
          _speed = speed;
        });
      }
    });

    if (mounted) {
      setState(() {
        _isTracking = true;
        _statusMessage = '🛰️ GPS praćenje aktivno...';
      });
    }
  }

  Future<void> _stopTracking() async {
    await _gps.stopTracking();
    _positionSubscription?.cancel();
    _speedSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isTracking = false;
        _statusMessage = 'GPS praćenje zaustavljeno';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const GradientBackButton(),
          title: const Text(
            'GPS Mapa',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // 🗺️ MAPA
            Expanded(
              child: _currentPosition != null
                  ? OfflineMapService.buildOfflineMap(
                      center: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      markers: [
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ],
                      zoom: 15.0,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // 📊 INFO PANEL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).glassContainer,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).glassBorder,
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Speedometer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoCard(
                        icon: Icons.speed,
                        value: '${_speed.toStringAsFixed(0)} km/h',
                        label: 'Brzina',
                        color: _speed >= 90
                            ? Colors.red
                            : _speed >= 60
                                ? Colors.orange
                                : Colors.green,
                      ),
                      _buildInfoCard(
                        icon: Icons.location_on,
                        value: _currentPosition != null ? '${_currentPosition!.accuracy.toStringAsFixed(0)}m' : '--',
                        label: 'Preciznost',
                        color: Colors.blue,
                      ),
                      _buildInfoCard(
                        icon: Icons.satellite_alt,
                        value: _isTracking ? 'ON' : 'OFF',
                        label: 'GPS',
                        color: _isTracking ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start/Stop dugme
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(_isTracking ? 'STOP' : 'START'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
