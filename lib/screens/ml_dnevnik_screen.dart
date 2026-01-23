import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/putnik_service.dart';
import '../services/vozac_mapping_service.dart';
import '../services/voznje_log_service.dart';

class MLDnevnikScreen extends StatefulWidget {
  const MLDnevnikScreen({super.key, this.filterVozacIme, this.showOnlyPutnici = false});
  final String? filterVozacIme;
  final bool showOnlyPutnici;

  @override
  State<MLDnevnikScreen> createState() => _MLDnevnikScreenState();
}

class _MLDnevnikScreenState extends State<MLDnevnikScreen> {
  final Map<String, String> _putnikNamesCache = {};
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  Future<String> _getPutnikName(dynamic id) async {
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
      appBar: AppBar(
        title: Text(
          widget.showOnlyPutnici
              ? 'Akcije Putnika 👥'
              : widget.filterVozacIme != null
                  ? 'Dnevnik: ${widget.filterVozacIme} 📖'
                  : 'Dnevnik Akcija 📖',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: widget.showOnlyPutnici ? Colors.orange.shade800 : Colors.indigo.shade800,
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
              ? VoznjeLogService.streamAllRecentLogs(limit: 150).map((logs) => logs.where((l) {
                    final tip = l['tip']?.toString() ?? '';
                    // Putničke akcije su one gde je vozac_id NULL
                    // ALI moramo isključiti 'voznja' (pokupljen) jer to nije akcija koju putnik sam preduzima
                    return l['vozac_id'] == null && tip != 'voznja';
                  }).toList())
              : widget.filterVozacIme != null
                  ? VoznjeLogService.streamRecentLogs(vozacIme: widget.filterVozacIme!, limit: 100)
                  : VoznjeLogService.streamAllRecentLogs(limit: 100),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Greška: ${snapshot.error}'));
            }
            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return const Center(child: Text('Nema zabeleženih akcija.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildLogItem(log);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final type = log['tip']?.toString() ?? 'nepoznato';
    final createdAtStr = log['created_at']?.toString() ?? '';
    // Supabase vraća UTC vreme, .toLocal() ga konvertuje u lokalno vreme telefona
    // Korisnik je tražio da vreme ide 1 sat unapred u odnosu na regularno lokalno
    final createdAt = (DateTime.tryParse(createdAtStr) ?? DateTime.now()).toLocal().add(const Duration(hours: 1));
    final vozacId = log['vozac_id']?.toString();
    final putnikId = log['putnik_id'];
    final iznos = log['iznos']?.toString();
    final datum = log['datum']?.toString() ?? '';
    final detalji = log['detalji']?.toString() ?? '';

    // Resolving labels
    final vozacName =
        vozacId != null ? (VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? vozacId) : 'Sistem';

    Color iconColor;
    IconData iconData;
    String actionLabel;

    switch (type) {
      case 'voznja':
        iconData = Icons.person_pin_circle;
        iconColor = Colors.blue;
        actionLabel = 'Pokupljen';
        break;
      case 'uplata':
      case 'uplata_dnevna':
      case 'uplata_mesecna':
        iconData = Icons.payments;
        iconColor = Colors.green;
        actionLabel = 'Plaćeno (${iznos ?? '0'} RSD)';
        break;
      case 'otkazivanje':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        actionLabel = 'Otkazano';
        break;
      case 'prijava':
        iconData = Icons.login;
        iconColor = Colors.purple;
        actionLabel = 'Prijavio se u aplikaciju';
        break;
      case 'odsustvo':
        iconData = Icons.beach_access;
        iconColor = Colors.orange;
        actionLabel = 'Postavljeno odsustvo';
        break;
      case 'povratak_na_posao':
        iconData = Icons.work;
        iconColor = Colors.teal;
        actionLabel = 'Povratak na posao';
        break;
      case 'zakazivanje_putnika':
        iconData = Icons.add_alarm;
        iconColor = Colors.blue;
        actionLabel = 'Zahtev za termin';
        break;
      case 'otkazivanje_putnika':
        iconData = Icons.calendar_today_outlined;
        iconColor = Colors.red;
        actionLabel = 'Otkazivanje termina';
        break;
      default:
        iconData = Icons.info;
        iconColor = Colors.grey;
        actionLabel = type.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: FutureBuilder<String>(
        future: _getPutnikName(putnikId),
        builder: (context, snapshot) {
          final putnikName = snapshot.data ?? 'Učitavam...';

          // Ako je akciju uradio putnik (nema vozacId), on je primarni "glumac" u logu
          final primaryName = vozacId != null ? vozacName : putnikName;
          final secondaryName = vozacId != null ? putnikName : 'Direktna akcija putnika';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline/Icon section
              Column(
                children: [
                  Text(
                    _timeFormat.format(createdAt),
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Content section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          primaryName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _dateFormat.format(createdAt),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.indigo.shade700,
                        fontStyle: vozacId == null ? FontStyle.italic : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ),
                    if (detalji.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          detalji,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ),
                    if (datum.isNotEmpty &&
                        type != 'prijava' &&
                        type != 'zakazivanje_putnika' &&
                        type != 'otkazivanje_putnika')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Za datum: $datum',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    if (type == 'uplata')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Iznos: ${log['iznos'] ?? log['meta']?['iznos'] ?? '0'} RSD',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
