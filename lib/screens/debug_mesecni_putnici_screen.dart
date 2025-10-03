import 'package:flutter/material.dart';
import '../services/mesecni_putnik_service_novi.dart';
import '../models/mesecni_putnik_novi.dart';

class DebugMesecniPutniciScreen extends StatefulWidget {
  const DebugMesecniPutniciScreen({Key? key}) : super(key: key);

  @override
  State<DebugMesecniPutniciScreen> createState() =>
      _DebugMesecniPutniciScreenState();
}

class _DebugMesecniPutniciScreenState extends State<DebugMesecniPutniciScreen> {
  final MesecniPutnikServiceNovi _service = MesecniPutnikServiceNovi();
  List<MesecniPutnik> _putnici = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPutnici();
  }

  Future<void> _loadPutnici() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final putnici = await _service.getAllMesecniPutnici();

      setState(() {
        _putnici = putnici;
        _loading = false;
      });

      print('🔍 Loaded ${putnici.length} monthly passengers');
      for (final p in putnici) {
        print(
            '   ${p.putnikIme} - ${p.tip} - ${p.radniDani} - aktivan: ${p.aktivan}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      print('❌ Error loading monthly passengers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Mesečni Putnici'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPutnici,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Greška: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPutnici,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : _putnici.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off, color: Colors.grey, size: 48),
                          SizedBox(height: 16),
                          Text('Nema mesečnih putnika'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _putnici.length,
                      itemBuilder: (context, index) {
                        final putnik = _putnici[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  putnik.aktivan ? Colors.green : Colors.red,
                              child: Text(
                                putnik.putnikIme.isNotEmpty
                                    ? putnik.putnikIme[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(putnik.putnikIme),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tip: ${putnik.tip}'),
                                Text('Radni dani: ${putnik.radniDani}'),
                                Text('Status: ${putnik.status}'),
                                if (putnik.polasciPoDanu.isNotEmpty)
                                  Text(
                                      'Polasci: ${putnik.polasciPoDanu.toString()}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  putnik.aktivan
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: putnik.aktivan
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                Text(
                                  putnik.aktivan ? 'Aktivan' : 'Neaktivan',
                                  style: TextStyle(
                                    color: putnik.aktivan
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
