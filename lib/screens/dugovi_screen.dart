import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../utils/logging.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/putnik_list.dart';
import '../widgets/realtime_error_widgets.dart'; // 🚨 REALTIME error handling

class DugoviScreen extends StatefulWidget {
  const DugoviScreen({Key? key, this.currentDriver}) : super(key: key);
  final String? currentDriver;

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

  // 🔍 DEBOUNCED SEARCH & FILTERING
  final BehaviorSubject<String> _searchSubject =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<String> _filterSubject =
      BehaviorSubject<String>.seeded('svi');
  late Stream<String> _debouncedSearchStream;
  final TextEditingController _searchController = TextEditingController();

  // 📊 PERFORMANCE STATE
  bool _isLoading = false;
  String? _errorMessage;
  List<Putnik> _cachedDugovi = [];
  String _selectedFilter = 'svi'; // 'svi', 'veliki_dug', 'mali_dug'
  String _sortBy = 'iznos'; // 'iznos', 'vreme', 'ime', 'vozac'

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
    _searchSubject.close();
    _filterSubject.close();
    _searchController.dispose();

    dlog('🧹 DugoviScreen: Disposed realtime monitoring resources');
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
    dlog('✅ DugoviScreen: V3.0 realtime monitoring initialized');
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
        dlog(
          '⚠️ Stream ${entry.key} heartbeat stale: ${timeSinceLastHeartbeat.inSeconds}s',
        );
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

