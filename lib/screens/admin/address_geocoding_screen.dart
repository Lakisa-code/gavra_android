import 'package:flutter/material.dart';
import 'package:gavra_android/services/address_geocoding_batch_service.dart';

import '../../theme.dart';

/// Admin screen za batch geocoding adresa
class AddressGeocodingScreen extends StatefulWidget {
  const AddressGeocodingScreen({super.key});

  @override
  State<AddressGeocodingScreen> createState() => _AddressGeocodingScreenState();
}

class _AddressGeocodingScreenState extends State<AddressGeocodingScreen> {
  bool _isRunning = false;
  Map<String, dynamic>? _status;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await AddressGeocodingBatchService.getGeocodingStatus();
      setState(() {
        _status = status;
      });
    } catch (e) {
      setState(() {
        _log += '❌ Greška pri dobijanju statusa: $e\n';
      });
    }
  }

  Future<void> _startGeocoding() async {
    setState(() {
      _isRunning = true;
      _log = '🌍 Početak batch geocoding...\n';
    });

    try {
      await AddressGeocodingBatchService.geocodeAllMissingAddresses();
      setState(() {
        _log += '✅ Batch geocoding završen uspešno!\n';
      });
      await _loadStatus(); // Refresh status
    } catch (e) {
      setState(() {
        _log += '❌ Greška: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌍 Batch Geocoding'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
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
            // remove shadows — AppBar should be transparent + border only
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            if (_status != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Geocoding Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('📍 Ukupno adresa: ${_status!['ukupno_adresa']}'),
                      Text('✅ Sa koordinatama: ${_status!['sa_koordinatama']}'),
                      Text('❌ Bez koordinata: ${_status!['bez_koordinata']}'),
                      Text('📈 Procenat: ${_status!['procenat_kompletiran']}%'),
                      const SizedBox(height: 8),
                      Text(
                        'Po gradovima:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...(_status!['status_po_gradovima'] as Map<String, dynamic>)
                          .entries
                          .map((e) => Text('  • ${e.key}: ${e.value} adresa')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Control Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _startGeocoding,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isRunning ? 'Radim...' : 'Pokreni Geocoding'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Log Area
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📜 Log',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _log.isEmpty ? 'Nema log poruka...' : _log,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
