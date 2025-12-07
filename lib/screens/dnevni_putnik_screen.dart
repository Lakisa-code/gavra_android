import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// 📱 Ekran za odobrenog dnevnog putnika
/// Može da pošalje zahtev za vožnju
class DnevniPutnikScreen extends StatefulWidget {
  final String putnikId;
  final String ime;
  final String prezime;

  const DnevniPutnikScreen({
    super.key,
    required this.putnikId,
    required this.ime,
    required this.prezime,
  });

  @override
  State<DnevniPutnikScreen> createState() => _DnevniPutnikScreenState();
}

class _DnevniPutnikScreenState extends State<DnevniPutnikScreen> {
  final _supabase = Supabase.instance.client;

  // Forma
  String _smer = 'BC_VS'; // BC_VS ili VS_BC
  DateTime _datum = DateTime.now();
  TimeOfDay _vreme = const TimeOfDay(hour: 7, minute: 0);
  int _brojPutnika = 1;
  final _napomenaController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _mojiZahtevi = [];

  @override
  void initState() {
    super.initState();
    _ucitajMojeZahteve();
  }

  @override
  void dispose() {
    _napomenaController.dispose();
    super.dispose();
  }

  Future<void> _ucitajMojeZahteve() async {
    try {
      // Dohvati podatke registrovanog putnika
      final putnikData =
          await _supabase.from('dnevni_putnici_registrovani').select('telefon').eq('id', widget.putnikId).single();

      final telefon = putnikData['telefon'] as String;

      // Dohvati vožnje tog putnika po telefonu
      final response = await _supabase
          .from('dnevni_putnici')
          .select()
          .eq('telefon', telefon)
          .eq('obrisan', false)
          .order('datum_putovanja', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _mojiZahtevi = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Greška pri učitavanju zahteva: $e');
    }
  }

  Future<void> _posaljiZahtev() async {
    setState(() => _isLoading = true);

    try {
      // Dohvati podatke registrovanog putnika
      final putnikData = await _supabase
          .from('dnevni_putnici_registrovani')
          .select('ime, prezime, telefon, grad')
          .eq('id', widget.putnikId)
          .single();

      final datumStr = DateFormat('yyyy-MM-dd').format(_datum);
      final vremeStr = '${_vreme.hour.toString().padLeft(2, '0')}:${_vreme.minute.toString().padLeft(2, '0')}';

      // Kreiraj zahtev za vožnju u dnevni_putnici tabeli
      await _supabase.from('dnevni_putnici').insert({
        'putnik_ime': '${putnikData['ime']} ${putnikData['prezime']}',
        'telefon': putnikData['telefon'],
        'grad': putnikData['grad'],
        'datum_putovanja': datumStr,
        'vreme_polaska': vremeStr,
        'broj_mesta': _brojPutnika,
        'status': 'kreiran',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zahtev za vožnju je poslat!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset forme
        _napomenaController.clear();
        setState(() {
          _brojPutnika = 1;
          _datum = DateTime.now();
        });

        // Osveži listu
        _ucitajMojeZahteve();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _izaberiDatum() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('sr', 'RS'),
    );
    if (picked != null) {
      setState(() => _datum = picked);
    }
  }

  Future<void> _izaberiVreme() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _vreme,
    );
    if (picked != null) {
      setState(() => _vreme = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: tripleBlueFashionGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zdravo, ${widget.ime}! 👋',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dnevni putnik',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.logout),
                            tooltip: 'Odjavi se',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Forma za zahtev
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).glassContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).glassBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_car, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              'Zakaži vožnju',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Smer
                        const Text(
                          'Smer putovanja',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSmerButton(
                                'BC_VS',
                                'Bela Crkva → Vršac',
                                Icons.arrow_forward,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSmerButton(
                                'VS_BC',
                                'Vršac → Bela Crkva',
                                Icons.arrow_back,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Datum i vreme
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Datum',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _izaberiDatum,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 20, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                DateFormat('dd.MM.yyyy').format(_datum),
                                                style: const TextStyle(fontSize: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Vreme',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _izaberiVreme,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 20, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_vreme.hour.toString().padLeft(2, '0')}:${_vreme.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Broj putnika
                        const Text(
                          'Broj putnika',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _brojPutnika > 1 ? () => setState(() => _brojPutnika--) : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.white,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_brojPutnika',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _brojPutnika < 8 ? () => setState(() => _brojPutnika++) : null,
                              icon: const Icon(Icons.add_circle_outline),
                              color: Colors.white,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Dugme za slanje
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _posaljiZahtev,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send),
                                      SizedBox(width: 8),
                                      Text(
                                        'Pošalji zahtev',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Moji zahtevi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Moji zahtevi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Lista zahteva
              if (_mojiZahtevi.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(
                        'Nemaš prethodnih zahteva',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final zahtev = _mojiZahtevi[index];
                      return _buildZahtevCard(zahtev);
                    },
                    childCount: _mojiZahtevi.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmerButton(String value, String label, IconData icon) {
    final isSelected = _smer == value;
    return InkWell(
      onTap: () => setState(() => _smer = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZahtevCard(Map<String, dynamic> zahtev) {
    final status = zahtev['status'] as String? ?? 'pending';
    final datum = zahtev['datum'] as String? ?? '';
    final vreme = zahtev['vreme'] as String? ?? '';
    final smer = zahtev['smer'] as String? ?? '';
    final brojPutnika = zahtev['broj_putnika'] as int? ?? 1;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Odobreno';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Odbijeno';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Na čekanju';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Status ikona
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 12),

          // Detalji
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  smer == 'BC_VS' ? 'BC → VS' : 'VS → BC',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$datum u $vreme • $brojPutnika putnik${brojPutnika > 1 ? 'a' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
