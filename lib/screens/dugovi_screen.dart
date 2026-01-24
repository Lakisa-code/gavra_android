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
  StreamSubscription<List<Putnik>>? _dugoviSubscription;
  final Map<String, DateTime> _streamHeartbeats = {};

  // 🔍 SEARCH & FILTERING (bez RxDart)
  final TextEditingController _searchController = TextEditingController();

  // 📊 PERFORMANCE STATE
  bool _isLoading = false;
  String? _errorMessage;
  List<Putnik> _cachedDugovi = [];
  final String _selectedFilter = 'svi'; // 'svi', 'veliki_dug', 'mali_dug'
  final String _sortBy = 'vreme'; // 'iznos', 'vreme', 'ime', 'vozac' - default: najnoviji gore

  @override
  void initState() {
    super.initState();
    _setupRealtimeMonitoring();
    _setupDebouncedSearch();
    _loadInitialData();
  }

  @override
  void dispose() {
    // 🧹 V3.0 CLEANUP REALTIME MONITORING
    _healthCheckTimer?.cancel();
    _dugoviSubscription?.cancel();
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

    _initializeRealtimeStream();
  }

  // 💓 HEARTBEAT MONITORING FUNCTIONS
  void _registerStreamHeartbeat(String streamName) {
    _streamHeartbeats[streamName] = DateTime.now();
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

  // 🚀 ENHANCED REALTIME STREAM INITIALIZATION
  void _initializeRealtimeStream() {
    _dugoviSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    _dugoviSubscription = PutnikService()
        .streamKombinovaniPutniciFiltered(
      isoDate: PutnikHelpers.getWorkingDateIso(),
    )
        .listen(
      (putnici) {
        if (mounted) {
          _registerStreamHeartbeat('dugovi_stream');
          _dugoviStreamHealthy.value = true;

          // ✅ Filter dužnike - putnici sa PLAVOM KARTICOM (nisu mesečni tip) koji nisu platili
          final duzniciRaw = putnici
              .where(
                (p) =>
                    (!p.isMesecniTip) && // ✅ FIX: Plava kartica = nije mesečni tip
                    (p.vremePlacanja == null) && // ✅ FIX: Nije platio ako nema vremePlacanja
                    (p.jePokupljen) &&
                    (p.status == null || (p.status != 'Otkazano' && p.status != 'otkazan')) &&
                    // 🎯 FILTER PO VOZAČU: Prikaži samo one koje je pokupio ovaj vozač
                    (p.pokupioVozac == widget.currentDriver),
              )
              .toList();

          // ✅ DEDUPLIKACIJA: Jedan putnik može imati više termina, ali je jedan dužnik
          final seenIds = <dynamic>{};
          final duznici = duzniciRaw.where((p) {
            final key = p.id ?? '${p.ime}_${p.dan}';
            if (seenIds.contains(key)) return false;
            seenIds.add(key);
            return true;
          }).toList();

          // Sort dužnike
          _sortDugovi(duznici);

          if (mounted) {
            setState(() {
              _cachedDugovi = duznici;
              _isLoading = false;
              _errorMessage = null;
            });
          }
        }
      },
      onError: (Object error) {
        if (mounted) {
          _dugoviStreamHealthy.value = false;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = error.toString();
            });
          }
// 🔄 AUTO RETRY after 5 seconds
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              _initializeRealtimeStream();
            }
          });
        }
      },
    );
  }

  // 🔍 SEARCH SETUP (bez RxDart - jednostavan setState)
  void _setupDebouncedSearch() {
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _loadInitialData() {
    _initializeRealtimeStream();
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

  // 🔍 FILTERED DATA GETTER
  List<Putnik> _getFilteredDugovi() {
    var dugovi = _cachedDugovi;

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      dugovi = dugovi.where((duznik) {
        return duznik.ime.toLowerCase().contains(searchQuery) ||
            (duznik.pokupioVozac?.toLowerCase().contains(searchQuery) ?? false) ||
            (duznik.grad.toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Apply amount filter
    if (_selectedFilter != 'svi') {
      dugovi = dugovi.where((duznik) {
        final iznos = _calculateDugAmount(duznik);
        switch (_selectedFilter) {
          case 'veliki_dug':
            return iznos >= 500; // Veliki dug preko 500 RSD
          case 'mali_dug':
            return iznos < 500; // Mali dug ispod 500 RSD
          default:
            return true;
        }
      }).toList();
    }

    return dugovi;
  }

  // 💰 CALCULATE DUG AMOUNT HELPER
  double _calculateDugAmount(Putnik putnik) {
    // Za dugove, koristimo standardnu cenu ili specifičnu cenu iz putnika
    // Default cena za Bela Crkva - Vršac je 500 RSD
    return 500.0; // Osnovni iznos karte - može se proširiti na osnovu rute
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient, // Gradijent preko celog ekrana
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparentna pozadina
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer, // Transparentni glassmorphism
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Dužnici',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // 💰 UKUPAN DUG BAR UKLONJEN PO ZAHTEVU (15.01.2026)
            /*
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.indigo.shade200),
                ),
              ),
              child: Text(
                'Ukupan dug: ${_calculateTotalDebt().toStringAsFixed(0)} RSD',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            */
            // 📋 LISTA DUGOVA - V3.0 REALTIME DATA
            Expanded(
              child: _buildRealtimeContent(),
            ),
          ],
        ),
      ), // Zatvaranje Scaffold
    ); // Zatvaranje Container
  }

  // 🚀 V3.0 REALTIME CONTENT BUILDER
  Widget _buildRealtimeContent() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      // Heartbeat indicator shows connection status
      return _buildEmptyState();
    }

    final filteredDugovi = _getFilteredDugovi();

    if (filteredDugovi.isEmpty) {
      return _buildEmptyState();
    }

    return PutnikList(
      putnici: filteredDugovi,
      currentDriver: widget.currentDriver,
    );
  }

  // ✨ SHIMMER LOADING EFFECT
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header shimmer
                Container(
                  height: 24,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                // Content shimmer
                ...List.generate(
                  2,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
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
      },
    );
  }

  // 📭 EMPTY STATE WIDGET
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nema neplaćenih putnika!',
            style: TextStyle(
              fontSize: 18,
              color: Colors.green.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Svi putnici su platili svoje karte',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
