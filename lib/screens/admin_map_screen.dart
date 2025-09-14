import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/putnik_service.dart';
import '../models/putnik.dart';

// Model za GPS lokacije vozača
class GpsLokacija {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String color;
  final String vehicleType;

  GpsLokacija({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.color,
    required this.vehicleType,
  });

  factory GpsLokacija.fromMap(Map<String, dynamic> map) {
    return GpsLokacija(
      id: map['id'] as int,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      color: map['color'] as String? ?? 'blue',
      vehicleType: map['vehicle_type'] as String? ?? 'car',
    );
  }
}

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final MapController _mapController = MapController();
  List<GpsLokacija> _gpsLokacije = [];
  List<Putnik> _putnici = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showDrivers = true;
  bool _showPassengers = false;
  List<Marker> _markers = [];

  // Početna pozicija - Bela Crkva/Vršac region
  static const LatLng _initialCenter = LatLng(44.9, 21.4);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadGpsLokacije();
    _loadPutnici();
  }

  Future<void> _loadPutnici() async {
    try {
      final putnikService = PutnikService();
      final putnici = await putnikService.getAllPutniciFromBothTables();
      setState(() {
        _putnici = putnici;
      });
      _updateMarkers();
    } catch (e) {
      debugPrint('Greška učitavanja putnika: $e');
    }
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
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Centriraj mapu na trenutnu poziciju
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        13.0,
      );
    } catch (e) {
      debugPrint('Greška dobavljanja trenutne lokacije: $e');
    }
  }

  Future<void> _loadGpsLokacije() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('gps_lokacije')
          .select()
          .order('timestamp', ascending: false)
          .limit(1000);

      final gpsLokacije = (response as List<dynamic>)
          .map((json) => GpsLokacija.fromMap(json))
          .toList();

      setState(() {
        _gpsLokacije = gpsLokacije;
        _updateMarkers();
        _isLoading = false;
      });

      // Automatski fokusiraj na sve vozače nakon učitavanja
      if (_markers.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        _fitAllMarkers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri učitavanju GPS lokacija: $e'),
            backgroundColor: Colors.red,
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
      Map<String, GpsLokacija> najnovijeLokacije = {};
      for (final lokacija in _gpsLokacije) {
        if (!najnovijeLokacije.containsKey(lokacija.name) ||
            najnovijeLokacije[lokacija.name]!
                .timestamp
                .isBefore(lokacija.timestamp)) {
          najnovijeLokacije[lokacija.name] = lokacija;
        }
      }

      // Kreiraj markere za svakog vozača
      najnovijeLokacije.forEach((vozac, lokacija) {
        markers.add(
          Marker(
            point: LatLng(lokacija.lat, lokacija.lng),
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
                    vozac.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

    setState(() {
      _markers = markers;
    });
  }

  Color _getDriverColor(GpsLokacija lokacija) {
    // 🎨 KORISTI OFICIJELNE BOJE VOZAČA
    switch (lokacija.name.toLowerCase()) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🗺️ Admin GPS Mapa (OpenStreetMap)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 🚗 Vozači toggle
          IconButton(
            icon: Icon(
              _showDrivers
                  ? Icons.directions_car
                  : Icons.directions_car_outlined,
              color: _showDrivers ? Colors.white : Colors.white54,
            ),
            onPressed: () {
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
              setState(() {
                _showPassengers = !_showPassengers;
              });
              _updateMarkers();
            },
            tooltip: _showPassengers ? 'Sakrij putnike' : 'Prikaži putnike',
          ),
          // 🔄 Refresh dugme
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadGpsLokacije();
              _loadPutnici();
            },
            tooltip: 'Osveži GPS podatke',
          ),
          // 🗺️ Zoom out dugme
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white),
            onPressed: _fitAllMarkers,
            tooltip: 'Prikaži sve vozače',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🗺️ OpenStreetMap sa flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : _initialCenter,
              initialZoom: 13.0,
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
          // 📊 Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          // 📋 Legend
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Legenda:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  if (_showDrivers) ...[
                    _buildLegendItem(const Color(0xFF00E5FF), '🚗 Bojan'),
                    _buildLegendItem(const Color(0xFFFF1493), '🚗 Svetlana'),
                    _buildLegendItem(const Color(0xFF7C4DFF), '🚗 Bruda'),
                    _buildLegendItem(const Color(0xFFFF9800), '🚗 Bilevski'),
                  ],
                  if (_showPassengers)
                    _buildLegendItem(Colors.green, '👤 Putnici'),
                  const SizedBox(height: 4),
                  const Text(
                    '💚 BESPLATNO OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
