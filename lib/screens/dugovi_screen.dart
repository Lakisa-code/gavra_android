import 'dart:async';

import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../theme.dart';
import '../utils/putnik_helpers.dart';
import '../widgets/putnik_list.dart';

class DugoviScreen extends StatefulWidget {
  const DugoviScreen({Key? key, required this.currentDriver}) : super(key: key);
  final String currentDriver;

  @override
  State<DugoviScreen> createState() => _DugoviScreenState();
}

class _DugoviScreenState extends State<DugoviScreen> {
  // 🔄 V3.0 REALTIME MONITORING STATE (Clean Architecture)
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _dugoviStreamHealthy;
  late ValueNotifier<bool> _isNetworkConnected;
  late ValueNotifier<String> _realtimeHealthStatus;
  Timer? _healthCheckTimer;
  final Map<String, DateTime> _streamHeartbeats = {};

  // 🔍 SEARCH & FILTERING (bez RxDart)
  final TextEditingController _searchController = TextEditingController();

  final String _selectedFilter = 'svi'; // 'svi', 'veliki_dug', 'mali_dug'
  final String _sortBy = 'vreme'; // 'iznos', 'vreme', 'ime', 'vozac' - default: najnoviji gore

  @override
  void initState() {
    super.initState();
    _setupRealtimeMonitoring();
    _setupDebouncedSearch();
  }

  @override
  void dispose() {
    // 🧹 V3.0 CLEANUP REALTIME MONITORING
    _healthCheckTimer?.cancel();
    _isRealtimeHealthy.dispose();
    _dugoviStreamHealthy.dispose();
    _isNetworkConnected.dispose();
    _realtimeHealthStatus.dispose();

    // 🧹 SEARCH CLEANUP
    _searchController.dispose();
    super.dispose();
  }

  // 🔄 V3.0 REALTIME MONITORING SETUP
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _dugoviStreamHealthy = ValueNotifier(true);
    _isNetworkConnected = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkStreamHealth();
    });
  }

  void _checkStreamHealth() {
    final now = DateTime.now();
    bool isHealthy = true;

    for (final entry in _streamHeartbeats.entries) {
      final timeSinceLastHeartbeat = now.difference(entry.value);
      if (timeSinceLastHeartbeat.inSeconds > 60) {
        isHealthy = false;
        break;
      }
    }

    if (_isRealtimeHealthy.value != isHealthy) {
      _isRealtimeHealthy.value = isHealthy;
      _realtimeHealthStatus.value = isHealthy ? 'healthy' : 'heartbeat_timeout';
    }

    final networkHealthy = _isNetworkConnected.value;
    final streamHealthy = _dugoviStreamHealthy.value;

    if (!networkHealthy) {
      _realtimeHealthStatus.value = 'network_error';
    } else if (!streamHealthy) {
      _realtimeHealthStatus.value = 'stream_error';
    } else if (isHealthy) {
      _realtimeHealthStatus.value = 'healthy';
    }
  }

  // 🔍 SEARCH SETUP (bez RxDart - jednostavan setState)
  void _setupDebouncedSearch() {
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // 📊 SORT DUGOVE
  void _sortDugovi(List<Putnik> dugovi) {
    switch (_sortBy) {
      case 'iznos':
        dugovi.sort((a, b) {
          // Za dugove, koristimo cenu putovanja kao osnovu za sortiranje
          final cenaA = _calculateDugAmount(a);
          final cenaB = _calculateDugAmount(b);
          return cenaB.compareTo(cenaA); // Najveći dug prvi
        });
        break;
      case 'vreme':
        dugovi.sort((a, b) {
          final timeA = a.vremePokupljenja;
          final timeB = b.vremePokupljenja;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA); // Najnoviji prvi
        });
        break;
      case 'ime':
        dugovi.sort((a, b) => a.ime.compareTo(b.ime));
        break;
      case 'vozac':
        dugovi.sort(
          (a, b) => (a.pokupioVozac ?? '').compareTo(b.pokupioVozac ?? ''),
        );
        break;
    }
  }

  // 💰 CALCULATE DUG AMOUNT HELPER
  double _calculateDugAmount(Putnik putnik) {
    // ✅ FIX: Koristi efektivnu cenu iz modela pomnoženu sa brojem mesta
    // Umesto hardkodovanih 500.0
    return putnik.effectivePrice * (putnik.brojMesta > 0 ? putnik.brojMesta : 1);
  }

  List<Putnik> _applyFiltersAndSort(List<Putnik> input) {
    var result = input;

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      result = result.where((duznik) {
        return duznik.ime.toLowerCase().contains(searchQuery) ||
            (duznik.pokupioVozac?.toLowerCase().contains(searchQuery) ?? false) ||
            (duznik.grad.toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Apply amount filter
    if (_selectedFilter != 'svi') {
      result = result.where((duznik) {
        final iznos = _calculateDugAmount(duznik);
        switch (_selectedFilter) {
          case 'veliki_dug':
            return iznos >= 600; // Veliki dug (Dnevni je 600)
          case 'mali_dug':
            return iznos < 600; 
          default:
            return true;
        }
      }).toList();
    }

    // Sort
    _sortDugovi(result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Putnik>>(
      stream: PutnikService().streamKombinovaniPutniciFiltered(
        isoDate: PutnikHelpers.getWorkingDateIso(),
      ),
      builder: (context, snapshot) {
        final putnici = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting && putnici.isEmpty;

        // ✅ Filter dužnike - putnici sa PLAVOM KARTICOM (nisu mesečni tip) koji nisu platili
        final duzniciRaw = putnici
            .where(
              (p) =>
                  (!p.isMesecniTip) && // ✅ FIX: Plava kartica = nije mesečni tip
                  (p.vremePlacanja == null) && // ✅ FIX: Nije platio ako nema vremePlacanja
                  (p.jePokupljen) &&
                  (p.status == null || (p.status != 'Otkazano' && p.status != 'otkazan')),
              // 🎯 IZMENA: Uklonjen filter po vozaču da bi se prikazali SVI dužnici (zahtev 26.01.2026)
            )
            .toList();

        // ✅ DEDUPLIKACIJA: Jedan putnik može imati više termina, ali je jedan dužnik
        final seenIds = <dynamic>{};
        final duzniciDeduplicated = duzniciRaw.where((p) {
          final key = p.id ?? '${p.ime}_${p.dan}';
          if (seenIds.contains(key)) return false;
          seenIds.add(key);
          return true;
        }).toList();

        // Apply filters and sort
        final filteredDugovi = _applyFiltersAndSort(duzniciDeduplicated);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dugovanja',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  'Svi neplaćeni putnici (Plava kartica)',
                  style: TextStyle(fontSize: 12, color: Colors.white70.withValues(alpha: 0.8)),
                ),
              ],
            ),
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: BoxDecoration(gradient: Theme.of(context).backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  // ...existing code...
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : filteredDugovi.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nema evidentiranih dugovanja.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : PutnikList(
                                putnici: filteredDugovi,
                                currentDriver: widget.currentDriver,
                                isDugovanjaMode: true,
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
