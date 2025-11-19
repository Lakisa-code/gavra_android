import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/real_time_statistika_service.dart';
import '../theme.dart';
import '../widgets/realtime_error_widgets.dart';

/// 📊 WIDGET ZA DETALJNE STATISTIKE MESEČNIH PUTNIKA
///
/// Izdvojen iz mesecni_putnici_screen.dart za bolju organizaciju koda.
/// Sadrži kompletnu logiku za prikaz statistika putnika sa:
/// - Dropdown za odabir perioda (meseci, godina, ukupno)
/// - Osnovne informacije putnika
/// - Finansijske informacije (plaćanja, datum, vozač)
/// - Statistike putovanja za odabrani period
/// - Real-time stream podataka
/// - Error handling i offline podršku
class DetaljneStatistikeDialog extends StatefulWidget {
  final MesecniPutnik putnik;
  final Map<String, double> stvarnaPlacanja;
  final bool isConnected;
  final VoidCallback? onUpdated;

  const DetaljneStatistikeDialog({
    Key? key,
    required this.putnik,
    required this.stvarnaPlacanja,
    required this.isConnected,
    this.onUpdated,
  }) : super(key: key);

  @override
  State<DetaljneStatistikeDialog> createState() => _DetaljneStatistikeDialogState();
}

class _DetaljneStatistikeDialogState extends State<DetaljneStatistikeDialog> {
  late String _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = _getCurrentMonthYear();
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return '${_getMonthName(now.month)} ${now.year}';
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Jun',
      'Jul',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar',
    ];
    return months[month];
  }

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthName(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  bool _isMonthPaid(String monthYear, MesecniPutnik putnik) {
    final stvarniIznos = widget.stvarnaPlacanja[putnik.id] ?? 0;
    if (stvarniIznos <= 0) {
      return false;
    }

    // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
    final parts = monthYear.split(' ');
    if (parts.length != 2) return false;

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) return false;

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) return false;

    // 1. PRIORITET: Precizni podaci o plaćenom mesecu
    if (putnik.placeniMesec != null && putnik.placenaGodina != null) {
      return putnik.placeniMesec == monthNumber && putnik.placenaGodina == year;
    }

    // 2. FALLBACK: Koristi vreme plaćanja ako postoji
    if (putnik.vremePlacanja != null) {
      final paymentDate = putnik.vremePlacanja!;
      return paymentDate.year == year && paymentDate.month == monthNumber;
    }

    // 3. DODATNA LOGIKA: Ako putnik ima pozitivan iznos plaćanja, možda je plaćen za više meseci
    final mesecnaCena = putnik.cena ?? 0;
    if (mesecnaCena > 0 && stvarniIznos >= mesecnaCena) {
      return true;
    }

    return false;
  }

  int _getMonthNumber(String monthName) {
    const months = [
      '', // 0 - ne postoji
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
      'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];

    for (int i = 1; i < months.length; i++) {
      if (months[i] == monthName) {
        return i;
      }
    }
    return 0; // Ne postoji
  }

  String _formatDatum(DateTime datum) {
    return '${datum.day}.${datum.month}.${datum.year}';
  }

  // 📊 REAL-TIME STATISTIKE STREAM - SINHRONIZOVANO SA BAZOM
  Stream<Map<String, dynamic>> _streamStatistikeZaPeriod(
    String putnikId,
    String period,
  ) {
    // 🔄 KORISTI NOVI CENTRALIZOVANI REAL-TIME SERVIS
    return RealTimeStatistikaService.instance.getPutnikStatistikeStream(putnikId).asyncMap((baseStats) async {
      try {
        return await _getMesecneStatistike(putnikId);
      } catch (e) {
        return {
          'error': true,
          'message': e.toString(),
          'putovanja': 0,
          'otkazivanja': 0,
          'poslednje': 'Greška pri učitavanju',
          'uspesnost': 0,
        };
      }
    }).handleError((Object error) {
      return {
        'error': true,
        'message': error.toString(),
        'putovanja': 0,
        'otkazivanja': 0,
        'poslednje': 'Greška pri učitavanju',
        'uspesnost': 0,
      };
    });
  }

  // 📊 DOBIJ MESEČNE STATISTIKE ZA SEPTEMBAR 2025
  Future<Map<String, dynamic>> _getMesecneStatistike(String putnikId) async {
    try {
      final DateTime septembarStart = DateTime(2025, 9);
      final DateTime septembarEnd = DateTime(2025, 9, 30, 23, 59, 59);

      final String startStr = septembarStart.toIso8601String().split('T')[0];
      final String endStr = septembarEnd.toIso8601String().split('T')[0];

      // Dohvati sva putovanja za septembar 2025
      final response = await Supabase.instance.client
          .from('putovanja_istorija')
          .select()
          .eq('putnik_id', putnikId)
          .gte('datum_putovanja', startStr)
          .lte('datum_putovanja', endStr)
          .order('datum_putovanja', ascending: false);

      // Broji jedinstvene datume kada je pokupljen
      final Set<String> uspesniDatumi = {};
      final Set<String> otkazaniDatumi = {};
      String? poslednjiDatum;

      for (final red in response) {
        final datumPutovanja = red['datum_putovanja'] as String?;
        final status = red['status'] as String?;

        if (datumPutovanja != null) {
          if (poslednjiDatum == null) {
            poslednjiDatum = datumPutovanja;
          }

          if (status == 'pokupljen' || status == 'placeno') {
            uspesniDatumi.add(datumPutovanja);
          } else if (status == 'otkazan') {
            otkazaniDatumi.add(datumPutovanja);
          }
        }
      }

      final int putovanja = uspesniDatumi.length;
      final int otkazivanja = otkazaniDatumi.length;
      final int ukupno = putovanja + otkazivanja;
      final double uspesnost = ukupno > 0 ? (putovanja / ukupno * 100) : 0.0;

      return {
        'putovanja': putovanja,
        'otkazivanja': otkazivanja,
        'poslednje': poslednjiDatum ?? 'Nema podataka',
        'uspesnost': uspesnost.round(),
        'error': false,
      };
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
        'putovanja': 0,
        'otkazivanja': 0,
        'poslednje': 'Greška pri učitavanju',
        'uspesnost': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          gradient: Theme.of(context).backgroundGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).glassBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).glassContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).glassBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.white70, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detaljne statistike - ${widget.putnik.putnikIme}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodDropdown(),
                    const SizedBox(height: 16),
                    _buildStatistikeStream(),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).glassContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).glassBorder,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.6),
                    ),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Zatvori',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.white70,
          ),
          style: TextStyle(color: Colors.white),
          items: _getMonthOptions().map<DropdownMenuItem<String>>((String value) {
            // Proveri da li je mesec plaćen
            final bool isPlacen = _isMonthPaid(value, widget.putnik);

            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isPlacen ? Colors.green : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: isPlacen ? Colors.green[300] : Colors.white,
                      fontWeight: isPlacen ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList()
            ..addAll([
              // 📊 CELA GODINA I UKUPNO
              DropdownMenuItem(
                value: 'Cela 2025',
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 16,
                      color: Colors.blue[300],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cela 2025',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Ukupno',
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Colors.purple[300],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ukupno',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ]),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedPeriod = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatistikeStream() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _streamStatistikeZaPeriod(widget.putnik.id, _selectedPeriod),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        // Error handling
        if (snapshot.hasError) {
          return SizedBox(
            height: 200,
            child: StreamErrorWidget(
              streamName: 'MesecniPutniciStats',
              errorMessage: snapshot.error.toString(),
              onRetry: () {
                setState(() {});
              },
            ),
          );
        }

        // Check for data errors
        final stats = snapshot.data ?? {};
        if (stats['error'] == true) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Podaci trenutno nisu dostupni.\nPovežite se na internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange[300]),
                  ),
                  if (!widget.isConnected) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OFFLINE',
                        style: TextStyle(
                          color: Colors.red[300],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return _buildStatistikeContent(stats, _selectedPeriod);
      },
    );
  }

  Widget _buildStatistikeContent(Map<String, dynamic> stats, String period) {
    IconData periodIcon = Icons.calendar_today;

    // Posebni slučajevi
    if (period == 'Cela 2025') {
      periodIcon = Icons.event_note;
    } else if (period == 'Ukupno') {
      periodIcon = Icons.history;
    } else {
      // Meseci - koristiti kalendar ikonu
      periodIcon = Icons.calendar_today;
    }

    return Column(
      children: [
        // 🎯 OSNOVNE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).glassContainer,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📋 Osnovne informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: const Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow('👤 Ime:', widget.putnik.putnikIme),
              _buildStatRow('📅 Radni dani:', widget.putnik.radniDani),
              _buildStatRow('📊 Tip putnika:', widget.putnik.tip),
              if (widget.putnik.tipSkole != null)
                _buildStatRow(
                  widget.putnik.tip == 'ucenik' ? '🎓 Škola:' : '🏢 Ustanova/Firma:',
                  widget.putnik.tipSkole!,
                ),
              if (widget.putnik.brojTelefona != null) _buildStatRow('📞 Telefon:', widget.putnik.brojTelefona!),
            ],
          ),
        ),

        // 💰 FINANSIJSKE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).glassContainer,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💰 Finansijske informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: const Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                '💵 Poslednje plaćanje:',
                (widget.stvarnaPlacanja[widget.putnik.id] ?? 0) > 0
                    ? '${(widget.stvarnaPlacanja[widget.putnik.id]!).toStringAsFixed(0)} RSD'
                    : 'Nema podataka o ceni',
              ),
              _buildStatRow(
                '📅 Datum plaćanja:',
                widget.putnik.vremePlacanja != null
                    ? _formatDatum(widget.putnik.vremePlacanja!)
                    : 'Nema podataka o datumu',
              ),
              // 🔍 Vozač koji je naplatio - async loading
              StreamBuilder<String?>(
                stream: MesecniPutnikService.streamVozacPoslednjegPlacanja(widget.putnik.id),
                builder: (context, snapshot) {
                  final vozacIme = snapshot.data ?? 'Učitava...';
                  return _buildStatRow('🚗 Vozač (naplata):', vozacIme);
                },
              ),
            ],
          ),
        ),

        // 📈 STATISTIKE PUTOVANJA - DINAMICKI PERIOD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).glassContainer,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    periodIcon,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '📈 Statistike - $period',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          offset: const Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatRow('🚗 Putovanja:', '${stats['putovanja'] ?? 0}'),
              _buildStatRow('❌ Otkazivanja:', '${stats['otkazivanja'] ?? 0}'),
              _buildStatRow(
                '📈 Uspešnost:',
                '${stats['uspesnost'] ?? 0}%',
              ),
              _buildStatRow('📅 Poslednje:', stats['poslednje'] ?? 'Nema podataka'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