    dlog(
      '🩺 DugoviScreen health: Network=$networkHealthy, Stream=$streamHealthy, Heartbeat=$isHealthy',
    );
  }

  // 🚀 ENHANCED REALTIME STREAM INITIALIZATION
  void _initializeRealtimeStream() {
    _dugoviSubscription?.cancel();

    if (mounted) setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _dugoviSubscription = PutnikService()
        .streamKombinovaniPutniciFiltered(
          isoDate: DateTime.now().toIso8601String().split('T')[0],
        )
        .timeout(const Duration(seconds: 30))
        .listen(
      (putnici) {
        if (mounted) {
          _registerStreamHeartbeat('dugovi_stream');
          _dugoviStreamHealthy.value = true;

          // Filter dužnike
          final duznici = putnici
              .where(
                (p) =>
                    (p.iznosPlacanja == null || p.iznosPlacanja == 0) &&
                    (p.jePokupljen) &&
                    (p.status == null ||
                        (p.status != 'Otkazano' && p.status != 'otkazan')) &&
                    (p.mesecnaKarta != true),
              )
              .toList();

          // Sort dužnike
          _sortDugovi(duznici);

          if (mounted) setState(() {
            _cachedDugovi = duznici;
            _isLoading = false;
            _errorMessage = null;
          });

          dlog('✅ DugoviScreen: Received ${duznici.length} dužnika');
        }
      },
      onError: (Object error) {
        if (mounted) {
          _dugoviStreamHealthy.value = false;
          if (mounted) setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });

          dlog('❌ DugoviScreen stream error: $error');

          // 🔄 AUTO RETRY after 5 seconds
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              dlog('🔄 DugoviScreen: Auto-retrying stream connection...');
              _initializeRealtimeStream();
            }
          });
        }
      },
    );
  }

  // 🔍 DEBOUNCED SEARCH SETUP
  void _setupDebouncedSearch() {
    _debouncedSearchStream = _searchSubject
        .debounceTime(const Duration(milliseconds: 300))
        .distinct();

    _debouncedSearchStream.listen((query) {
      _performSearch(query);
    });

    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });
  }

  void _performSearch(String query) {
    if (mounted) setState(() {
      // Trigger rebuild with filtered data
    });

    final filtered = _getFilteredDugovi();
    dlog('🔍 Search query: "$query" - Found ${filtered.length} results');
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
            (duznik.pokupioVozac?.toLowerCase().contains(searchQuery) ??
                false) ||
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const GradientBackButton(),
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
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔄 MANUAL REFRESH BUTTON
                  IconButton(
                    icon: ValueListenableBuilder<bool>(
                      valueListenable: _isRealtimeHealthy,
                      builder: (context, isHealthy, child) {
                        return Icon(
                          isHealthy ? Icons.refresh : Icons.refresh_rounded,
                          color: isHealthy ? Colors.white : Colors.white70,
                        );
                      },
                    ),
                    onPressed: () {
                      _initializeRealtimeStream();
                    },
                    tooltip: 'Osveži podatke',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔍 ENHANCED SEARCH AND FILTER BAR
          _buildSearchAndFilterBar(),
          // 📋 LISTA DUGOVA - V3.0 REALTIME DATA
          Expanded(
            child: _buildRealtimeContent(),
          ),
        ],
      ),
    );
  }

  // 🔍 ENHANCED SEARCH AND FILTER BAR
  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.indigo.shade200),
        ),
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Pretraži po imenu, vozaču ili gradu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchSubject.add('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.indigo.shade300),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Advanced filters row
          Row(
            children: [
              // Filter dropdown
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.indigo.shade600,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) {
                        if (mounted) setState(() {
                          _selectedFilter = value!;
                        });
                        _filterSubject.add(value!);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'svi',
                          child: Text('Svi dugovi'),
                        ),
                        DropdownMenuItem(
                          value: 'veliki_dug',
                          child: Text('Veliki dugovi (500+ RSD)'),
                        ),
                        DropdownMenuItem(
                          value: 'mali_dug',
                          child: Text('Mali dugovi (<500 RSD)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Sort dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(Icons.sort, color: Colors.indigo.shade600),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      if (mounted) setState(() {
                        _sortBy = value!;
                        _sortDugovi(_cachedDugovi);
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'iznos',
                        child: Text('Po iznosu'),
                      ),
                      DropdownMenuItem(
                        value: 'vreme',
                        child: Text('Po vremenu'),
                      ),
                      DropdownMenuItem(value: 'ime', child: Text('Po imenu')),
                      DropdownMenuItem(
                        value: 'vozac',
                        child: Text('Po vozaču'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Results counter
          const SizedBox(height: 8),
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _dugoviStreamHealthy,
                builder: (context, isHealthy, child) {
                  final filteredCount = _getFilteredDugovi().length;
                  final totalCount = _cachedDugovi.length;
                  final totalDebt = _calculateTotalDebt();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHealthy
                            ? 'Prikazano: $filteredCount od $totalCount dužnika'
                            : 'Podaci se učitavaju...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade600,
                          fontStyle:
                              isHealthy ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      if (isHealthy) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ukupan dug: ${totalDebt.toStringAsFixed(0)} RSD',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 💰 CALCULATE TOTAL DEBT
  double _calculateTotalDebt() {
    return _getFilteredDugovi()
        .fold(0.0, (sum, duznik) => sum + _calculateDugAmount(duznik));
  }

  // 🚀 V3.0 REALTIME CONTENT BUILDER
  Widget _buildRealtimeContent() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorWidgetForException(
        Exception(_errorMessage!),
        'Dugovi lista',
      );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _initializeRealtimeStream(),
            icon: const Icon(Icons.refresh),
            label: const Text('Osveži podatke'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 🚨 ERROR TYPE DETECTION HELPER
  Widget _buildErrorWidgetForException(
    Object error,
    String streamName, {
    VoidCallback? onRetry,
  }) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout') || errorString.contains('time')) {
      return TimeoutErrorWidget(
        operation: streamName,
        timeout: const Duration(seconds: 30),
        onRetry: onRetry ?? _initializeRealtimeStream,
      );
    }

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return NetworkErrorWidget(
        message: 'Problem sa mrežom u $streamName',
        onRetry: onRetry ?? _initializeRealtimeStream,
      );
    }

    if (errorString.contains('data') ||
        errorString.contains('parse') ||
        errorString.contains('format')) {
      return DataErrorWidget(
        dataType: streamName,
        reason: error.toString(),
        onRefresh: onRetry ?? _initializeRealtimeStream,
      );
    }

    return StreamErrorWidget(
      streamName: streamName,
      errorMessage: error.toString(),
      onRetry: onRetry ?? _initializeRealtimeStream,
    );
  }
}





