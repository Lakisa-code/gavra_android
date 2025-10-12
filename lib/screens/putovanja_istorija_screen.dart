import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../models/putovanja_istorija.dart';
import '../services/putovanja_istorija_service.dart';
import '../theme.dart'; // Za theme boje
import '../utils/logging.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/realtime_error_widgets.dart'; // 🚨 REALTIME error handling

class PutovanjaIstorijaScreen extends StatefulWidget {
  const PutovanjaIstorijaScreen({Key? key}) : super(key: key);

  @override
  State<PutovanjaIstorijaScreen> createState() =>
      _PutovanjaIstorijaScreenState();
}

class _PutovanjaIstorijaScreenState extends State<PutovanjaIstorijaScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'svi'; // 'svi', 'mesecni', 'dnevni'

  // Varijable za dodavanje novog putovanja
  String _noviPutnikIme = '';
  String _noviPutnikTelefon = '';
  double _novaCena = 0.0;
  String _noviTipPutnika = 'regularni';

  // 🔄 V3.0 REALTIME MONITORING STATE (Clean Architecture)
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _putovanjaStreamHealthy;
  late ValueNotifier<bool> _isNetworkConnected;
  late ValueNotifier<String> _realtimeHealthStatus;
  Timer? _healthCheckTimer;
  StreamSubscription<List<PutovanjaIstorija>>? _putovanjaSubscription;
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
  List<PutovanjaIstorija> _cachedPutovanja = [];

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
    _putovanjaSubscription?.cancel();
    _isRealtimeHealthy.dispose();
    _putovanjaStreamHealthy.dispose();
    _isNetworkConnected.dispose();
    _realtimeHealthStatus.dispose();

    // 🧹 SEARCH CLEANUP
    _searchSubject.close();
    _filterSubject.close();
    _searchController.dispose();

    dlog('🧹 PutovanjaIstorijaScreen: Disposed realtime monitoring resources');
    super.dispose();
  }

  // 🔄 V3.0 REALTIME MONITORING SETUP (Backend only - no visual heartbeat)
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _putovanjaStreamHealthy = ValueNotifier(true);
    _isNetworkConnected = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkStreamHealth();
    });

    _initializeRealtimeStream();
    dlog('✅ PutovanjaIstorijaScreen: V3.0 realtime monitoring initialized');
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
        // 60 seconds timeout
        isHealthy = false;
        dlog(
            '⚠️ Stream ${entry.key} heartbeat stale: ${timeSinceLastHeartbeat.inSeconds}s',);
        break;
      }
    }

    if (_isRealtimeHealthy.value != isHealthy) {
      _isRealtimeHealthy.value = isHealthy;
      _realtimeHealthStatus.value = isHealthy ? 'healthy' : 'heartbeat_timeout';
    }

    final networkHealthy = _isNetworkConnected.value;
    final streamHealthy = _putovanjaStreamHealthy.value;

    if (!networkHealthy) {
      _realtimeHealthStatus.value = 'network_error';
    } else if (!streamHealthy) {
      _realtimeHealthStatus.value = 'stream_error';
    } else if (isHealthy) {
      _realtimeHealthStatus.value = 'healthy';
    }

    dlog(
        '🩺 PutovanjaIstorijaScreen health: Network=$networkHealthy, Stream=$streamHealthy, Heartbeat=$isHealthy',);
  }

  // 🚀 ENHANCED REALTIME STREAM INITIALIZATION
  void _initializeRealtimeStream() {
    _putovanjaSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _putovanjaSubscription =
        PutovanjaIstorijaService.streamPutovanjaZaDatum(_selectedDate)
            .timeout(const Duration(seconds: 30))
            .listen(
      (putovanja) {
        if (mounted) {
          _registerStreamHeartbeat('putovanja_stream');
          _putovanjaStreamHealthy.value = true;

          setState(() {
            _cachedPutovanja = putovanja;
            _isLoading = false;
            _errorMessage = null;
          });

          dlog(
              '✅ PutovanjaIstorijaScreen: Received ${putovanja.length} putovanja',);
        }
      },
      onError: (Object error) {
        if (mounted) {
          _putovanjaStreamHealthy.value = false;
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });

          dlog('❌ PutovanjaIstorijaScreen stream error: $error');

          // 🔄 AUTO RETRY after 5 seconds
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              dlog(
                  '🔄 PutovanjaIstorijaScreen: Auto-retrying stream connection...',);
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
    if (query.isEmpty) {
      // Reset to show all
      setState(() {});
      return;
    }

    // Filter cached data
    final filtered = _cachedPutovanja.where((putovanje) {
      return putovanje.putnikIme.toLowerCase().contains(query.toLowerCase()) ||
          putovanje.adresaPolaska.toLowerCase().contains(query.toLowerCase()) ||
          (putovanje.brojTelefona?.contains(query) ?? false);
    }).toList();

    setState(() {
      // This will trigger rebuild with filtered data
    });

    dlog('🔍 Search query: "$query" - Found ${filtered.length} results');
  }

  void _loadInitialData() {
    _initializeRealtimeStream();
  }

  // 🚨 ERROR TYPE DETECTION HELPER
  Widget _buildErrorWidgetForException(Object error, String streamName,
      {VoidCallback? onRetry,}) {
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

    // Default stream error
    return StreamErrorWidget(
      streamName: streamName,
      errorMessage: error.toString(),
      onRetry: onRetry ?? _initializeRealtimeStream,
    );
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
                          'Istorija Putovanja',
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
                        const SizedBox(height: 4),
                        // 💓 V3.0 REALTIME STATUS INDICATOR
                        ValueListenableBuilder<String>(
                          valueListenable: _realtimeHealthStatus,
                          builder: (context, status, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2,),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      _getStatusColor(status).withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    onPressed: () => _selectDate(),
                    tooltip: 'Izaberi datum',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    tooltip: 'Filter tip putnika',
                    onSelected: (value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                      _filterSubject.add(value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'svi',
                        child: Text('Svi putnici'),
                      ),
                      const PopupMenuItem(
                        value: 'mesecni',
                        child: Text('Mesečni putnici'),
                      ),
                      const PopupMenuItem(
                        value: 'dnevni',
                        child: Text('Dnevni putnici'),
                      ),
                    ],
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
                  // 🌐 NETWORK STATUS INDICATOR
                  ValueListenableBuilder<bool>(
                    valueListenable: _isNetworkConnected,
                    builder: (context, isConnected, child) {
                      return Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConnected
                                ? Colors.green.withOpacity(0.5)
                                : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: isConnected ? Colors.white : Colors.white70,
                        ),
                      );
                    },
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
          Container(
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
                    hintText: 'Pretraži po imenu, adresi ili telefonu...',
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
                    // Date info
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.indigo.shade600,),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4,),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.indigo.shade600,),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedFilter = value!;
                            });
                            _filterSubject.add(value!);
                          },
                          items: const [
                            DropdownMenuItem(value: 'svi', child: Text('Svi')),
                            DropdownMenuItem(
                                value: 'mesecni', child: Text('Mesečni'),),
                            DropdownMenuItem(
                                value: 'dnevni', child: Text('Dnevni'),),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Sort & Export actions
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.sort,
                                size: 20, color: Colors.indigo.shade600,),
                            onPressed: _showSortOptions,
                            tooltip: 'Sortiraj',
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40,),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: Colors.indigo.shade200,
                          ),
                          IconButton(
                            icon: Icon(Icons.file_download,
                                size: 20, color: Colors.indigo.shade600,),
                            onPressed: _exportData,
                            tooltip: 'Eksportuj',
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40,),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Results counter
                const SizedBox(height: 8),
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _putovanjaStreamHealthy,
                      builder: (context, isHealthy, child) {
                        final filteredCount = _getFilteredPutovanja().length;
                        final totalCount = _cachedPutovanja.length;

                        return Text(
                          isHealthy
                              ? 'Prikazano: $filteredCount od $totalCount putovanja'
                              : 'Podaci se učitavaju...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo.shade600,
                            fontStyle:
                                isHealthy ? FontStyle.normal : FontStyle.italic,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Real-time indicator
                    ValueListenableBuilder<String>(
                      valueListenable: _realtimeHealthStatus,
                      builder: (context, status, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2,),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getStatusColor(status).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 📋 LISTA PUTOVANJA - V3.0 REALTIME DATA
          Expanded(
            child: _buildRealtimeContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _dodajNovoPutovanje(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        tooltip: 'Dodaj novo putovanje',
        child: const Icon(Icons.add),
      ),
    );
  }

  // 🎨 STATUS COLOR HELPER
  Color _getStatusColor(String status) {
    switch (status) {
      case 'healthy':
        return Colors.green;
      case 'network_error':
        return Colors.orange;
      case 'stream_error':
      case 'heartbeat_timeout':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 📝 STATUS TEXT HELPER
  String _getStatusText(String status) {
    switch (status) {
      case 'healthy':
        return 'LIVE';
      case 'network_error':
        return 'NET';
      case 'stream_error':
        return 'ERR';
      case 'heartbeat_timeout':
        return 'TIMEOUT';
      default:
        return 'OFF';
    }
  }

  // 🚀 V3.0 REALTIME CONTENT BUILDER
  Widget _buildRealtimeContent() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorWidgetForException(
        Exception(_errorMessage!),
        'Putovanja istorija',
      );
    }

    // Filter data based on current filter and search
    final filteredPutovanja = _getFilteredPutovanja();

    if (filteredPutovanja.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPutovanjaList(filteredPutovanja);
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
            Icons.directions_bus_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nema putovanja za izabrani datum',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Izaberite drugi datum ili dodajte nova putovanja',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _dodajNovoPutovanje(),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj putovanje'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 🔍 FILTERED DATA GETTER
  List<PutovanjaIstorija> _getFilteredPutovanja() {
    var putovanja = _cachedPutovanja;

    // Apply type filter
    if (_selectedFilter != 'svi') {
      putovanja = putovanja.where((putovanje) {
        return putovanje.tipPutnika == _selectedFilter;
      }).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      putovanja = putovanja.where((putovanje) {
        return putovanje.putnikIme.toLowerCase().contains(searchQuery) ||
            putovanje.adresaPolaska.toLowerCase().contains(searchQuery) ||
            (putovanje.brojTelefona?.toLowerCase().contains(searchQuery) ??
                false);
      }).toList();
    }

    return putovanja;
  }

  // 📋 OPTIMIZED PUTOVANJA LIST
  Widget _buildPutovanjaList(List<PutovanjaIstorija> putovanja) {
    // Grupiranje po vremenu polaska
    final Map<String, List<PutovanjaIstorija>> grupisanaPutovanja = {};
    for (final putovanje in putovanja) {
      final vreme = putovanje.vremePolaska;
      if (!grupisanaPutovanja.containsKey(vreme)) {
        grupisanaPutovanja[vreme] = [];
      }
      grupisanaPutovanja[vreme]!.add(putovanje);
    }

    final sortedKeys = grupisanaPutovanja.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final vreme = sortedKeys[index];
        final putovanjaGrupe = grupisanaPutovanja[vreme]!;
        return _buildVremeGroup(vreme, putovanjaGrupe);
      },
    );
  }

  Widget _buildVremeGroup(String vreme, List<PutovanjaIstorija> putovanja) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sa vremenom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  vreme,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${putovanja.length} putnik${putovanja.length == 1 ? '' : 'a'}',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista putnika
          ...putovanja.map((putovanje) => _buildPutovanjeCard(putovanje)),
        ],
      ),
    );
  }

  Widget _buildPutovanjeCard(PutovanjaIstorija putovanje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sa imenom i tipom
          Row(
            children: [
              Expanded(
                child: Text(
                  putovanje.putnikIme,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTipChip(putovanje.tipPutnika),
            ],
          ),

          const SizedBox(height: 8),

          // Adresa polaska
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  putovanje.adresaPolaska,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),

          // Telefon ako postoji
          if (putovanje.brojTelefona != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  putovanje.brojTelefona!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Status putovanja
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BC → Vršac',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(putovanje.status),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vršac → BC',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(putovanje.status),
                  ],
                ),
              ),
            ],
          ),

          // Cena
          if (putovanje.cena > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (putovanje.cena > 0) ...[
                  Icon(
                    Icons.monetization_on,
                    size: 16,
                    color: Theme.of(context).colorScheme.successPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${putovanje.cena.toStringAsFixed(0)} RSD',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.successPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Action buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _editPutovanje(putovanje),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Uredi'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showStatusDialog(putovanje),
                icon: const Icon(Icons.update, size: 16),
                label: const Text('Status'),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipChip(String tip) {
    final isMesecni = tip == 'mesecni';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMesecni
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMesecni
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.3),
        ),
      ),
      child: Text(
        isMesecni ? 'MESEČNI' : 'DNEVNI',
        style: TextStyle(
          color: isMesecni
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pokupljen':
        color = Colors.green;
        text = 'POKUPLJEN';
        break;
      case 'otkazao_poziv':
        color = Colors.orange;
        text = 'OTKAZAO';
        break;
      case 'nije_se_pojavio':
      default:
        color = Colors.red;
        text = 'NIJE SE POJAVIO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const meseci = [
      '',
      'januar',
      'februar',
      'mart',
      'april',
      'maj',
      'jun',
      'jul',
      'avgust',
      'septembar',
      'oktobar',
      'novembar',
      'decembar',
    ];

    const dani = [
      '',
      'ponedeljak',
      'utorak',
      'sreda',
      'četvrtak',
      'petak',
      'subota',
      'nedelja',
    ];

    return '${dani[date.weekday]}, ${date.day}. ${meseci[date.month]} ${date.year}.';
  }

  // 🔧 SORT OPTIONS DIALOG
  void _showSortOptions() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sortiraj putovanja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Po vremenu polaska'),
              onTap: () {
                Navigator.pop(context);
                // Implementiraj sortiranje po vremenu
                _sortData('vreme');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Po imenu putnika'),
              onTap: () {
                Navigator.pop(context);
                _sortData('ime');
              },
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Po ceni'),
              onTap: () {
                Navigator.pop(context);
                _sortData('cena');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Po statusu'),
              onTap: () {
                Navigator.pop(context);
                _sortData('status');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
        ],
      ),
    );
  }

  // 📊 SORT DATA IMPLEMENTATION
  void _sortData(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'vreme':
          _cachedPutovanja
              .sort((a, b) => a.vremePolaska.compareTo(b.vremePolaska));
          break;
        case 'ime':
          _cachedPutovanja.sort((a, b) => a.putnikIme.compareTo(b.putnikIme));
          break;
        case 'cena':
          _cachedPutovanja.sort((a, b) => b.cena.compareTo(a.cena));
          break;
        case 'status':
          _cachedPutovanja.sort((a, b) => a.status.compareTo(b.status));
          break;
      }
    });

    dlog('📊 PutovanjaIstorijaScreen: Sorted data by $sortBy');
  }

  // 📄 EXPORT DATA FUNCTIONALITY
  Future<void> _exportData() async {
    try {
      final filteredData = _getFilteredPutovanja();

      if (filteredData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nema podataka za eksport'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show export options
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eksportuj podatke'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('CSV format'),
                subtitle: Text('${filteredData.length} putovanja'),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Pripremi za štampu'),
                subtitle: const Text('PDF format'),
                onTap: () => Navigator.pop(context, 'print'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
          ],
        ),
      );

      if (result == 'csv') {
        await _exportToCSV(filteredData);
      } else if (result == 'print') {
        await _preparePrintData(filteredData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri eksportu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 📄 CSV EXPORT IMPLEMENTATION
  Future<void> _exportToCSV(List<PutovanjaIstorija> data) async {
    try {
      final csvContent = await PutovanjaIstorijaService.exportToCSV(
        odDatuma: _selectedDate,
        doDatuma: _selectedDate,
        tipPutnika: _selectedFilter == 'svi' ? null : _selectedFilter,
      );

      if (csvContent.isNotEmpty) {
        // U realnoj aplikaciji, ovde bi bio kod za čuvanje fajla
        // ili deljenje kroz share API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eksportovano ${data.length} putovanja u CSV'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Podeli',
              textColor: Colors.white,
              onPressed: () {
                // Implementiraj deljenje fajla
                dlog('📄 Share CSV content: ${csvContent.length} characters');
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export greška: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🖨️ PRINT PREPARATION
  Future<void> _preparePrintData(List<PutovanjaIstorija> data) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Priprema za štampu ${data.length} putovanja...'),
        backgroundColor: Colors.blue,
      ),
    );

    // Ovde bi bila implementacija za print preview
    dlog('🖨️ Preparing print data for ${data.length} items');
  }

  // 📅 DATE SELECTION
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Izaberite datum',
      cancelText: 'Odustani',
      confirmText: 'Potvrdi',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      // 🔄 REINITIALIZE STREAM FOR NEW DATE
      dlog(
          '📅 PutovanjaIstorijaScreen: Date changed to ${_selectedDate.toIso8601String().split('T')[0]}',);
      _initializeRealtimeStream();
    }
  }

  // 📝 DODAJ NOVO PUTOVANJE
  void _dodajNovoPutovanje() {
    // Reset forme
    setState(() {
      _noviPutnikIme = '';
      _noviPutnikTelefon = '';
      _novaCena = 0.0;
      _noviTipPutnika = 'regularni';
    });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj novo putovanje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ime putnika',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _noviPutnikIme = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => _noviPutnikTelefon = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Cena (RSD)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _novaCena = double.tryParse(value) ?? 0.0,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                value: _noviTipPutnika,
                items: ['regularni', 'mesecni'].map((tip) {
                  return DropdownMenuItem(value: tip, child: Text(tip));
                }).toList(),
                onChanged: (value) => _noviTipPutnika = value ?? 'regularni',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: _sacuvajNovoPutovanje,
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  // 💾 SAČUVAJ NOVO PUTOVANJE
  Future<void> _sacuvajNovoPutovanje() async {
    if (_noviPutnikIme.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final novoPutovanje = PutovanjaIstorija(
        id: '', // Biće automatski generisan u Supabase
        putnikIme: _noviPutnikIme.trim(),
        brojTelefona: _noviPutnikTelefon.trim().isEmpty
            ? null
            : _noviPutnikTelefon.trim(),
        adresaPolaska: 'Bela Crkva', // Default vrednost
        vremePolaska: '07:00', // Default vrednost
        tipPutnika: _noviTipPutnika,
        cena: _novaCena,
        datum: _selectedDate,
        vremeAkcije: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await PutovanjaIstorijaService.dodajPutovanje(novoPutovanje);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Putovanje je uspešno dodato'),
            backgroundColor: Colors.green,
          ),
        );

        // Resetuj forme
        setState(() {
          _noviPutnikIme = '';
          _noviPutnikTelefon = '';
          _novaCena = 0.0;
          _noviTipPutnika = 'regularni';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  // ✏️ EDIT PUTOVANJE
  void _editPutovanje(PutovanjaIstorija putovanje) {
    // Postavi vrednosti za edit
    setState(() {
      _noviPutnikIme = putovanje.putnikIme;
      _noviPutnikTelefon = putovanje.brojTelefona ?? '';
      _novaCena = putovanje.cena;
      _noviTipPutnika = putovanje.tipPutnika;
    });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uredi putovanje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => _noviPutnikIme = value,
                decoration: const InputDecoration(
                  labelText: 'Ime putnika',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _noviPutnikIme),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPutnikTelefon = value,
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _noviPutnikTelefon),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaCena = double.tryParse(value) ?? 0.0,
                decoration: const InputDecoration(
                  labelText: 'Cena',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _novaCena.toString()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                value: _noviTipPutnika,
                items: ['regularni', 'mesecni'].map((tip) {
                  return DropdownMenuItem(value: tip, child: Text(tip));
                }).toList(),
                onChanged: (value) => _noviTipPutnika = value ?? 'regularni',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => _sacuvajIzmenePutovanja(putovanje),
            child: const Text('Sačuvaj izmene'),
          ),
        ],
      ),
    );
  }

  // 💾 SAČUVAJ IZMENE PUTOVANJA
  Future<void> _sacuvajIzmenePutovanja(
      PutovanjaIstorija originalPutovanje,) async {
    if (_noviPutnikIme.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final azuriranoPutovanje = PutovanjaIstorija(
        id: originalPutovanje.id,
        mesecniPutnikId: originalPutovanje.mesecniPutnikId,
        putnikIme: _noviPutnikIme.trim(),
        brojTelefona: _noviPutnikTelefon.trim().isEmpty
            ? null
            : _noviPutnikTelefon.trim(),
        adresaPolaska: originalPutovanje.adresaPolaska,
        vremePolaska: originalPutovanje.vremePolaska,
        tipPutnika: _noviTipPutnika,
        status: originalPutovanje.status,
        pokupljen: originalPutovanje.pokupljen,
        cena: _novaCena,
        datum: originalPutovanje.datum,
        vremeAkcije: originalPutovanje.vremeAkcije,
        createdAt: originalPutovanje.createdAt,
        updatedAt: DateTime.now(),
      );

      await PutovanjaIstorijaService.azurirajPutovanje(azuriranoPutovanje);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Putovanje je uspešno ažurirano'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri ažuriranju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📊 STATUS DIALOG
  void _showStatusDialog(PutovanjaIstorija putovanje) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Status: ${putovanje.putnikIme}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pending, color: Colors.orange),
              title: const Text('Na čekanju'),
              onTap: () => _updateMainStatus(putovanje, 'na_cekanju'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Pokupljen'),
              onTap: () => _updateMainStatus(putovanje, 'pokupljen'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Otkazano'),
              onTap: () => _updateMainStatus(putovanje, 'otkazano'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  // 🔄 UPDATE STATUS
  Future<void> _updateMainStatus(
    PutovanjaIstorija putovanje,
    String noviStatus,
  ) async {
    final azuriranoPutovanje = PutovanjaIstorija(
      id: putovanje.id,
      mesecniPutnikId: putovanje.mesecniPutnikId,
      putnikIme: putovanje.putnikIme,
      brojTelefona: putovanje.brojTelefona,
      adresaPolaska: putovanje.adresaPolaska,
      vremePolaska: putovanje.vremePolaska,
      tipPutnika: putovanje.tipPutnika,
      status: noviStatus,
      pokupljen: noviStatus == 'pokupljen',
      cena: putovanje.cena,
      datum: putovanje.datum,
      vremeAkcije: putovanje.vremeAkcije,
      createdAt: putovanje.createdAt,
      updatedAt: DateTime.now(),
    );

    await PutovanjaIstorijaService.azurirajPutovanje(azuriranoPutovanje);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status ažuriran na: $noviStatus')),
      );
    }
  }
}
