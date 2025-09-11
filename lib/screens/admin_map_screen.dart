import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/putnik_service.dart';
import '../services/geocoding_service.dart';
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
  GoogleMapController? _controller;
  Position? _currentPosition;
  List<GpsLokacija> _gpsLokacije = [];
  List<Putnik> _putnici = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _showDrivers = true;
  bool _showPassengers = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(44.7866, 20.4489), // Belgrade default
    zoom: 11.0,
  );

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

      if (_controller != null) {
        _controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );
      }
    } catch (e) {
      // Greška u animaciji kamere na poziciju
    }
  }

  Future<void> _fitAllMarkers() async {
    if (_controller == null || _markers.isEmpty) return;

    // Pronađi granice svih markera
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Dodaj margine
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    minLat -= latDiff * 0.1;
    maxLat += latDiff * 0.1;
    minLng -= lngDiff * 0.1;
    maxLng += lngDiff * 0.1;

    // Animiraj kameru
    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }

  Future<void> _loadGpsLokacije() async {
    try {
      final response = await Supabase.instance.client
          .from('gps_lokacije')
          .select()
          .order('timestamp', ascending: false);

      final List<GpsLokacija> gpsLokacije =
          (response as List).map((data) => GpsLokacija.fromMap(data)).toList();

      setState(() {
        _gpsLokacije = gpsLokacije;
        _updateMarkers();
        _isLoading = false;
      });

      // Automatski fokusiraj na sve vozače nakon učitavanja
      if (_markers.isNotEmpty) {
        await Future.delayed(
            const Duration(milliseconds: 500)); // Čekaj da se mapa učita
        _fitAllMarkers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Prikaži error poruku korisniku
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
    Set<Marker> markers = {};

    // VOZAČI - ako su uključeni
    if (_showDrivers) {
      // Grupiši GPS lokacije po vozaču (name) i uzmi najnoviju za svakog
      Map<String, GpsLokacija> najnovijeLokacije = {};
      for (final lokacija in _gpsLokacije) {
        if (!najnovijeLokacije.containsKey(lokacija.name) ||
            najnovijeLokacije[lokacija.name]!.timestamp.isBefore(
                  lokacija.timestamp,
                )) {
          najnovijeLokacije[lokacija.name] = lokacija;
        }
      }

      // Kreiraj markere za svakog vozača
      najnovijeLokacije.forEach((vozac, lokacija) {
        final timeAgo = DateTime.now().difference(lokacija.timestamp).inMinutes;
        final timeAgoText = timeAgo < 60
            ? '${timeAgo}min ago'
            : '${(timeAgo / 60).round()}h ago';

        markers.add(
          Marker(
            markerId: MarkerId('driver_$vozac'),
            position: LatLng(lokacija.lat, lokacija.lng),
            infoWindow: InfoWindow(
              title: '🚗 $vozac',
              snippet: '${lokacija.vehicleType} • $timeAgoText',
            ),
            icon: _getMarkerIcon(lokacija),
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

  Future<void> _addPassengerMarkers(Set<Marker> markers) async {
    for (final putnik in _putnici) {
      if (putnik.adresa?.isNotEmpty == true) {
        try {
          final coords = await GeocodingService.getKoordinateZaAdresu(
              putnik.grad, putnik.adresa!);

          if (coords != null) {
            final parts = coords.split(',');
            if (parts.length == 2) {
              final lat = double.tryParse(parts[0]);
              final lng = double.tryParse(parts[1]);

              if (lat != null && lng != null) {
                markers.add(
                  Marker(
                    markerId: MarkerId('passenger_${putnik.id}'),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(
                      title: '👤 ${putnik.ime}',
                      snippet: '${putnik.adresa} • ${putnik.grad}',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Greška geocoding za ${putnik.ime}: $e');
        }
      }
    }
  }

  BitmapDescriptor _getMarkerIcon(GpsLokacija lokacija) {
    // 🎨 KORISTI OFICIJELNE BOJE VOZAČA - KONZISTENTNO SA APLIKACIJOM
    switch (lokacija.name.toLowerCase()) {
      case 'bojan':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueCyan, // 🔵 Cyan - kao u VozacBoja (0xFF00E5FF)
        );
      case 'bruda':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor
              .hueViolet, // 🟣 Ljubičasta - kao u VozacBoja (0xFF7C4DFF)
        );
      case 'bilevski':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor
              .hueOrange, // 🟠 Narandžasta - kao u VozacBoja (0xFFFF9800)
        );
      case 'svetlana':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor
              .hueRose, // 🌸 Drecava pink - kao u VozacBoja (0xFFFF1493)
        );
      default:
        // Fallback na plavu za nepoznate vozače
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        );
    }
  }

  // Prikaz samo izabranog vozača na mapi
  void _prikaziVozaca(String vozac) {
    final danas = DateTime.now();
    final lokacije = _gpsLokacije
        .where((l) =>
            l.name.toLowerCase() == vozac.toLowerCase() &&
            l.timestamp.year == danas.year &&
            l.timestamp.month == danas.month &&
            l.timestamp.day == danas.day)
        .toList();
    if (lokacije.isEmpty) return;
    final najnovija =
        lokacije.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId(vozac),
          position: LatLng(najnovija.lat, najnovija.lng),
          infoWindow: InfoWindow(
            title: '🚗 $vozac',
            snippet: '${najnovija.vehicleType} • ${najnovija.timestamp}',
          ),
          icon: _getMarkerIcon(najnovija),
        ),
      };
    });
    // Pomeri kameru na vozača
    _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(najnovija.lat, najnovija.lng), 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surface, // 🎨 Tema-aware pozadina
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
        title: const Text('GPS Mapa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // � Toggle vozači
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
          // 👥 Toggle putnici
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
          // �🔄 Refresh dugme
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
          // � Vozači menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.people, color: Colors.white),
            tooltip: 'Izbor vozača',
            onSelected: (vozac) => _prikaziVozaca(vozac),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Bruda',
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple, // Bruda
                      radius: 12,
                      child: Text('B',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    Text('Bruda'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Bilevski',
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange, // Bilevski
                      radius: 12,
                      child: Text('B',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    Text('Bilevski'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Svetlana',
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.pink, // Svetlana
                      radius: 12,
                      child: Text('S',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    Text('Svetlana'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Bojan',
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.cyan, // Bojan
                      radius: 12,
                      child: Text('B',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    Text('Bojan'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gpsLokacije.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nema GPS podataka',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tabela "gps_lokacije" je prazna',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _controller = controller;
                        if (_currentPosition != null) {
                          controller.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                zoom: 15.0,
                              ),
                            ),
                          );
                        }
                      },
                      initialCameraPosition: _initialPosition,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                    // Status overlay
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showDrivers) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_car,
                                      size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_gpsLokacije.length} vozača',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_showPassengers) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people,
                                      size: 16, color: Colors.green[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_putnici.length} putnika',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
