import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/putnik_service.dart';
import '../services/seat_request_service.dart';
import '../services/voznje_log_service.dart';
import '../theme.dart';

class AdminZahteviScreen extends StatefulWidget {
  const AdminZahteviScreen({super.key});

  @override
  State<AdminZahteviScreen> createState() => _AdminZahteviScreenState();
}

class _AdminZahteviScreenState extends State<AdminZahteviScreen> {
  final Map<String, String> _putnikNamesCache = {};
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  String _activeFilter = 'Sve'; // 'Sve', 'Na čekanju', 'Obrađeno', 'Otkazano'
  String _searchQuery = '';

  /// 📦 Keširanje imena putnika u serijama kako bi se izbeglo "beskonačno učitavanje"
  Future<void> _precacheNames(List<Map<String, dynamic>> logs) async {
    final idsToFetch = <String>{};
    for (var l in logs) {
      final id = l['putnik_id']?.toString();
      if (id != null && !_putnikNamesCache.containsKey(id)) {
        idsToFetch.add(id);
      }
    }

    if (idsToFetch.isEmpty) return;

    try {
      final List<dynamic> response = await PutnikService()
          .supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime') // Fix: column is putnik_ime
          .inFilter('id', idsToFetch.toList());

      for (var p in response) {
        _putnikNamesCache[p['id'].toString()] = p['putnik_ime'].toString(); // Fix: column is putnik_ime
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Precache error: $e');
    }
  }

  String _getPutnikNameSync(dynamic id) {
    if (id == null) return 'Sistem/Nepoznato';
    return _putnikNamesCache[id.toString()] ?? 'Učitavanje...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Monitoring Zahteva 📨',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SeatRequestService.streamActiveRequests(),
                  builder: (context, activeSnapshot) {
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: VoznjeLogService.streamRequestLogs(limit: 50),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }
                        if (snapshot.hasError) {
                          debugPrint('❌ Monitoring Error: ${snapshot.error}');
                          return Center(
                              child: Text('Greška pri učitavanju.', style: const TextStyle(color: Colors.white70)));
                        }

                        final activeReqs = activeSnapshot.data ?? [];
                        var logs = snapshot.data ?? [];

                        // Precache names for both
                        if (activeReqs.isNotEmpty || logs.isNotEmpty) {
                          _precacheNames([...activeReqs, ...logs]);
                        }

                        // Map active requests to a log-like format for UI consistency
                        final mappedActive = activeReqs
                            .map((r) => {
                                  'id': r['id'],
                                  'tip': 'LIVE_REQUEST',
                                  'putnik_id': r['putnik_id'],
                                  'created_at': r['created_at'],
                                  'detalji':
                                      'AKTIVNO: ${r['grad'].toString().toUpperCase()} za ${r['dan']} (${r['vreme']})',
                                  'is_live': true,
                                })
                            .toList();

                        // 1. Combine lists (live first)
                        var displayList = [...mappedActive, ...logs];

                        // 2. Primeni UI filter (Sve, Na čekanju...)
                        if (_activeFilter != 'Sve') {
                          // Identifikuj putnike koji imaju potvrđene ili otkazane zahteve u trenutnoj listi
                          final handledPutnikIds = logs
                              .where((l) =>
                                  l['tip'] == 'potvrda_zakazivanja' ||
                                  l['tip'] == 'otkazivanje_putnika' ||
                                  l['tip'] == 'otkazivanje')
                              .map((l) => l['putnik_id']?.toString() ?? '')
                              .where((id) => id.isNotEmpty)
                              .toSet();

                          displayList = displayList.where((l) {
                            final tip = l['tip']?.toString() ?? '';
                            final pId = l['putnik_id']?.toString() ?? '';

                            if (_activeFilter == 'Na čekanju') {
                              if (tip == 'LIVE_REQUEST') return true;
                              if (tip != 'zakazivanje_putnika') return false;
                              return !handledPutnikIds.contains(pId);
                            }
                            if (_activeFilter == 'Obrađeno') return tip == 'potvrda_zakazivanja';
                            if (_activeFilter == 'Otkazano') {
                              return tip == 'otkazivanje_putnika' || tip == 'otkazivanje' || tip == 'greska_zahteva';
                            }
                            return true;
                          }).toList();
                        }

                        // 3. Search filter
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          displayList = displayList.where((l) {
                            final detalji = l['detalji']?.toString().toLowerCase() ?? '';
                            return detalji.contains(q);
                          }).toList();
                        }

                        if (displayList.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) => _buildRequestCard(displayList[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'name': 'Sve', 'icon': Icons.all_inclusive},
      {'name': 'Na čekanju', 'icon': Icons.hourglass_top},
      {'name': 'Obrađeno', 'icon': Icons.check_circle_outline},
      {'name': 'Otkazano', 'icon': Icons.cancel_outlined},
    ];

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final name = filter['name'] as String;
          final icon = filter['icon'] as IconData;
          final isActive = _activeFilter == name;

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? Colors.blue.shade900 : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: isActive ? Colors.blue.shade900 : Colors.white,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> log) {
    final tip = log['tip']?.toString() ?? '';
    final createdAtStr = log['created_at']?.toString() ?? '';
    final createdAt = (DateTime.tryParse(createdAtStr) ?? DateTime.now()).toLocal();
    final putnikId = log['putnik_id'];
    final detalji = log['detalji']?.toString() ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (tip) {
      case 'LIVE_REQUEST':
        statusColor = Colors.purple;
        statusLabel = 'LIVE ZAHTEV';
        statusIcon = Icons.sensors;
        break;
      case 'zakazivanje_putnika':
        statusColor = Colors.orange;
        statusLabel = 'DNEVNIK: ZAHTEV';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'potvrda_zakazivanja':
        if (detalji.contains('Sistem')) {
          statusColor = Colors.green.shade800;
          statusLabel = 'SISTEM POTVRDIO';
          statusIcon = Icons.auto_awesome;
        } else {
          statusColor = Colors.green;
          statusLabel = 'OBRAĐENO';
          statusIcon = Icons.check_circle;
        }
        break;
      case 'otkazivanje_putnika':
        if (detalji.contains('Sistem')) {
          statusColor = Colors.red.shade800;
          statusLabel = 'SISTEM UKLONIO';
          statusIcon = Icons.bolt;
        } else {
          statusColor = Colors.red;
          statusLabel = 'OTKAZANO';
          statusIcon = Icons.cancel;
        }
        break;
      case 'greska_zahteva':
        statusColor = Colors.deepOrange;
        statusLabel = 'SISTEMSKA GREŠKA';
        statusIcon = Icons.report_problem;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'NEPOZNATO';
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_dateFormat.format(createdAt)} ${_timeFormat.format(createdAt)}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _getPutnikNameSync(putnikId),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.indigo.withOpacity(0.08)),
                ),
                child: Text(
                  detalji,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 80,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nema rezultata',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty ? 'Kategorija: $_activeFilter' : 'Pretraga: $_searchQuery',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog<String>(
      context: context,
      builder: (context) {
        String input = _searchQuery;
        return AlertDialog(
          title: const Text('Pretraži zahteve'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ime putnika ili detalji...'),
            onChanged: (v) => input = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
            TextButton(
              onPressed: () {
                setState(() => _searchQuery = input);
                Navigator.pop(context);
              },
              child: const Text('Traži'),
            ),
          ],
        );
      },
    );
  }
}
