import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/putnik_service.dart';
import '../services/vozac_mapping_service.dart';
import '../services/voznje_log_service.dart';

class MLDnevnikScreen extends StatefulWidget {
  const MLDnevnikScreen({
    super.key,
    this.filterVozacIme,
    this.showOnlyPutnici = false,
    this.showOnlyVozaci = false,
    this.onlyType,
  });
  final String? filterVozacIme;
  final bool showOnlyPutnici;
  final bool showOnlyVozaci;
  final String? onlyType; // 'radnik' ili 'ucenik'

  @override
  State<MLDnevnikScreen> createState() => _MLDnevnikScreenState();
}

class _MLDnevnikScreenState extends State<MLDnevnikScreen> {
  final Map<String, String> _putnikNamesCache = {};
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateFormat = DateFormat('dd.MM');
  String _searchQuery = '';

  /// 📦 Keširanje imena putnika u serijama
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
          .select('id, putnik_ime')
          .inFilter('id', idsToFetch.toList());

      for (var p in response) {
        _putnikNamesCache[p['id'].toString()] = p['putnik_ime'].toString();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Precache error (Dnevnik): $e');
    }
  }

  String _getPutnikNameSync(dynamic id) {
    if (id == null) return 'Sistem';
    return _putnikNamesCache[id.toString()] ?? '...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.onlyType != null
                  ? (widget.onlyType == 'ucenik'
                      ? 'Akcije Učenika 🎓'
                      : widget.onlyType == 'dnevni'
                          ? 'Dnevni Putnici 📅'
                          : 'Akcije Radnika 👷')
                  : widget.showOnlyPutnici
                      ? 'Akcije Putnika 👥'
                      : widget.showOnlyVozaci
                          ? 'Akcije Vozača 🚐'
                          : widget.filterVozacIme != null
                              ? 'Dnevnik: ${widget.filterVozacIme} 📖'
                              : 'Dnevnik Akcija 📖',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_searchQuery.isNotEmpty)
              Text('Filter: $_searchQuery', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: widget.showOnlyPutnici ? Colors.orange.shade900 : Colors.indigo.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                widget.showOnlyPutnici ? [Colors.orange.shade50, Colors.white] : [Colors.indigo.shade50, Colors.white],
          ),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.showOnlyPutnici
              ? VoznjeLogService.streamAllRecentLogs(limit: 200).map((logs) => logs.where((l) {
                    final tip = l['tip']?.toString() ?? '';
                    final detalji = l['detalji']?.toString().toLowerCase() ?? '';
                    // Putničke akcije su one koje NEMAJU vozac_id, ILI imaju putnik_id
                    // ali isključujemo čisto vozačke tipove
                    final isPassengerAction = (l['vozac_id'] == null || l['putnik_id'] != null) &&
                        tip != 'voznja' &&
                        tip != 'prijava_vozaca' &&
                        tip != 'odjava_vozaca';

                    if (!isPassengerAction) return false;

                    // Filter po tipu (ako je zadat)
                    if (widget.onlyType != null) {
                      final target = widget.onlyType!.toLowerCase();
                      final metaTip = l['meta']?['putnik_tip']?.toString().toLowerCase();

                      if (target == 'ucenik') {
                        return metaTip == 'ucenik' || detalji.contains('ucenik') || detalji.contains('učenik');
                      }
                      if (target == 'radnik') {
                        return metaTip == 'radnik' || detalji.contains('radnik') || tip == 'potvrda_zakazivanja';
                      }
                      return metaTip == target || detalji.contains(target);
                    }

                    return true;
                  }).toList())
              : widget.showOnlyVozaci
                  ? VoznjeLogService.streamAllRecentLogs(limit: 200).map((logs) {
                      return logs.where((l) {
                        final vozacId = l['vozac_id'];
                        final tip = l['tip']?.toString() ?? '';
                        // Vozačke akcije su one koje imaju vozac_id ILI su tipa 'admin_akcija' a tiču se vozača (mada obično imaju vozac_id)
                        return vozacId != null || tip == 'voznja' || tip == 'prijava_vozaca' || tip == 'odjava_vozaca';
                      }).toList();
                    })
                  : widget.filterVozacIme != null
                      ? VoznjeLogService.streamRecentLogs(vozacIme: widget.filterVozacIme!, limit: 100)
                      : VoznjeLogService.streamAllRecentLogs(limit: 150),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Greška: ${snapshot.error}'));
            }
            var logs = snapshot.data ?? [];

            // 📦 Pokreni keširanje imena
            if (logs.isNotEmpty) {
              _precacheNames(logs);
            }

            // SEARCH FILTER
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              logs = logs.where((l) {
                final detalji = l['detalji']?.toString().toLowerCase() ?? '';
                final tip = l['tip']?.toString().toLowerCase() ?? '';
                final vId = l['vozac_id']?.toString() ?? '';
                return detalji.contains(query) || tip.contains(query) || vId.contains(query);
              }).toList();
            }

            if (logs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty ? 'Nema zabeleženih akcija.' : 'Nema rezultata za: "$_searchQuery"',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return _buildLogItem(logs[index]);
              },
            );
          },
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog<String>(
      context: context,
      builder: (context) {
        String input = _searchQuery;
        return AlertDialog(
          title: const Text('Pretraži dnevnik'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ime, tip akcije ili detalji...'),
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

  Widget _buildLogItem(Map<String, dynamic> log) {
    final type = log['tip']?.toString() ?? 'nepoznato';
    final createdAtStr = log['created_at']?.toString() ?? '';
    final createdAt = (DateTime.tryParse(createdAtStr) ?? DateTime.now()).toLocal();
    final vozacId = log['vozac_id']?.toString();
    final putnikId = log['putnik_id'];
    final iznos = (log['iznos'] ?? log['meta']?['iznos'])?.toString();
    final datum = log['datum']?.toString() ?? '';
    final detalji = log['detalji']?.toString() ?? '';

    final isDriverAction = vozacId != null;
    final vozacName = isDriverAction ? (VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? vozacId) : 'Sistem';

    Color themeColor;
    IconData iconData;
    String actionLabel;

    switch (type) {
      case 'voznja':
        iconData = Icons.local_taxi;
        themeColor = Colors.blue;
        actionLabel = 'Realizovana vožnja';
        break;
      case 'uplata':
      case 'uplata_dnevna':
        iconData = Icons.account_balance_wallet;
        themeColor = Colors.green;
        actionLabel = 'Dnevna uplata (${iznos ?? '0'} RSD)';
        break;
      case 'uplata_mesecna':
        iconData = Icons.calendar_month;
        themeColor = Colors.teal;
        actionLabel = 'Mesečna uplata (${iznos ?? '0'} RSD)';
        break;
      case 'bolovanje':
        iconData = Icons.medical_services;
        themeColor = Colors.red.shade400;
        actionLabel = 'Bolovanje';
        break;
      case 'godisnji':
        iconData = Icons.beach_access;
        themeColor = Colors.orange;
        actionLabel = 'Godišnji odmor';
        break;
      case 'licno':
        iconData = Icons.person_off;
        themeColor = Colors.brown;
        actionLabel = 'Lično odsustvo';
        break;
      case 'otkazivanje':
        iconData = Icons.block;
        themeColor = Colors.red;
        actionLabel = 'Otkazano od strane vozača';
        break;
      case 'prijava':
        iconData = Icons.fingerprint;
        themeColor = Colors.purple;
        actionLabel = 'Prijava u aplikaciju';
        break;
      case 'odsustvo':
        iconData = Icons.event_busy;
        themeColor = Colors.orange;
        actionLabel = 'Odsustvo (Opšte)';
        break;
      case 'povratak_na_posao':
        iconData = Icons.check_circle;
        themeColor = Colors.teal;
        actionLabel = 'Povratak na posao';
        break;
      case 'zakazivanje_putnika':
        iconData = Icons.notification_add;
        themeColor = Colors.indigo;
        actionLabel = 'Zahtev dodat';
        break;
      case 'potvrda_zakazivanja':
        iconData = Icons.check_circle_outline;
        themeColor = Colors.green.shade700;
        if (detalji.contains('Sistem')) {
          actionLabel = 'Sistem potvrdio';
        } else {
          actionLabel = 'Uspešno obrađeno';
        }
        break;
      case 'otkazivanje_putnika':
        iconData = Icons.event_available_outlined;
        themeColor = Colors.deepOrange;
        if (detalji.contains('Sistem')) {
          actionLabel = 'Sistem uklonio';
        } else {
          actionLabel = 'Putnik otkazao termin';
        }
        break;
      case 'admin_akcija':
        iconData = Icons.admin_panel_settings;
        themeColor = Colors.red.shade900;
        actionLabel = 'Admin Akcija';
        break;
      default:
        iconData = Icons.explore;
        themeColor = Colors.blueGrey;
        actionLabel = type.toUpperCase().replaceAll('_', ' ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Builder(
        builder: (context) {
          final putnikName = _getPutnikNameSync(putnikId);
          final primaryName = isDriverAction ? vozacName : putnikName;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIME & ICON
                Column(
                  children: [
                    Text(
                      _timeFormat.format(createdAt),
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: themeColor, size: 22),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // BODY
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              primaryName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.indigo.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _dateFormat.format(createdAt),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (isDriverAction)
                        Text(
                          'Putnik: $putnikName',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              detalji.contains('Sistem') ? Icons.bolt : Icons.person,
                              size: 12,
                              color: detalji.contains('Sistem') ? Colors.red : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              detalji.contains('Sistem') ? 'Sistemska akcija' : 'Samostalna akcija',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: detalji.contains('Sistem') ? Colors.red.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      const Divider(height: 16, thickness: 0.5),
                      // ACTION LABEL
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (datum.isNotEmpty && type == 'voznja')
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'D: $datum',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                      if (detalji.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              detalji,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blueGrey.shade800,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
