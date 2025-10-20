import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../services/geocoding_stats_service.dart';

class GeocodingAdminScreen extends StatefulWidget {
  const GeocodingAdminScreen({Key? key}) : super(key: key);

  @override
  State<GeocodingAdminScreen> createState() => _GeocodingAdminScreenState();
}

class _GeocodingAdminScreenState extends State<GeocodingAdminScreen> {
  // 🔄 V3.0 REALTIME MONITORING STATE (Clean Architecture)
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _geocodingStreamHealthy;
  late ValueNotifier<bool> _isNetworkConnected;
  late ValueNotifier<String> _realtimeHealthStatus;
  Timer? _healthCheckTimer;
  Timer? _autoRefreshTimer;
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;
  final Map<String, DateTime> _streamHeartbeats = {};

  // 🔍 DEBOUNCED SEARCH & FILTERING
  final BehaviorSubject<String> _searchSubject = BehaviorSubject<String>.seeded('');
  final BehaviorSubject<String> _filterSubject = BehaviorSubject<String>.seeded('svi');
  late Stream<String> _debouncedSearchStream;
  final TextEditingController _searchController = TextEditingController();

  // 📊 PERFORMANCE STATE
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _cachedStats = {};
  List<Map<String, dynamic>> _cachedPopularLocations = [];
  String _selectedFilter = 'svi'; // 'svi', 'api_calls', 'cache_hits'
  String _sortBy = 'count'; // 'count', 'location', 'recent'
  bool _autoRefreshEnabled = true;

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
    _autoRefreshTimer?.cancel();
    _statsSubscription?.cancel();
    _isRealtimeHealthy.dispose();
    _geocodingStreamHealthy.dispose();
    _isNetworkConnected.dispose();
    _realtimeHealthStatus.dispose();

