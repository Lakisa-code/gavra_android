import 'dart:async';

import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../services/theme_manager.dart';
import '../utils/putnik_helpers.dart';
import '../utils/vozac_boja.dart';
import '../widgets/putnik_card.dart';

class TranzitScreen extends StatefulWidget {
  final String currentDriver;

  const TranzitScreen({
    Key? key,
    required this.currentDriver,
  }) : super(key: key);

  @override
  State<TranzitScreen> createState() => _TranzitScreenState();
}

class _TranzitScreenState extends State<TranzitScreen> {
  StreamSubscription<List<Putnik>>? _subscription;
  List<Map<String, dynamic>> _tranzitniPutnici = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startStream() {
    _subscription = PutnikService()
        .streamKombinovaniPutniciFiltered(
      isoDate: PutnikHelpers.getWorkingDateIso(),
    )
        .listen((sviPutnici) {
      if (!mounted) return;

      final Map<String, List<Putnik>> tranzitMap = {};
      for (var p in sviPutnici) {
        if (p.jeOtkazan || p.jeOdsustvo || p.obrisan) continue;
        if (p.tipPutnika == 'posiljka') continue;
        // Samo putnici dodeljeni ovom vozaču (kao i na glavnom ekranu)
        if (p.dodeljenVozac != widget.currentDriver) continue;

        tranzitMap.putIfAbsent(p.ime, () => []).add(p);
      }

      final List<Map<String, dynamic>> results = [];

      tranzitMap.forEach((ime, trips) {
        final imaBC = trips.any((t) => t.grad == 'Bela Crkva');
        final imaVS = trips.any((t) => t.grad == 'Vršac');

        if (imaBC && imaVS) {
          final isZavrseno = trips.every((t) => t.jePokupljen);
          results.add({
            'ime': ime,
            'trips': trips,
            'isZavrseno': isZavrseno,
          });
        }
      });

      // Sortiraj: prvo oni koji NISU završeni
      results.sort((a, b) {
        if (a['isZavrseno'] != b['isZavrseno']) {
          return a['isZavrseno'] ? 1 : -1;
        }
        return (a['ime'] as String).compareTo(b['ime'] as String);
      });

      setState(() {
        _tranzitniPutnici = results;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverColor = VozacBoja.get(widget.currentDriver);
    final workingDate = PutnikHelpers.getWorkingDateIso();

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRANZIT PUTNICI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                workingDate,
                style: TextStyle(fontSize: 12, color: driverColor),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _tranzitniPutnici.isEmpty
                ? _buildEmptyState()
                : _buildList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Nema putnika u tranzitu za danas',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _tranzitniPutnici.length,
      itemBuilder: (context, index) {
        final item = _tranzitniPutnici[index];
        final String ime = item['ime'];
        final bool isZavrseno = item['isZavrseno'];
        final List<Putnik> trips = item['trips'];

        return Card(
          color: Colors.white.withValues(alpha: 0.1),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isZavrseno ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: ExpansionTile(
            leading: Icon(
              isZavrseno ? Icons.check_circle : Icons.pending,
              color: isZavrseno ? Colors.green : Colors.orange,
            ),
            title: Text(
              ime,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${trips.length} termina zakazano',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            trailing: isZavrseno
                ? const Text('ZAVRŠENO',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10))
                : const Text('NA ČEKANJU',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: trips
                      .map((p) => PutnikCard(
                            putnik: p,
                            currentDriver: widget.currentDriver,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
