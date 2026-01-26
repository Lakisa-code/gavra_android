import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/putnik_service.dart';
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

  Future<String> _getPutnikName(dynamic id) async {
    if (id == null) return 'Sistem/Nepoznato';
    final sId = id.toString();
    if (_putnikNamesCache.containsKey(sId)) return _putnikNamesCache[sId]!;

    try {
      final p = await PutnikService().getPutnikFromAnyTable(id);
      if (p != null) {
        final name = p.ime;
        _putnikNamesCache[sId] = name;
        return name;
      }
    } catch (_) {}

    return 'Putnik #$sId';
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
                  stream: VoznjeLogService.streamAllRecentLogs(limit: 300),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Greška: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
                    }

                    var logs = snapshot.data ?? [];

                    // 1. Primarni filter za tipove koji nas zanimaju (Zahtevi)
                    logs = logs.where((l) {
                      final tip = l['tip']?.toString() ?? '';
                      return tip == 'zakazivanje_putnika' ||
                          tip == 'potvrda_zakazivanja' ||
                          tip == 'otkazivanje_putnika' ||
                          tip == 'greska_zahteva';
                    }).toList();

                    // 2. Primeni UI filter (Sve, Na čekanju...)
                    if (_activeFilter != 'Sve') {
                      logs = logs.where((l) {
                        final tip = l['tip']?.toString() ?? '';
                        if (_activeFilter == 'Na čekanju') return tip == 'zakazivanje_putnika';
                        if (_activeFilter == 'Obrađeno') return tip == 'potvrda_zakazivanja';
                        if (_activeFilter == 'Otkazano') return tip == 'otkazivanje_putnika' || tip == 'greska_zahteva';
                        return true;
                      }).toList();
                    } // 3. Search filter
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      logs = logs.where((l) {
                        final detalji = l['detalji']?.toString().toLowerCase() ?? '';
                        return detalji.contains(q);
                      }).toList();
                    }

                    if (logs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: logs.length,
                      itemBuilder: (context, index) => _buildRequestCard(logs[index]),
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
    final filters = ['Sve', 'Na čekanju', 'Obrađeno', 'Otkazano'];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final isActive = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f),
              selected: isActive,
              onSelected: (val) => setState(() => _activeFilter = f),
              backgroundColor: Colors.white10,
              selectedColor: Colors.blue.shade700,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> log) {
    final tip = log['tip']?.toString() ?? '';
    final createdAtStr = log['created_at']?.toString() ?? '';
    final createdAt = (DateTime.tryParse(createdAtStr) ?? DateTime.now()).toLocal().add(const Duration(hours: 1));
    final putnikId = log['putnik_id'];
    final detalji = log['detalji']?.toString() ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (tip) {
      case 'zakazivanje_putnika':
        statusColor = Colors.orange;
        statusLabel = 'NOVI ZAHTEV';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'potvrda_zakazivanja':
        statusColor = Colors.green;
        statusLabel = 'OBRAĐENO';
        statusIcon = Icons.check_circle;
        break;
      case 'otkazivanje_putnika':
        statusColor = Colors.red;
        statusLabel = 'OTKAZANO';
        statusIcon = Icons.cancel;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Ovde možemo dodati neku akciju, npr. otvaranje profila putnika
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_dateFormat.format(createdAt)} ${_timeFormat.format(createdAt)}',
                    style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: _getPutnikName(putnikId),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Učitavanje...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
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
          Icon(Icons.inbox_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Nema zahteva u ovoj kategoriji' : 'Nema rezultata za pretragu',
            style: GoogleFonts.poppins(color: Colors.white70),
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
