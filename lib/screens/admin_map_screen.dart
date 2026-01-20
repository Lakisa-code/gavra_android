import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../globals.dart';
import '../models/gps_lokacija.dart';
import '../services/permission_service.dart';
import '../services/realtime/realtime_manager.dart';
import '../theme.dart';
import '../utils/vozac_boja.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final MapController _mapController = MapController();
  List<GPSLokacija> _gpsLokacije = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showDrivers = true;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _showPolylines = false;
  DateTime? _lastGpsLoad;
  static const cacheDuration = Duration(seconds: 30);

  StreamSubscription? _gpsSubscription;

  // Početna pozicija - Bela Crkva/Vršac region
  static const LatLng _initialCenter = LatLng(44.9, 21.4);

  @override
  void initState() {
    super.initState();
    _initializeRealtimeMonitoring();
    _getCurrentLocation();
    _loadGpsLokacije(); // Fallback
  }

  void _initializeRealtimeMonitoring() {
    _gpsSubscription?.cancel();

    // Koristi centralizovani RealtimeManager
    _gpsSubscription = RealtimeManager.instance.subscribe('vozac_lokacije').listen((payload) {
      _loadGpsLokacije();
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('vozac_lokacije');
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 🔐 CENTRALIZOVANA PROVERA GPS DOZVOLA
      final hasPermission = await PermissionService.ensureGpsForNavigation();
      if (!hasPermission) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      // Centriraj mapu na trenutnu poziciju
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        13.0,
      );
    } catch (e) {
      // Silently ignore
    }
  }

  Future<void> _loadGpsLokacije() async {
    // Proverava cache - ne učitava ponovo ako je prošlo manje od 30 sekundi
    if (_lastGpsLoad != null && DateTime.now().difference(_lastGpsLoad!) < cacheDuration) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Učitaj iz vozac_lokacije tabele - SAMO aktivne vozače sa skorašnjim podacima
      // Filter: aktivan = true I updated_at u poslednjih 4 sata (realno praćenje)
      final recentTime = DateTime.now().subtract(const Duration(hours: 4)).toUtc().toIso8601String();
      final response =
          await supabase.from('vozac_lokacije').select().eq('aktivan', true).gte('updated_at', recentTime).limit(10);
      final gpsLokacije = <GPSLokacija>[];
      for (final json in response as List<dynamic>) {
        try {
          final data = json as Map<String, dynamic>;
          // Koristi vozac_ime ako postoji, inače vozac_id (može biti ime ili UUID)
          final vozacIme = data['vozac_ime'] as String? ?? data['vozac_id'] as String?;
          gpsLokacije.add(GPSLokacija(
            id: data['id'] as String,
            vozacId: vozacIme, // Sada sadrži ime vozača direktno
            latitude: (data['lat'] as num).toDouble(),
            longitude: (data['lng'] as num).toDouble(),
            vreme: data['updated_at'] != null ? DateTime.parse(data['updated_at'] as String) : DateTime.now(),
          ));
        } catch (e) {
          // Silently ignore malformed GPS data
        }
      }
      if (mounted) {
        setState(() {
          _gpsLokacije = gpsLokacije;
          _lastGpsLoad = DateTime.now();
          _updateMarkers();
          _isLoading = false;
        });
      }

      // Automatski fokusiraj na sve vozače nakon učitavanja
      if (_markers.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _fitAllMarkers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsLokacije = []; // Postavi praznu listu
          _isLoading = false;
        });
      }

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
        final vozacKey = lokacija.vozacId ?? '';
        if (vozacKey.isEmpty) continue;
        if (!najnovijeLokacije.containsKey(vozacKey) || najnovijeLokacije[vozacKey]!.vreme.isBefore(lokacija.vreme)) {
          najnovijeLokacije[vozacKey] = lokacija;
        }
      }

      // Kreiraj markere za svakog vozača
      najnovijeLokacije.forEach((vozacIme, lokacija) {
        // vozacIme je sada već ime vozača (ne UUID), koristi direktno
        if (vozacIme.isEmpty) return;
        final displayName = vozacIme;

        markers.add(
          Marker(
            point: LatLng(lokacija.latitude, lokacija.longitude),
            width: 40,
            height: 50,
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.location_pin,
              color: _getDriverColor(displayName),
              size: 50,
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
              ],
            ),
          ),
        );
      });
    }

    // PUTNICI - funkcionalnost nije implementirana (geocoding potreban)

    _updatePolylines();

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  void _updatePolylines() {
    if (!_showPolylines) {
      _polylines = [];
      return;
    }

    List<Polyline> polylines = [];

    // Grupiši sve GPS lokacije po vozaču
    Map<String, List<GPSLokacija>> lokacijePoVozacu = {};
    for (final lokacija in _gpsLokacije) {
      final vozacKey = lokacija.vozacId ?? '';
      if (vozacKey.isEmpty) continue;
      lokacijePoVozacu.putIfAbsent(vozacKey, () => []).add(lokacija);
    }

    // Kreiraj polyline za svakog vozača
    lokacijePoVozacu.forEach((vozacIme, lokacije) {
      if (lokacije.length < 2) return; // Treba minimum 2 tačke za liniju

      // Sortiraj po vremenu
      lokacije.sort((a, b) => a.vreme.compareTo(b.vreme));

      final points = lokacije.map((l) => LatLng(l.latitude, l.longitude)).toList();

      polylines.add(
        Polyline(
          points: points,
          color: _getDriverColor(vozacIme).withValues(alpha: 0.7),
          strokeWidth: 4.0,
        ),
      );
    });

    _polylines = polylines;
  }

  // Prima ime vozača - koristi centralizovanu VozacBoja klasu
  Color _getDriverColor(String vozacIme) {
    return VozacBoja.getColorOrDefault(vozacIme, const Color(0xFF607D8B));
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
                    const Expanded(
                      child: Text(
                        '🗺️ Admin GPS Mapa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                        if (mounted) {
                          setState(() {
                            _showDrivers = !_showDrivers;
                          });
                        }
                        _updateMarkers();
                      },
                      tooltip: _showDrivers ? 'Sakrij vozače' : 'Prikaži vozače',
                    ),
                    // 📍 Polyline toggle - prikaz putanja
                    IconButton(
                      icon: Icon(
                        _showPolylines ? Icons.timeline : Icons.timeline_outlined,
                        color: _showPolylines ? Colors.white : Colors.white54,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _showPolylines = !_showPolylines;
                          });
                        }
                        _updateMarkers();
                      },
                      tooltip: _showPolylines ? 'Sakrij putanje' : 'Prikaži putanje',
                    ),
                    // 👥 Putnici toggle - DISABLED (geocoding nije implementiran)
                    // Refresh dugme
                    TextButton(
                      onPressed: () {
                        _loadGpsLokacije();
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
                // Polyline putanje vozača
                if (_showPolylines) PolylineLayer(polylines: _polylines),
                // Markeri
                MarkerLayer(markers: _markers),
              ],
            ),
            // V3.0 Loading State - Elegant design
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Realtime monitoring aktiviran',
                          style: TextStyle(
                            fontSize: 12,
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
                            fontSize: 14,
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
                      _buildLegendItem(const Color(0xFFFFD700), '🚗 Ivan'),
                    ],
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
                              fontSize: 10,
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
              fontSize: 11,
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
