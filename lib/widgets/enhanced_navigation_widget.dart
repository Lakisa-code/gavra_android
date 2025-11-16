import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/putnik.dart';
import '../services/background_gps_service.dart';
import '../services/offline_map_service.dart';
import '../services/voice_navigation_service.dart';

/// 🗺️ ENHANCED NAVIGATION WIDGET SA NOVIM FUNKCIONALNOSTIMA
/// Integrišu background GPS, offline maps i voice navigation
class EnhancedNavigationWidget extends StatefulWidget {
  const EnhancedNavigationWidget({
    Key? key,
    required this.putnici,
    required this.vozacId,
    required this.voziloId,
    required this.onOptimizeAllRoutes,
    required this.onStartGPSTracking,
  }) : super(key: key);
  final List<Putnik> putnici;
  final String vozacId;
  final String voziloId;
  final VoidCallback onOptimizeAllRoutes;
  final VoidCallback onStartGPSTracking;

  @override
  State<EnhancedNavigationWidget> createState() =>
      _EnhancedNavigationWidgetState();
}

class _EnhancedNavigationWidgetState extends State<EnhancedNavigationWidget> {
  bool _isBackgroundTrackingActive = false;
  bool _isVoiceNavigationActive = false;
  bool _isOfflineMapReady = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkServicesStatus();
    _getCurrentPosition();
  }

  /// 📊 CHECK STATUS OF ALL SERVICES
  Future<void> _checkServicesStatus() async {
    final isBackgroundActive =
        await BackgroundGpsService.isBackgroundTrackingActive();
    final isVoiceReady = VoiceNavigationService.isInitialized;

    if (mounted) {
      setState(() {
        _isBackgroundTrackingActive = isBackgroundActive;
        _isVoiceNavigationActive = isVoiceReady;
        _isOfflineMapReady =
            true; // OfflineMapService is always ready after init
      });
    }
  }

  /// 📍 GET CURRENT GPS POSITION
  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Handle GPS error
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ HEADER
          Text(
            '🚀 Enhanced Navigation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // 📊 SERVICE STATUS CARDS
          _buildServiceStatusCards(),
          const SizedBox(height: 20),

          // 🗺️ OFFLINE MAP PREVIEW
          if (_currentPosition != null) _buildOfflineMapPreview(),
          const SizedBox(height: 20),

          // 🎮 NAVIGATION CONTROLS
          _buildNavigationControls(),
          const SizedBox(height: 20),

          // 🔊 VOICE SETTINGS
          _buildVoiceSettings(),
        ],
      ),
    );
  }

  /// 📊 BUILD SERVICE STATUS CARDS
  Widget _buildServiceStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            'Background GPS',
            _isBackgroundTrackingActive ? 'Active' : 'Inactive',
            _isBackgroundTrackingActive ? Colors.green : Colors.grey,
            Icons.gps_fixed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusCard(
            'Voice Nav',
            _isVoiceNavigationActive ? 'Ready' : 'Disabled',
            _isVoiceNavigationActive ? Colors.blue : Colors.grey,
            Icons.volume_up,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusCard(
            'Offline Maps',
            _isOfflineMapReady ? 'Ready' : 'Loading',
            _isOfflineMapReady ? Colors.orange : Colors.grey,
            Icons.map,
          ),
        ),
      ],
    );
  }

  /// 📊 BUILD INDIVIDUAL STATUS CARD
  Widget _buildStatusCard(
    String title,
    String status,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              status,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 🗺️ BUILD OFFLINE MAP PREVIEW
  Widget _buildOfflineMapPreview() {
    final center =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    // Create markers for passengers
    final markers = widget.putnici
        .where((p) => p.adresa != null && p.adresa!.isNotEmpty)
        .map(
          (putnik) => Marker(
            point: center, // Would be geocoded in real implementation
            child: const Icon(Icons.person_pin, color: Colors.red, size: 20),
          ),
        )
        .toList();

    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗺️ Offline Map Preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OfflineMapService.buildOfflineMap(
                  center: center,
                  markers: markers,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎮 BUILD NAVIGATION CONTROLS
  Widget _buildNavigationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎮 Navigation Controls',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Background GPS Toggle
            ListTile(
              leading: Icon(
                _isBackgroundTrackingActive ? Icons.gps_fixed : Icons.gps_off,
                color: _isBackgroundTrackingActive ? Colors.green : Colors.grey,
              ),
              title: const Text('Background GPS Tracking'),
              subtitle: Text(
                _isBackgroundTrackingActive
                    ? 'GPS tracking active in background'
                    : 'Start continuous GPS tracking',
              ),
              trailing: Switch(
                value: _isBackgroundTrackingActive,
                onChanged: _toggleBackgroundGps,
              ),
            ),

            const Divider(),

            // Voice Navigation Toggle
            ListTile(
              leading: Icon(
                _isVoiceNavigationActive ? Icons.volume_up : Icons.volume_off,
                color: _isVoiceNavigationActive ? Colors.blue : Colors.grey,
              ),
              title: const Text('Voice Navigation'),
              subtitle: Text(
                _isVoiceNavigationActive
                    ? 'Voice instructions enabled'
                    : 'Enable voice turn-by-turn',
              ),
              trailing: Switch(
                value: _isVoiceNavigationActive,
                onChanged: _toggleVoiceNavigation,
              ),
            ),

            const Divider(),

            // Enhanced Navigation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    widget.putnici.isEmpty ? null : _startEnhancedNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text('🚀 Start Enhanced Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔊 BUILD VOICE SETTINGS
  Widget _buildVoiceSettings() {
    if (!_isVoiceNavigationActive) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔊 Voice Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Speech Rate
            Text(
              'Speech Rate: ${VoiceNavigationService.speechRate.toStringAsFixed(1)}',
            ),
            Slider(
              value: VoiceNavigationService.speechRate,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              onChanged: (value) async {
                await VoiceNavigationService.setSpeechRate(value);
                setState(() {});
              },
            ),

            // Volume
            Text(
              'Volume: ${(VoiceNavigationService.volume * 100).toStringAsFixed(0)}%',
            ),
            Slider(
              value: VoiceNavigationService.volume,
              divisions: 10,
              onChanged: (value) async {
                await VoiceNavigationService.setVolume(value);
                setState(() {});
              },
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testVoice,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Voice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🛰️ TOGGLE BACKGROUND GPS
  Future<void> _toggleBackgroundGps(bool enabled) async {
    if (enabled) {
      await BackgroundGpsService.startBackgroundTracking();
    } else {
      await BackgroundGpsService.stopBackgroundTracking();
    }

    await _checkServicesStatus();
  }

  /// 🔊 TOGGLE VOICE NAVIGATION
  Future<void> _toggleVoiceNavigation(bool enabled) async {
    if (enabled) {
      await VoiceNavigationService.initialize();
    } else {
      await VoiceNavigationService.dispose();
    }

    await _checkServicesStatus();
  }

  /// 🚀 START ENHANCED NAVIGATION
  Future<void> _startEnhancedNavigation() async {
    try {
      // 1. Optimize route offline
      if (_currentPosition != null) {
        final center =
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        final optimizedRoute = await OfflineMapService.optimizeRouteOffline(
          widget.putnici,
          center,
        );

        // 2. Start voice navigation if enabled
        if (_isVoiceNavigationActive) {
          await VoiceNavigationService.announcePassengerPickup(
            optimizedRoute.first,
          );
        }

        // 3. Start background GPS if enabled
        if (_isBackgroundTrackingActive) {
          await BackgroundGpsService.startBackgroundTracking();
        }

        // 4. Trigger existing optimization
        widget.onOptimizeAllRoutes();
        widget.onStartGPSTracking();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚀 Enhanced Navigation Started!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🔊 Voice test functionality
  Future<void> _testVoice() async {
    await VoiceNavigationService.speak(
      'Gavra navigacija je spremna. Broj putnika na listi: ${widget.putnici.length}.',
    );
  }
}