    // 🧹 SEARCH CLEANUP
    _searchSubject.close();
    _filterSubject.close();
    _searchController.dispose();
    // Debug logging removed for production
    super.dispose();
  }

  // 🔄 V3.0 REALTIME MONITORING SETUP
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _geocodingStreamHealthy = ValueNotifier(true);
    _isNetworkConnected = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkStreamHealth();
    });

    // Auto-refresh every 60 seconds
    if (_autoRefreshEnabled) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        _loadData();
      });
    }

    _initializeRealtimeStream();
    // Debug logging removed for production
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
      if (timeSinceLastHeartbeat.inSeconds > 90) {
        // 90 seconds timeout for admin stats
        isHealthy = false;
        // Debug logging removed for production
        break;
      }
    }

    if (_isRealtimeHealthy.value != isHealthy) {
      _isRealtimeHealthy.value = isHealthy;
      _realtimeHealthStatus.value = isHealthy ? 'healthy' : 'heartbeat_timeout';
    }

    final networkHealthy = _isNetworkConnected.value;
    final streamHealthy = _geocodingStreamHealthy.value;

    if (!networkHealthy) {
      _realtimeHealthStatus.value = 'network_error';
    } else if (!streamHealthy) {
      _realtimeHealthStatus.value = 'stream_error';
    } else if (isHealthy) {
      _realtimeHealthStatus.value = 'healthy';
    }
    // Debug logging removed for production
  }

  // 🚀 ENHANCED REALTIME STREAM INITIALIZATION
  void _initializeRealtimeStream() {
    _statsSubscription?.cancel();

    if (mounted)
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

    // Simulate stream-like behavior with periodic updates
    _loadData();
  }

  // 🔍 DEBOUNCED SEARCH SETUP
  void _setupDebouncedSearch() {
    _debouncedSearchStream = _searchSubject.debounceTime(const Duration(milliseconds: 300)).distinct();

    _debouncedSearchStream.listen((query) {
      _performSearch(query);
    });

    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });
  }

  void _performSearch(String query) {
    if (mounted)
      setState(() {
        // Trigger rebuild with filtered data
      });

    // Debug logging removed for production
  }

  void _loadInitialData() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _registerStreamHeartbeat('geocoding_stats');
      _geocodingStreamHealthy.value = true;

      final stats = await GeocodingStatsService.getGeocodingStats();
      final popular = await GeocodingStatsService.getPopularLocations();

      if (mounted) {
        if (mounted)
          setState(() {
            _cachedStats = stats;
            _cachedPopularLocations = popular;
            _isLoading = false;
            _errorMessage = null;
          });

        // Sort locations
        _sortLocations();
        // Debug logging removed for production
      }
    } catch (e) {
      if (mounted) {
        _geocodingStreamHealthy.value = false;
        if (mounted)
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
        // Debug logging removed for production
// 🔄 AUTO RETRY after 10 seconds for admin screens
        Timer(const Duration(seconds: 10), () {
          if (mounted && _autoRefreshEnabled) {
            // Debug logging removed for production
            _loadData();
          }
        });
      }
    }
  }

  // 📊 SORT LOCATIONS
  void _sortLocations() {
    switch (_sortBy) {
      case 'count':
        _cachedPopularLocations.sort(
          (a, b) => ((b['count'] ?? 0) as int).compareTo((a['count'] ?? 0) as int),
        );
        break;
      case 'location':
        _cachedPopularLocations.sort(
          (a, b) => ((a['location'] ?? '') as String).compareTo((b['location'] ?? '') as String),
        );
        break;
      case 'recent':
        // Sort by most recently accessed (if timestamp available)
        _cachedPopularLocations.sort(
          (a, b) => ((b['last_accessed'] ?? 0) as int).compareTo((a['last_accessed'] ?? 0) as int),
        );
        break;
    }
  }

  // 🔍 FILTERED DATA GETTER
  List<Map<String, dynamic>> _getFilteredLocations() {
    var locations = _cachedPopularLocations;

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      locations = locations.where((location) {
        final locationName = (location['location'] ?? '').toString().toLowerCase();
        return locationName.contains(searchQuery);
      }).toList();
    }

    // Apply type filter
    if (_selectedFilter != 'svi') {
      locations = locations.where((location) {
        final count = (location['count'] ?? 0) as int;
        switch (_selectedFilter) {
          case 'popular':
            return count >= 10; // Popular locations with 10+ searches
          case 'moderate':
            return count >= 5 && count < 10; // Moderate usage
          case 'low':
            return count < 5; // Low usage
          default:
            return true;
        }
      }).toList();
    }

    return locations;
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši Cache'),
        content: const Text(
          'Da li ste sigurni da želite da obrišete sav geocoding cache? '
          'Ovo će usporiti sledeća pretraživanja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GeocodingStatsService.clearGeocodingCache();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geocoding cache je obrisan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Statistike'),
        content: const Text(
          'Da li ste sigurni da želite da resetujete sve geocoding statistike?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GeocodingStatsService.resetStats();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statistike su resetovane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Blue-900
              Color(0xFF3B82F6), // Blue-500
              Color(0xFF1D4ED8), // Blue-600
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🎯 ENHANCED HEADER WITH REALTIME STATUS
              _buildEnhancedHeader(),

              // 🔍 ENHANCED SEARCH AND FILTER BAR
              _buildSearchAndFilterBar(),

              // 📊 STATS OVERVIEW CARDS
              if (!_isLoading && _cachedStats.isNotEmpty) _buildStatsCards(),

              // 📋 MAIN CONTENT AREA
              Expanded(
                child: _isLoading
                    ? _buildShimmerLoading()
                    : _errorMessage != null
                        ? _buildErrorWidget()
                        : _buildLocationsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 ENHANCED HEADER WITH REALTIME STATUS
  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),

          // Title
          const Expanded(
            child: Text(
              'Geocoding Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox.shrink(),

          // Auto-refresh toggle
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              if (mounted)
                setState(() {
                  _autoRefreshEnabled = !_autoRefreshEnabled;
                });
              // Debug logging removed for production
            },
            icon: Icon(
              _autoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
              color: _autoRefreshEnabled ? Colors.white : Colors.white54,
              size: 20,
            ),
          ),

          // Cache management menu
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            onSelected: (value) {
              switch (value) {
                case 'clear_cache':
                  _clearCache();
                  break;
                case 'reset_stats':
                  _resetStats();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Obriši Cache'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_stats',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset Statistike'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔍 ENHANCED SEARCH AND FILTER BAR
  Widget _buildSearchAndFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pretraži lokacije...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchSubject.add('');
                        },
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Filter chips
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('svi', 'Sve lokacije'),
                const SizedBox(width: 8),
                _buildFilterChip('popular', 'Popularne (10+)'),
                const SizedBox(width: 8),
                _buildFilterChip('moderate', 'Umerene (5-9)'),
                const SizedBox(width: 8),
                _buildFilterChip('low', 'Retke (<5)'),
              ],
            ),
          ),

          // Sort options
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Sortiranje:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              _buildSortChip('count', 'Brojač'),
              const SizedBox(width: 8),
              _buildSortChip('location', 'Naziv'),
              const SizedBox(width: 8),
              _buildSortChip('recent', 'Nedavno'),
            ],
          ),
        ],
      ),
    );
  }

  // 🎯 FILTER CHIP WIDGET
  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        if (mounted)
          setState(() {
            _selectedFilter = value;
          });
        // Debug logging removed for production
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // 📊 SORT CHIP WIDGET
  Widget _buildSortChip(String value, String label) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        if (mounted)
          setState(() {
            _sortBy = value;
            _sortLocations();
          });
        // Debug logging removed for production
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // 📊 STATS OVERVIEW CARDS
  Widget _buildStatsCards() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'API pozivi',
              '${_cachedStats['api_calls'] ?? 0}',
              Icons.cloud_outlined,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Cache hits',
              '${_cachedStats['cache_hits'] ?? 0}',
              Icons.memory,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Hit rate',
              '${_cachedStats['cache_hit_rate'] ?? 0}%',
              Icons.speed,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // 📈 INDIVIDUAL STAT CARD
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 💎 SHIMMER LOADING EFFECT
  Widget _buildShimmerLoading() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          8,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // 📋 LOCATIONS LIST
  Widget _buildLocationsList() {
    final filteredLocations = _getFilteredLocations();

    if (filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nema rezultata',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Probajte sa drugim kriterijumima pretrage',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLocations.length,
        itemBuilder: (context, index) {
          final location = filteredLocations[index];
          return _buildLocationItem(location, index);
        },
      ),
    );
  }

  // 📍 LOCATION ITEM WIDGET
  Widget _buildLocationItem(Map<String, dynamic> location, int index) {
    final locationName = (location['location'] ?? 'Nepoznato').toString();
    final count = (location['count'] ?? 0) as int;
    final lastAccessed = location['last_accessed'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getCountColor(count).withOpacity(0.2),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: _getCountColor(count),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          locationName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: lastAccessed != null
            ? Text(
                'Poslednji pristup: ${_formatDateTime(lastAccessed)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getCountColor(count).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: _getCountColor(count),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  } // 🎨 COUNT COLOR HELPER

  Color _getCountColor(int count) {
    if (count >= 20) return Colors.red;
    if (count >= 10) return Colors.orange;
    if (count >= 5) return Colors.yellow;
    return Colors.green;
  }

  // 📅 DATE FORMATTER
  String _formatDateTime(dynamic timestamp) {
    try {
      if (timestamp is String) {
        final dateTime = DateTime.parse(timestamp);
        return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  // ❌ ERROR WIDGET
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Greška u učitavanju',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Nepoznata greška',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    );
  }
}
