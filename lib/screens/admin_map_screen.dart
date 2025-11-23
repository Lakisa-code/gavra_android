import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gps_lokacija.dart';
import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final MapController _mapController = MapController();
  List<GPSLokacija> _gpsLokacije = [];
  List<Putnik> _putnici = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showDrivers = true;
  bool _showPassengers = false;
  List<Marker> _markers = [];
  DateTime? _lastGpsLoad;
  DateTime? _lastPutniciLoad;
  static const cacheDuration = Duration(seconds: 30);

  // V3.0 Clean Monitoring - realtime streams za admin bez heartbeat
  StreamSubscription<List<Map<String, dynamic>>>? _gpsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _putnikSubscription;

  // Početna pozicija - Bela Crkva/Vršac region
  static const LatLng _initialCenter = LatLng(44.9, 21.4);

  @override
  void initState() {
    super.initState();
    _initializeRealtimeMonitoring(); // V3.0 Clean monitoring
    _getCurrentLocation();
    _loadGpsLokacije(); // Fallback
    _loadPutnici(); // Fallback
  }

  // V3.0 Clean - Setup realtime monitoring with resilience
  void _initializeRealtimeMonitoring() {
    // GPS Realtime Stream with error recovery
    _gpsSubscription =
        Supabase.instance.client.from('gps_lokacije').stream(primaryKey: ['id']).order('timestamp').listen(
              (data) {
                if (mounted) {
                  try {
                    final gpsLokacije = data.map((json) => GPSLokacija.fromMap(json)).toList();
                    if (mounted)
                      setState(() {
                        _gpsLokacije = gpsLokacije;
                        _isLoading = false;
                        _updateMarkers();
                      });
                  } catch (e) {
// Fallback to cached data
                    if (_gpsLokacije.isEmpty) {
                      _loadGpsLokacije();
                    }
                  }
                }
              },
              onError: (Object error) {
// V3.0 Resilience - Auto retry after 5 seconds
                Timer(const Duration(seconds: 5), () {
                  if (mounted) {
                    _initializeRealtimeMonitoring();
                  }
                });
              },
            );

    // Putnik Realtime Stream with error recovery
    _putnikSubscription = Supabase.instance.client.from('putnik').stream(primaryKey: ['id']).listen(
      (data) {
        if (mounted) {
          try {
            final putnici = data.map((json) => Putnik.fromMap(json)).toList();
            if (mounted)
              setState(() {
                _putnici = putnici;
                _updateMarkers();
              });
          } catch (e) {
// Fallback to cached data
            if (_putnici.isEmpty) {
              _loadPutnici();
            }
          }
        }
      },
      onError: (Object error) {
// V3.0 Resilience - Auto retry after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _initializeRealtimeMonitoring();
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _putnikSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPutnici() async {
    // Proverava cache - ne učitava ponovo ako je prošlo manje od 30 sekundi
    if (_lastPutniciLoad != null && DateTime.now().difference(_lastPutniciLoad!) < cacheDuration) {
      return;
    }

    try {
      final putnikService = PutnikService();
      final putnici = await putnikService.getAllPutniciFromBothTables();
      if (mounted)
        setState(() {
          _putnici = putnici;
          _lastPutniciLoad = DateTime.now();
        });
      _updateMarkers();
    } catch (e) {}
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          // desiredAccuracy: deprecated, use settings parameter
          );

      if (mounted)
        setState(() {
          _currentPosition = position;
        });

      // Centriraj mapu na trenutnu poziciju
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        13.0,
      );
    } catch (e) {}
  }

  Future<void> _loadGpsLokacije() async {
    // Proverava cache - ne učitava ponovo ako je prošlo manje od 30 sekundi
    if (_lastGpsLoad != null && DateTime.now().difference(_lastGpsLoad!) < cacheDuration) {
      return;
    }

    try {
      if (mounted)
        setState(() {
          _isLoading = true;
        });

      // Prvo pokušaj da dobiješ strukturu tabele
      final response =
          await Supabase.instance.client.from('gps_lokacije').select().limit(10); // Uzmi samo 10 da vidimo strukturu
      final gpsLokacije = <GPSLokacija>[];
      for (final json in response as List<dynamic>) {
        try {
          gpsLokacije.add(GPSLokacija.fromMap(json as Map<String, dynamic>));
        } catch (e) {}
      }
      if (mounted)
        setState(() {
          _gpsLokacije = gpsLokacije;
          _lastGpsLoad = DateTime.now();
          _updateMarkers();
          _isLoading = false;
        });

      // Automatski fokusiraj na sve vozače nakon učitavanja
      if (_markers.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _fitAllMarkers();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _gpsLokacije = []; // Postavi praznu listu
          _isLoading = false;
        });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('GPS lokacije trenutno nisu dostupne'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Pokušaj ponovo',
              onPressed: () => _loadGpsLokacije(),
            ),
          ),
        );
      }
    }
  }

  void _updateMarkers() {
    List<Marker> markers = [];

    // VOZAČI - ako su uključeni
    if (_showDrivers) {
      // Grupiši GPS lokacije po vozaču i uzmi najnoviju za svakog
      Map<String, GPSLokacija> najnovijeLokacije = {};
      for (final lokacija in _gpsLokacije) {
        final vozacKey = lokacija.vozacId ?? 'nepoznat';
        if (!najnovijeLokacije.containsKey(vozacKey) || najnovijeLokacije[vozacKey]!.vreme.isBefore(lokacija.vreme)) {
          najnovijeLokacije[vozacKey] = lokacija;
        }
      }

      // Kreiraj markere za svakog vozača
      najnovijeLokacije.forEach((vozacId, lokacija) {
        markers.add(
          Marker(
            point: LatLng(lokacija.latitude, lokacija.longitude),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getDriverColor(lokacija),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 20,
                  ),
                  Text(
                    vozacId.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.fontSize(context, 12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });
    }

    // PUTNICI - ako su uključeni
    if (_showPassengers) {
      _addPassengerMarkers(markers);
    }

    if (mounted)
      setState(() {
        _markers = markers;
      });
  }

  Color _getDriverColor(GPSLokacija lokacija) {
    // Koristimo vozac_id umesto name
    final vozacId = lokacija.vozacId?.toLowerCase() ?? 'nepoznat';

    switch (vozacId) {
      case 'bojan':
        return const Color(0xFF00E5FF); // svetla cyan plava
      case 'svetlana':
        return const Color(0xFFFF1493); // deep pink
      case 'bruda':
        return const Color(0xFF7C4DFF); // ljubičasta
      case 'bilevski':
        return const Color(0xFFFF9800); // narandžasta
      case 'sasa':
        return const Color(0xFF9C27B0); // Ljubičasta
      case 'nikola':
        return const Color(0xFF4CAF50); // Zelena
      default:
        return const Color(0xFF607D8B); // Siva
    }
  }

  void _addPassengerMarkers(List<Marker> markers) {
    // Dodaj markere za putnike sa adresama (sync verzija)
    for (final putnik in _putnici) {
      if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) continue;

      // Za sada skip putničke markere jer zahtevaju async geocoding
      // Možemo dodati kasnije ako bude potrebno
    }
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty) return;

    // Izračunaj granice svih markera
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      if (marker.point.latitude < minLat) minLat = marker.point.latitude;
      if (marker.point.latitude > maxLat) maxLat = marker.point.latitude;
      if (marker.point.longitude < minLng) minLng = marker.point.longitude;
      if (marker.point.longitude > maxLng) maxLng = marker.point.longitude;
    }

    // Izračunaj centar i zoom za sve markere
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Jednostavan zoom na osnovu spread-a koordinata
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final zoom = latRange > 0.1 || lngRange > 0.1 ? 10.0 : 13.0;

    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
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
              // No boxShadow — keep AppBar fully transparent and only glass border
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    Expanded(
                      child: Text(
                        '🗺️ Admin GPS Mapa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 18),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 🚗 Vozači toggle
                    IconButton(
                      icon: Icon(
                        _showDrivers ? Icons.directions_car : Icons.directions_car_outlined,
                        color: _showDrivers ? Colors.white : Colors.white54,
                      ),
                      onPressed: () {
                        if (mounted)
                          setState(() {
                            _showDrivers = !_showDrivers;
                          });
                        _updateMarkers();
                      },
                      tooltip: _showDrivers ? 'Sakrij vozače' : 'Prikaži vozače',
                    ),
                    // 👥 Putnici toggle
                    IconButton(
                      icon: Icon(
                        _showPassengers ? Icons.people : Icons.people_outline,
                        color: _showPassengers ? Colors.white : Colors.white54,
                      ),
                      onPressed: () {
                        if (mounted)
                          setState(() {
                            _showPassengers = !_showPassengers;
                          });
                        _updateMarkers();
                      },
                      tooltip: _showPassengers ? 'Sakrij putnike' : 'Prikaži putnike',
                    ),
                    // 🔄 Refresh dugme
                    TextButton(
                      onPressed: () {
                        _loadGpsLokacije();
                        _loadPutnici();
                      },
                      child: const Text(
                        'Osveži',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // 🗺️ Zoom out dugme
                    IconButton(
                      icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                      onPressed: _fitAllMarkers,
                      tooltip: 'Prikaži sve vozače',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // 🗺️ OpenStreetMap sa flutter_map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : _initialCenter,
                minZoom: 8.0,
                maxZoom: 18.0,
              ),
              children: [
                // 🌍 OpenStreetMap tile layer - POTPUNO BESPLATNO!
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'rs.gavra.transport',
                  maxZoom: 19,
                ),
                // 📍 Markeri
                MarkerLayer(markers: _markers),
              ],
            ),
            // 📊 V3.0 Loading State - Elegant design
            if (_isLoading)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withValues(alpha: 0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '🗺️ Učitavam GPS podatke...',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 18),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Realtime monitoring aktiviran',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 📋 V3.0 Enhanced Legend
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.legend_toggle,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Legenda',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: Responsive.fontSize(context, 14),
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_showDrivers) ...[
                      _buildLegendItem(const Color(0xFF00E5FF), '🚗 Bojan'),
                      _buildLegendItem(const Color(0xFFFF1493), '🚗 Svetlana'),
                      _buildLegendItem(const Color(0xFF7C4DFF), '🚗 Bruda'),
                      _buildLegendItem(const Color(0xFFFF9800), '🚗 Bilevski'),
                    ],
                    if (_showPassengers) _buildLegendItem(Colors.green, '👤 Putnici'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco,
                            size: 12,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'OpenStreetMap',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 10),
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 11),
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
