import 'package:flutter/material.dart';
import '../services/geocoding_stats_service.dart';
import '../widgets/custom_back_button.dart';

class GeocodingAdminScreen extends StatefulWidget {
  const GeocodingAdminScreen({Key? key}) : super(key: key);

  @override
  State<GeocodingAdminScreen> createState() => _GeocodingAdminScreenState();
}

class _GeocodingAdminScreenState extends State<GeocodingAdminScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _popularLocations = [];
  Map<String, dynamic> _cacheInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await GeocodingStatsService.getGeocodingStats();
      final popular = await GeocodingStatsService.getPopularLocations();
      final cacheInfo = await GeocodingStatsService.getCacheInfo();

      setState(() {
        _stats = stats;
        _popularLocations = popular;
        _cacheInfo = cacheInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const GradientBackButton(),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Geocoding Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Statistike Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bar_chart, color: Colors.blue[600]),
                              const SizedBox(width: 8),
                              const Text(
                                'Geocoding Statistike',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('API pozivi',
                              '${_stats['api_calls'] ?? 0}', Icons.cloud),
                          _buildStatRow('Cache hits',
                              '${_stats['cache_hits'] ?? 0}', Icons.memory),
                          _buildStatRow(
                              'Ukupno zahteva',
                              '${_stats['total_requests'] ?? 0}',
                              Icons.all_inclusive),
                          _buildStatRow('Cache hit rate',
                              '${_stats['cache_hit_rate'] ?? 0}%', Icons.speed),
                          _buildStatRow('Cache entries',
                              '${_stats['cache_entries'] ?? 0}', Icons.storage),
                          _buildStatRow(
                              'Procenjena veličina',
                              '${_stats['cache_size_estimate'] ?? 'N/A'}',
                              Icons.folder_open),
                          _buildStatRow(
                              'Poslednji reset',
                              '${_stats['last_reset'] ?? 'Nikad'}',
                              Icons.refresh),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Popular Locations Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.green[600]),
                              const SizedBox(width: 8),
                              const Text(
                                'Popularne Lokacije',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_popularLocations.isEmpty)
                            const Text(
                              'Nema podataka o popularnim lokacijama',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            ...(_popularLocations.take(10))
                                .map(
                                  (location) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            location['location']
                                                .toString()
                                                .replaceAll('_', ' '),
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${location['count']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cache Management Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, color: Colors.orange[600]),
                              const SizedBox(width: 8),
                              const Text(
                                'Cache Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow(
                              'Ukupno entries',
                              '${_cacheInfo['total_entries'] ?? 0}',
                              Icons.folder),
                          _buildStatRow(
                              'Coordinate entries',
                              '${_cacheInfo['coordinate_entries'] ?? 0}',
                              Icons.map),
                          _buildStatRow(
                              'Stats entries',
                              '${_cacheInfo['stats_entries'] ?? 0}',
                              Icons.analytics),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _clearCache,
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white),
                                  label: const Text('Obriši Cache',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[600],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _resetStats,
                                  icon: const Icon(Icons.refresh,
                                      color: Colors.white),
                                  label: const Text('Reset Stats',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
