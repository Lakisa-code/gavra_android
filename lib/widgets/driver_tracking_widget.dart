import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/driver_location_service.dart';

/// 🚐 Widget za praćenje lokacije kombija od strane mesečnih putnika
/// Prikazuje mapu sa lokacijom kombija i ETA
class DriverTrackingWidget extends StatefulWidget {
  const DriverTrackingWidget({
    Key? key,
    required this.grad,
    required this.vremePolaska,
    required this.smer, // BC_VS ili VS_BC
    required this.putnikLat,
    required this.putnikLng,
    required this.putnikAdresa,
    this.onDriverArrived,
  }) : super(key: key);

  final String grad;
  final String vremePolaska;
  final String smer; // BC_VS = Bela Crkva -> Vršac, VS_BC = Vršac -> Bela Crkva
  final double putnikLat;
  final double putnikLng;
  final String putnikAdresa;
  final VoidCallback? onDriverArrived;

  @override
  State<DriverTrackingWidget> createState() => _DriverTrackingWidgetState();
}

class _DriverTrackingWidgetState extends State<DriverTrackingWidget> {
  StreamSubscription<Map<String, dynamic>?>? _locationSubscription;
  Map<String, dynamic>? _driverLocation;
  bool _isLoading = true;
  String? _errorMessage;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startListening() {
    _locationSubscription = DriverLocationService.streamDriverLocation(
      grad: widget.grad,
      vremePolaska: widget.vremePolaska,
      smer: widget.smer,
    ).listen(
      (location) {
        if (mounted) {
          setState(() {
            _driverLocation = location;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Greška pri učitavanju lokacije';
          });
        }
      },
    );
  }

  /// Izračunaj ETA na osnovu udaljenosti (prosečna brzina 40 km/h u gradu)
  String _calculateETA() {
    if (_driverLocation == null) return '--';

    final driverLat = _driverLocation!['lat'] as double?;
    final driverLng = _driverLocation!['lng'] as double?;

    if (driverLat == null || driverLng == null) return '--';

    // Haversine formula za udaljenost
    final distance = _calculateDistance(
      driverLat,
      driverLng,
      widget.putnikLat,
      widget.putnikLng,
    );

    // Prosečna brzina 40 km/h = 0.67 km/min
    final etaMinutes = (distance / 0.67).round();

    if (etaMinutes < 1) return '< 1 min';
    if (etaMinutes == 1) return '~1 minut';
    if (etaMinutes < 5) return '~$etaMinutes minuta';
    return '~$etaMinutes min';
  }

  /// Haversine formula za izračunavanje udaljenosti između dve tačke
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radius Zemlje u km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🚐 Praćenje kombija',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Polazak: ${widget.vremePolaska} • ${widget.grad}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sadržaj
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_driverLocation == null || _driverLocation!['aktivan'] != true)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vozač još nije krenuo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Praćenje počinje kada vozač aktivira rutu',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildActiveTracking(),
        ],
      ),
    );
  }

  Widget _buildActiveTracking() {
    final driverLat = _driverLocation!['lat'] as double;
    final driverLng = _driverLocation!['lng'] as double;
    final vozacIme = _driverLocation!['vozac_ime'] as String? ?? 'Vozač';
    final eta = _calculateETA();

    return Column(
      children: [
        // ETA Info
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ETA
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.access_time, color: Colors.greenAccent, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        eta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'do dolaska',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Vozač info
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person, color: Colors.lightBlueAccent, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        vozacIme,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'vozač',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Mapa
        Container(
          height: 200,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (driverLat + widget.putnikLat) / 2,
                (driverLng + widget.putnikLng) / 2,
              ),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gavra013.gavra_android',
              ),
              MarkerLayer(
                markers: [
                  // Marker za vozača (kombi)
                  Marker(
                    point: LatLng(driverLat, driverLng),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  // Marker za putnika (kuća)
                  Marker(
                    point: LatLng(widget.putnikLat, widget.putnikLng),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              // Linija između vozača i putnika
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(driverLat, driverLng),
                      LatLng(widget.putnikLat, widget.putnikLng),
                    ],
                    color: Colors.blue.withValues(alpha: 0.7),
                    strokeWidth: 3,
                    pattern: StrokePattern.dotted(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Adresa putnika
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.green.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vaša lokacija: ${widget.putnikAdresa}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
