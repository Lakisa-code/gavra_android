import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/real_time_statistika_service.dart'; // ✅ DODANO - novi real-time servis
import 'mesecni_putnik_detalji_screen.dart'; // ✅ DODANO za statistike

class MesecniPutniciScreen extends StatefulWidget {
  const MesecniPutniciScreen({Key? key}) : super(key: key);

  @override
  State<MesecniPutniciScreen> createState() => _MesecniPutniciScreenState();
}

class _MesecniPutniciScreenState extends State<MesecniPutniciScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'svi'; // 'svi', 'radnik', 'ucenik'

  // Supabase klijent
  final SupabaseClient supabase = Supabase.instance.client;

  // 🔄 OPTIMIZACIJA: Debounced search stream i filter stream
  late final BehaviorSubject<String> _searchSubject;
  late final BehaviorSubject<String> _filterSubject;
  late final Stream<String> _debouncedSearchStream;

  // 🔄 OPTIMIZACIJA: Connection resilience
  late final StreamSubscription? _connectionSubscription;
  bool _isConnected = true;

  // Promenljive za dodavanje/editovanje putnika
  String _novoIme = '';
  String _noviTip = 'radnik';
  String _novaTipSkole = '';
  String _noviBrojTelefona = '';
  String _novaAdresaBelaCrkva = '';
  String _novaAdresaVrsac = '';
  String _noviPolazakBelaCrkva = '';
  String _noviPolazakVrsac = '';

  // 📅 RADNI DANI - checkbox state
  Map<String, bool> _noviRadniDani = {
    'pon': true,
    'uto': true,
    'sre': true,
    'cet': true,
    'pet': true,
  };

  // Helper metod za konverziju radnih dana u string
  String _getRadniDaniString() {
    final List<String> odabraniDani = [];
    _noviRadniDani.forEach((dan, selected) {
      if (selected) {
        odabraniDani.add(dan);
      }
    });
    return odabraniDani.join(',');
  }

  // Helper metod za parsiranje radnih dana iz string-a
  void _setRadniDaniFromString(String radniDaniStr) {
    final daniList = radniDaniStr.split(',');
    _noviRadniDani = {
      'pon': daniList.contains('pon'),
      'uto': daniList.contains('uto'),
      'sre': daniList.contains('sre'),
      'cet': daniList.contains('cet'),
      'pet': daniList.contains('pet'),
    };
  }

  // TextEditingController-i za edit dialog
  late TextEditingController _imeController;
  late TextEditingController _tipSkoleController;
  late TextEditingController _brojTelefonaController;
  late TextEditingController _adresaBelaCrkvaController;
  late TextEditingController _adresaVrsacController;
  late TextEditingController _polazakBelaCrkvaController;
  late TextEditingController _polazakVrsacController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeOptimizations();
  }

  void _initializeControllers() {
    _imeController = TextEditingController();
    _tipSkoleController = TextEditingController();
    _brojTelefonaController = TextEditingController();
    _adresaBelaCrkvaController = TextEditingController();
    _adresaVrsacController = TextEditingController();
    _polazakBelaCrkvaController = TextEditingController();
    _polazakVrsacController = TextEditingController();
  }

  // 🔄 OPTIMIZACIJA: Inicijalizacija debounced search i error handling
  void _initializeOptimizations() {
    // Debounced search stream sa seeded vrednostima
    _searchSubject = BehaviorSubject<String>.seeded('');
    _filterSubject = BehaviorSubject<String>.seeded('svi');
    _debouncedSearchStream = _searchSubject
        .debounceTime(const Duration(milliseconds: 300))
        .distinct();

    // Listen za search promene
    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });

    // Connection monitoring (placeholder - možete proširiti)
    _isConnected = true;
  }

  @override
  void dispose() {
    // 🔄 OPTIMIZACIJA: Cleanup resources
    _searchSubject.close();
    _filterSubject.close();
    _connectionSubscription?.cancel();

    _searchController.dispose();
    _imeController.dispose();
    _tipSkoleController.dispose();
    _brojTelefonaController.dispose();
    _adresaBelaCrkvaController.dispose();
    _adresaVrsacController.dispose();
    _polazakBelaCrkvaController.dispose();
    _polazakVrsacController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x304F7EFC),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Color(0x204F7EFC),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
        ),
        title: const Text('Mesečni Putnici',
            style: TextStyle(color: Colors.white)),
        actions: [
          // Filter za radnike sa brojem
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.engineering,
                  color: _selectedFilter == 'radnik'
                      ? Colors.white
                      : Colors.white70,
                ),
                onPressed: () {
                  // 🔄 OPTIMIZOVANO: Stream update umesto setState
                  final newFilter =
                      _selectedFilter == 'radnik' ? 'svi' : 'radnik';
                  _selectedFilter = newFilter;
                  _filterSubject.add(newFilter);
                },
                tooltip: 'Filtriraj radnike',
              ),
              Positioned(
                right: 0,
                top: 0,
                child: StreamBuilder<List<MesecniPutnik>>(
                  stream: MesecniPutnikService.streamMesecniPutnici(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final brojRadnika = snapshot.data!
                        .where((p) =>
                            p.tip == 'radnik' &&
                            p.aktivan &&
                            !p.obrisan &&
                            p.status.toLowerCase() != 'godisnji' &&
                            p.status.toLowerCase() != 'bolovanje')
                        .length;
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$brojRadnika',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Filter za učenike sa brojem
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.school,
                  color: _selectedFilter == 'ucenik'
                      ? Colors.white
                      : Colors.white70,
                ),
                onPressed: () {
                  // 🔄 OPTIMIZOVANO: Stream update umesto setState
                  final newFilter =
                      _selectedFilter == 'ucenik' ? 'svi' : 'ucenik';
                  _selectedFilter = newFilter;
                  _filterSubject.add(newFilter);
                },
                tooltip: 'Filtriraj učenike',
              ),
              Positioned(
                right: 0,
                top: 0,
                child: StreamBuilder<List<MesecniPutnik>>(
                  stream: MesecniPutnikService.streamMesecniPutnici(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final brojUcenika = snapshot.data!
                        .where((p) =>
                            p.tip == 'ucenik' &&
                            p.aktivan &&
                            !p.obrisan &&
                            p.status.toLowerCase() != 'godisnji' &&
                            p.status.toLowerCase() != 'bolovanje')
                        .length;
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$brojUcenika',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _pokaziDijalogZaDodavanje(),
            tooltip: 'Dodaj novog putnika',
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textCapitalization:
                  TextCapitalization.words, // 🔤 Prvo slovo veliko za pretragu
              decoration: InputDecoration(
                hintText: 'Pretraži putnike...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          // 🔄 OPTIMIZOVANO: Ne koristimo setState, stream će se ažurirati automatski
                        },
                      )
                    : null,
              ),
              // 🔄 OPTIMIZOVANO: Uklonjen onChanged - debounced stream radi automatski
            ),
          ),

          const SizedBox(height: 16),

          // 📋 LISTA PUTNIKA - 🔄 OPTIMIZOVANO: CombineLatest streams za reaktivno filtriranje
          Expanded(
            child: StreamBuilder<List<MesecniPutnik>>(
              stream: Rx.combineLatest3(
                MesecniPutnikService.streamMesecniPutnici(),
                _debouncedSearchStream,
                _filterSubject.stream,
                (List<MesecniPutnik> putnici, String searchTerm,
                    String filterType) {
                  // Filtriranje po search terme i tipu putnika
                  return putnici.where((putnik) {
                    // Filtriraj po search termu
                    bool matchesSearch = true;
                    if (searchTerm.isNotEmpty) {
                      final search = searchTerm.toLowerCase();
                      matchesSearch =
                          putnik.putnikIme.toLowerCase().contains(search) ||
                              (putnik.brojTelefona
                                      ?.toLowerCase()
                                      .contains(search) ??
                                  false) ||
                              putnik.tip.toLowerCase().contains(search);
                    }

                    // Filtriraj po tipu putnika
                    bool matchesType = true;
                    if (filterType != 'svi') {
                      matchesType = putnik.tip == filterType;
                    }

                    return matchesSearch && matchesType;
                  }).toList();
                },
              ),
              builder: (context, snapshot) {
                // 🔄 OPTIMIZOVANO: Enhanced error handling sa retry opcijom
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isConnected ? Icons.error : Icons.wifi_off,
                            size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected
                              ? 'Greška pri učitavanju putnika'
                              : 'Nema konekcije',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                            color: Colors.red.shade400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}), // Trigger rebuild
                          icon: const Icon(Icons.refresh),
                          label: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredPutnici = snapshot.data ?? [];

                // Sortiranje: prvo po aktivnosti (aktivni gore), zatim po abecednom redu
                filteredPutnici.sort((a, b) {
                  // Prvo sortiranje po aktivnosti - aktivni gore (true > false)
                  if (a.aktivan != b.aktivan) {
                    return b.aktivan ? 1 : -1; // aktivni (true) idu gore
                  }
                  // Ako je isti status aktivnosti, sortiranje po abecednom redu
                  return a.putnikIme
                      .toLowerCase()
                      .compareTo(b.putnikIme.toLowerCase());
                });

                if (filteredPutnici.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Nema rezultata pretrage'
                              : 'Nema mesečnih putnika',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pokušajte sa drugim terminom',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPutnici.length,
                  itemBuilder: (context, index) {
                    final putnik = filteredPutnici[index];
                    return _buildPutnikCard(putnik, index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPutnikCard(MesecniPutnik putnik, int redniBroj) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 HEADER - Ime, broj i aktivnost switch
            Row(
              children: [
                // Redni broj i ime
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '$redniBroj.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          putnik.putnikIme,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Switch za aktivnost
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      putnik.aktivan ? 'AKTIVAN' : 'PAUZIRAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: putnik.aktivan ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: putnik.aktivan,
                      onChanged: (value) => _toggleAktivnost(putnik),
                      activeColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 📝 OSNOVNE INFORMACIJE - tip, telefon, škola, statistike u jednom redu
            Row(
              children: [
                // Tip putnika
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(
                        putnik.tip == 'radnik'
                            ? Icons.engineering
                            : Icons.school,
                        size: 16,
                        color: putnik.tip == 'radnik'
                            ? Colors.blue.shade600
                            : Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        putnik.tip.toUpperCase(),
                        style: TextStyle(
                          color: putnik.tip == 'radnik'
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Telefon (ako postoji)
                if (putnik.brojTelefona != null)
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(Icons.phone,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          putnik.brojTelefona!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tip škole (ako postoji)
                if (putnik.tipSkole != null)
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            putnik.tipSkole!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 💰 PLAĆANJE I STATISTIKE - jednostavan red
            Row(
              children: [
                // 💰 DUGME ZA PLAĆANJE - kompaktno
                SizedBox(
                  height: 26,
                  child: ElevatedButton.icon(
                    onPressed: () => _prikaziPlacanje(putnik),
                    icon: Icon(
                      putnik.cena != null && putnik.cena! > 0
                          ? Icons.check_circle_outline
                          : Icons.payments_outlined,
                      size: 14,
                    ),
                    label: Text(
                      putnik.cena != null && putnik.cena! > 0
                          ? '${putnik.cena!.toStringAsFixed(0)}din'
                          : 'Plati',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: putnik.cena != null && putnik.cena! > 0
                          ? Colors.green.shade50
                          : Colors.purple.shade50,
                      foregroundColor: putnik.cena != null && putnik.cena! > 0
                          ? Colors.green.shade700
                          : Colors.purple.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      side: BorderSide(
                        color: putnik.cena != null && putnik.cena! > 0
                            ? Colors.green.shade200
                            : Colors.purple.shade200,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Statistike putovanja i otkazivanja
                Row(
                  children: [
                    _buildCompactStatsPill(
                      '${putnik.brojPutovanja}',
                      Colors.green,
                      Icons.trending_up,
                    ),
                    const SizedBox(width: 6),
                    _buildCompactStatsPill(
                      '${putnik.brojOtkazivanja}',
                      Colors.orange,
                      Icons.cancel_outlined,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🎛️ ACTION BUTTONS - samo najvažnije
            Row(
              children: [
                // Pozovi (ako ima telefon)
                if (putnik.brojTelefona != null) ...[
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _pozoviBroj(putnik.brojTelefona!),
                      icon: Icons.phone,
                      label: 'Pozovi',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Uredi
                Expanded(
                  child: _buildCompactActionButton(
                    onPressed: () => _editPutnik(putnik),
                    icon: Icons.edit_outlined,
                    label: 'Uredi',
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(width: 6),

                // Menu sa opcijama (detalji i obriši)
                Expanded(
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'detalji':
                          _prikaziDetaljeStatistike(putnik);
                          break;
                        case 'obrisi':
                          _obrisiPutnika(putnik);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'detalji',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Detalji'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'obrisi',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Obriši', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.3), width: 1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.more_vert, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Opcije',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatsPill(String number, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            number,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: 28, // Još manja visina za 4 dugmeta u redu
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14), // Još manji ikon
        label: Text(
          label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500), // Manji tekst
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6), // Manji radius
            side: BorderSide(color: color.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2), // Manji padding
        ),
      ),
    );
  }

  void _toggleAktivnost(MesecniPutnik putnik) async {
    final success =
        await MesecniPutnikService.toggleAktivnost(putnik.id, !putnik.aktivan);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${putnik.putnikIme} je ${!putnik.aktivan ? "aktiviran" : "deaktiviran"}',
          ),
          backgroundColor: !putnik.aktivan ? Colors.green : Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri promeni statusa'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPutnik(MesecniPutnik putnik) {
    // Postavi vrednosti za edit
    setState(() {
      _novoIme = putnik.putnikIme;
      _noviTip = putnik.tip;
      _novaTipSkole = putnik.tipSkole ?? '';
      _noviBrojTelefona = putnik.brojTelefona ?? '';
      _novaAdresaBelaCrkva = putnik.adresaBelaCrkva ?? '';
      _novaAdresaVrsac = putnik.adresaVrsac ?? '';
      _noviPolazakBelaCrkva = putnik.polazakBelaCrkva ?? '';
      _noviPolazakVrsac = putnik.polazakVrsac ?? '';

      // ✅ DODANO - učitaj postojeće radne dane
      _setRadniDaniFromString(putnik.radniDani);

      // Postavi vrednosti u controller-e
      _imeController.text = _novoIme;
      _tipSkoleController.text = _novaTipSkole;
      _brojTelefonaController.text = _noviBrojTelefona;
      _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
      _adresaVrsacController.text = _novaAdresaVrsac;
      _polazakBelaCrkvaController.text = _noviPolazakBelaCrkva;
      _polazakVrsacController.text = _noviPolazakVrsac;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uredi mesečnog putnika'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => _novoIme = value,
                textCapitalization:
                    TextCapitalization.words, // 🔤 Prvo slovo veliko za ime
                decoration: const InputDecoration(
                  labelText: 'Ime putnika *',
                  border: OutlineInputBorder(),
                ),
                controller: _imeController,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _noviTip,
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'radnik', child: Text('Radnik')),
                  DropdownMenuItem(value: 'ucenik', child: Text('Učenik')),
                ],
                onChanged: (value) => setState(() => _noviTip = value!),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaTipSkole = value,
                decoration: const InputDecoration(
                  labelText: 'Tip škole (za školarce/studente)',
                  border: OutlineInputBorder(),
                ),
                controller: _tipSkoleController,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                controller: _brojTelefonaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaAdresaBelaCrkva = value,
                decoration: const InputDecoration(
                  labelText: 'Adresa polaska - Bela Crkva',
                  border: OutlineInputBorder(),
                ),
                controller: _adresaBelaCrkvaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPolazakBelaCrkva = value,
                decoration: const InputDecoration(
                  labelText: 'Vreme polaska - Bela Crkva',
                  border: OutlineInputBorder(),
                ),
                controller: _polazakBelaCrkvaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaAdresaVrsac = value,
                decoration: const InputDecoration(
                  labelText: 'Adresa polaska - Vršac',
                  border: OutlineInputBorder(),
                ),
                controller: _adresaVrsacController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPolazakVrsac = value,
                decoration: const InputDecoration(
                  labelText: 'Vreme polaska - Vršac',
                  border: OutlineInputBorder(),
                ),
                controller: _polazakVrsacController,
              ),
              const SizedBox(height: 16),

              // ✅ DODANO - Radni dani sekcija
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radni dani u toku nedelje:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Odaberi radne dane kada putnik koristi prevoz',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _buildRadniDanCheckbox(
                                    'pon', 'Ponedeljak')),
                            Expanded(
                                child: _buildRadniDanCheckbox('uto', 'Utorak')),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: _buildRadniDanCheckbox('sre', 'Sreda')),
                            Expanded(
                                child:
                                    _buildRadniDanCheckbox('cet', 'Četvrtak')),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: _buildRadniDanCheckbox('pet', 'Petak')),
                            const Expanded(child: SizedBox()), // Prazno mesto
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
            onPressed: () => _sacuvajEditPutnika(putnik),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajEditPutnika(MesecniPutnik originalPutnik) async {
    // Koristi vrednosti iz controller-a umesto iz varijabli
    final ime = _imeController.text.trim();
    final tipSkole = _tipSkoleController.text.trim();
    final brojTelefona = _brojTelefonaController.text.trim();
    final adresaBelaCrkva = _adresaBelaCrkvaController.text.trim();
    final adresaVrsac = _adresaVrsacController.text.trim();
    final polazakBelaCrkva = _polazakBelaCrkvaController.text.trim();
    final polazakVrsac = _polazakVrsacController.text.trim();

    if (ime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final editovanPutnik = MesecniPutnik(
        id: originalPutnik.id,
        putnikIme: ime,
        tip: _noviTip,
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polazakBelaCrkva: polazakBelaCrkva.isEmpty ? null : polazakBelaCrkva,
        adresaBelaCrkva: adresaBelaCrkva.isEmpty ? null : adresaBelaCrkva,
        polazakVrsac: polazakVrsac.isEmpty ? null : polazakVrsac,
        adresaVrsac: adresaVrsac.isEmpty ? null : adresaVrsac,
        tipPrikazivanja: originalPutnik.tipPrikazivanja,
        radniDani:
            _getRadniDaniString(), // ✅ DODANO - koristi odabrane radne dane
        aktivan: originalPutnik.aktivan,
        status: originalPutnik.status,
        datumPocetkaMeseca: originalPutnik.datumPocetkaMeseca,
        datumKrajaMeseca: originalPutnik.datumKrajaMeseca,
        ukupnaCenaMeseca: 0.0,
        brojPutovanja: originalPutnik.brojPutovanja,
        brojOtkazivanja: originalPutnik.brojOtkazivanja,
        poslednjiPutovanje: originalPutnik.poslednjiPutovanje,
        createdAt: originalPutnik.createdAt,
        updatedAt: DateTime.now(),
      );

      await MesecniPutnikService.azurirajMesecnogPutnika(editovanPutnik);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesečni putnik je uspešno ažuriran'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _pokaziDijalogZaDodavanje() {
    // Resetuj forme i controller-e
    setState(() {
      _novoIme = '';
      _noviTip = 'radnik';
      _novaTipSkole = '';
      _noviBrojTelefona = '';
      _novaAdresaBelaCrkva = '';
      _novaAdresaVrsac = '';
      _noviPolazakBelaCrkva = '';
      _noviPolazakVrsac = '';

      // Očisti controller-e
      _imeController.clear();
      _tipSkoleController.clear();
      _brojTelefonaController.clear();
      _adresaBelaCrkvaController.clear();
      _adresaVrsacController.clear();
      _polazakBelaCrkvaController.clear();
      _polazakVrsacController.clear();
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj novog mesečnog putnika'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => _novoIme = value,
                textCapitalization:
                    TextCapitalization.words, // 🔤 Prvo slovo veliko za ime
                decoration: const InputDecoration(
                  labelText: 'Ime putnika *',
                  border: OutlineInputBorder(),
                ),
                controller: _imeController,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _noviTip,
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'radnik', child: Text('Radnik')),
                  DropdownMenuItem(value: 'ucenik', child: Text('Učenik')),
                ],
                onChanged: (value) => setState(() => _noviTip = value!),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaTipSkole = value,
                decoration: const InputDecoration(
                  labelText: 'Tip škole (za školarce/studente)',
                  border: OutlineInputBorder(),
                ),
                controller: _tipSkoleController,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                controller: _brojTelefonaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaAdresaBelaCrkva = value,
                decoration: const InputDecoration(
                  labelText: 'Adresa polaska - Bela Crkva',
                  border: OutlineInputBorder(),
                ),
                controller: _adresaBelaCrkvaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPolazakBelaCrkva = value,
                decoration: const InputDecoration(
                  labelText: 'Vreme polaska - Bela Crkva',
                  border: OutlineInputBorder(),
                ),
                controller: _polazakBelaCrkvaController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaAdresaVrsac = value,
                decoration: const InputDecoration(
                  labelText: 'Adresa polaska - Vršac',
                  border: OutlineInputBorder(),
                ),
                controller: _adresaVrsacController,
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPolazakVrsac = value,
                decoration: const InputDecoration(
                  labelText: 'Vreme polaska - Vršac',
                  border: OutlineInputBorder(),
                ),
                controller: _polazakVrsacController,
              ),
              const SizedBox(height: 16),
              // 📅 RADNI DANI SEKCIJA
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Radni dani u nedelji',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Izaberite dane kada putnik radi:',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        _buildRadniDanCheckbox('pon', 'Ponedeljak'),
                        _buildRadniDanCheckbox('uto', 'Utorak'),
                        _buildRadniDanCheckbox('sre', 'Sreda'),
                        _buildRadniDanCheckbox('cet', 'Četvrtak'),
                        _buildRadniDanCheckbox('pet', 'Petak'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Primer: Ponedeljak, Sreda, Petak',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
            onPressed: () => _sacuvajNovogPutnika(),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajNovogPutnika() async {
    // Koristi vrednosti iz controller-a umesto iz varijabli
    final ime = _imeController.text.trim();
    final tipSkole = _tipSkoleController.text.trim();
    final brojTelefona = _brojTelefonaController.text.trim();
    final adresaBelaCrkva = _adresaBelaCrkvaController.text.trim();
    final adresaVrsac = _adresaVrsacController.text.trim();
    final polazakBelaCrkva = _polazakBelaCrkvaController.text.trim();
    final polazakVrsac = _polazakVrsacController.text.trim();

    if (ime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final noviPutnik = MesecniPutnik(
        id: '', // Biće automatski generisan u Supabase
        putnikIme: ime,
        tip: _noviTip,
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polazakBelaCrkva: polazakBelaCrkva.isEmpty ? null : polazakBelaCrkva,
        adresaBelaCrkva: adresaBelaCrkva.isEmpty ? null : adresaBelaCrkva,
        polazakVrsac: polazakVrsac.isEmpty ? null : polazakVrsac,
        adresaVrsac: adresaVrsac.isEmpty ? null : adresaVrsac,
        radniDani:
            _getRadniDaniString(), // ✅ DODANO - koristi odabrane radne dane
        datumPocetkaMeseca:
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        datumKrajaMeseca:
            DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        ukupnaCenaMeseca: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await MesecniPutnikService.dodajMesecnogPutnika(noviPutnik);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesečni putnik je uspešno dodat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _obrisiPutnika(MesecniPutnik putnik) async {
    // Pokaži potvrdu za brisanje
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdi brisanje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Da li ste sigurni da želite da obrišete putnika "${putnik.putnikIme}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Text('Važne informacije:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Putnik će biti označen kao obrisan'),
                  const Text('• Postojeća istorija putovanja se čuva'),
                  Text('• Broj putovanja: ${putnik.brojPutovanja}'),
                  const Text('• Možete kasnije da sinhronizujete statistike'),
                ],
              ),
            ),
          ],
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

    if (potvrda == true && mounted) {
      try {
        final success =
            await MesecniPutnikService.obrisiMesecnogPutnika(putnik.id);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${putnik.putnikIme} je uspešno obrisan'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'SINHRONIZUJ STATISTIKE',
                onPressed: () => _sinhronizujStatistike(putnik.id),
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri brisanju putnika'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Greška: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _sinhronizujStatistike(String putnikId) async {
    try {
      final success =
          await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
              putnikId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statistike su uspešno sinhronizovane sa istorijom'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri sinhronizaciji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pozoviBroj(String brojTelefona) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kontaktiraj putnika',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Pozovi'),
              subtitle: Text(brojTelefona),
              onTap: () async {
                Navigator.pop(context);
                await _pozovi(brojTelefona);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue),
              title: const Text('Pošalji SMS'),
              subtitle: Text(brojTelefona),
              onTap: () async {
                Navigator.pop(context);
                await _posaljiSMS(brojTelefona);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pozovi(String brojTelefona) async {
    final url = Uri.parse('tel:$brojTelefona');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nije moguće pokrenuti poziv'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri pozivanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _posaljiSMS(String brojTelefona) async {
    final url = Uri.parse('sms:$brojTelefona');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nije moguće poslati SMS'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri slanju SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📅 FORMAT DATUMA
  String _formatDatum(DateTime datum) {
    return '${datum.day}.${datum.month}.${datum.year}';
  }

  // � DOBIJANJE TRENUTNOG VOZAČA
  Future<String> _getCurrentDriver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_driver') ?? 'Nepoznat vozač';
    } catch (e) {
      return 'Nepoznat vozač';
    }
  }

  // �💰 PRIKAZ DIJALOGA ZA PLAĆANJE
  Future<void> _prikaziPlacanje(MesecniPutnik putnik) async {
    final TextEditingController iznosController = TextEditingController();
    String selectedMonth = _getCurrentMonthYear(); // Default current month

    // Ako je već plaćeno, prikaži postojeći iznos
    if (putnik.cena != null && putnik.cena! > 0) {
      iznosController.text = putnik.cena!.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payments_outlined, color: Colors.purple.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Plaćanje - ${putnik.putnikIme}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (putnik.cena != null && putnik.cena! > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trenutno plaćeno: ${putnik.cena!.toStringAsFixed(0)} din',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  if (putnik.vremePlacanja != null)
                                    Text(
                                      'Datum: ${_formatDatum(putnik.vremePlacanja!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 📅 IZBOR MESECA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          icon: Icon(Icons.calendar_month,
                              color: Colors.purple.shade600),
                          style: TextStyle(
                              color: Colors.purple.shade700, fontSize: 16),
                          menuMaxHeight: 300, // Ograniči visinu dropdown menija
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedMonth = newValue!;
                            });
                          },
                          items: _getMonthOptions()
                              .map<DropdownMenuItem<String>>((String value) {
                            // Proveri da li je mesec plaćen
                            final bool isPlacen = _isMonthPaid(value, putnik);

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: isPlacen ? Colors.green[700] : null,
                                  fontWeight: isPlacen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 💰 IZNOS
                    TextField(
                      controller: iznosController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Iznos (dinari)',
                        hintText: 'Unesite iznos plaćanja',
                        prefixIcon: Icon(Icons.attach_money,
                            color: Colors.purple.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: Colors.purple.shade600, width: 2),
                        ),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Otkaži'),
                ),
                // 📊 DUGME ZA DETALJNE STATISTIKE
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Zatvori trenutni dialog
                    _prikaziDetaljneStatistike(putnik); // Otvori statistike
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Detaljno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final iznos = double.tryParse(iznosController.text);
                    if (iznos != null && iznos > 0) {
                      Navigator.of(context).pop();
                      await _sacuvajPlacanje(putnik.id, iznos, selectedMonth);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unesite valjan iznos'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Sačuvaj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } // 💾 ČUVANJE PLAĆANJA

  // 📊 PRIKAŽI DETALJNE STATISTIKE PUTNIKA
  Future<void> _prikaziDetaljneStatistike(MesecniPutnik putnik) async {
    String selectedPeriod =
        _getCurrentMonthYearStatic(); // Default: trenutni mesec

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detaljne statistike - ${putnik.putnikIme}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📅 DROPDOWN ZA PERIOD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPeriod,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.blue.shade600),
                          items: _getMonthOptionsStatic()
                              .map<DropdownMenuItem<String>>((String value) {
                            // Proveri da li je mesec plaćen
                            final bool isPlacen =
                                _isMonthPaidStatic(value, putnik);

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: isPlacen
                                        ? Colors.green
                                        : Colors.blue.shade300,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    value,
                                    style: TextStyle(
                                      color:
                                          isPlacen ? Colors.green[700] : null,
                                      fontWeight: isPlacen
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()
                            ..addAll([
                              // 📊 CELA GODINA I UKUPNO
                              const DropdownMenuItem(
                                value: 'Cela 2025',
                                child: Row(
                                  children: [
                                    Icon(Icons.event_note,
                                        size: 16, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Cela 2025'),
                                  ],
                                ),
                              ),
                              const DropdownMenuItem(
                                value: 'Ukupno',
                                child: Row(
                                  children: [
                                    Icon(Icons.history,
                                        size: 16, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text('Ukupno'),
                                  ],
                                ),
                              ),
                            ]),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedPeriod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📊 OPTIMIZOVANO: StreamBuilder umesto FutureBuilder
                    StreamBuilder<Map<String, dynamic>>(
                      stream:
                          _streamStatistikeZaPeriod(putnik.id, selectedPeriod),
                      builder: (context, snapshot) {
                        // Loading state
                        if (snapshot.connectionState ==
                                ConnectionState.waiting ||
                            !snapshot.hasData) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        // 🔄 ERROR HANDLING: Poboljšano error handling
                        if (snapshot.hasError) {
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Greška pri učitavanju:\n${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Restart stream
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Pokušaj ponovo'),
                                  ),
                                ],
                              ),
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
                                  const Icon(Icons.warning_amber_outlined,
                                      color: Colors.orange, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Podaci trenutno nisu dostupni.\nPovežite se na internet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                  if (!_isConnected) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'OFFLINE',
                                        style: TextStyle(
                                          color: Colors.red[700],
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

                        return _buildStatistikeContent(
                            putnik, stats, selectedPeriod);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zatvori'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📊 KREIRANJE SADRŽAJA STATISTIKA NA OSNOVU PERIODA
  Widget _buildStatistikeContent(
      MesecniPutnik putnik, Map<String, dynamic> stats, String period) {
    Color periodColor = Colors.orange;
    IconData periodIcon = Icons.calendar_today;

    // Posebni slučajevi
    if (period == 'Cela 2025') {
      periodColor = Colors.blue;
      periodIcon = Icons.event_note;
    } else if (period == 'Ukupno') {
      periodColor = Colors.purple;
      periodIcon = Icons.history;
    } else {
      // Meseci - uzmi zelenu boju ako je plaćen
      final bool isPlacen = _isMonthPaidStatic(period, putnik);
      periodColor = isPlacen ? Colors.green : Colors.orange;
      periodIcon = Icons.calendar_today;
    }

    return Column(
      children: [
        // 🎯 OSNOVNE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📋 Osnovne informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow('👤 Ime:', putnik.putnikIme),
              _buildStatRow('📅 Radni dani:', putnik.radniDani),
              _buildStatRow('📊 Tip putnika:', putnik.tip),
              if (putnik.tipSkole != null)
                _buildStatRow('🎓 Tip škole:', putnik.tipSkole!),
              if (putnik.brojTelefona != null)
                _buildStatRow('📞 Telefon:', putnik.brojTelefona!),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 💰 FINANSIJSKE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💰 Finansijske informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                  '💵 Poslednje plaćanje:',
                  putnik.cena != null && putnik.cena! > 0
                      ? '${putnik.cena!.toStringAsFixed(0)} RSD'
                      : 'Nije plaćeno'),
              _buildStatRow(
                  '📅 Datum plaćanja:',
                  putnik.vremePlacanja != null
                      ? _formatDatum(putnik.vremePlacanja!)
                      : 'Nije plaćeno'),
              _buildStatRow('🚗 Vozač (naplata):', putnik.vozac ?? 'Nepoznat'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 📈 STATISTIKE PUTOVANJA - DINAMICKI PERIOD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: periodColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: periodColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(periodIcon, size: 16, color: periodColor),
                  const SizedBox(width: 4),
                  Text(
                    '📈 Statistike',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: periodColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatRow('🚗 Putovanja:', '${stats['putovanja'] ?? 0}'),
              _buildStatRow('❌ Otkazivanja:', '${stats['otkazivanja'] ?? 0}'),
              _buildStatRow('🔄 Poslednje putovanje:',
                  stats['poslednje'] ?? 'Nema podataka'),
              _buildStatRow('📊 Uspešnost:', '${stats['uspesnost'] ?? 0}%'),
              if (period == 'all_time' && stats['ukupan_prihod'] != null)
                _buildStatRow(
                    '💰 Ukupan prihod:', '${stats['ukupan_prihod']} RSD'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 🕐 SISTEMSKE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🕐 Sistemske informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow('� Kreiran:', _formatDatum(putnik.createdAt)),
              _buildStatRow('🔄 Ažuriran:', _formatDatum(putnik.updatedAt)),
              _buildStatRow(
                  '✅ Status:', putnik.aktivan ? 'Aktivan' : 'Neaktivan'),
            ],
          ),
        ),
      ],
    );
  }

  // 📊 REAL-TIME STATISTIKE STREAM - SINHRONIZOVANO SA BAZOM
  Stream<Map<String, dynamic>> _streamStatistikeZaPeriod(
      String putnikId, String period) {
    // 🔄 KORISTI NOVI CENTRALIZOVANI REAL-TIME SERVIS
    return RealTimeStatistikaService.instance
        .getPutnikStatistikeStream(putnikId)
        .asyncMap((baseStats) async {
      try {
        // Posebni slučajevi
        if (period == 'Cela 2025') {
          return await _getGodisnjeStatistike(putnikId);
        }
        if (period == 'Ukupno') {
          return await _getUkupneStatistike(putnikId);
        }

        // Parsiraj mesec u formatu "Septembar 2025"
        final parts = period.split(' ');
        if (parts.length == 2) {
          final monthName = parts[0];
          final year = int.tryParse(parts[1]);

          if (year != null) {
            final monthNumber = _getMonthNumberStatic(monthName);
            if (monthNumber > 0) {
              return await _getStatistikeZaMesec(putnikId, monthNumber, year);
            }
          }
        }

        // Fallback na trenutni mesec
        return await _getMesecneStatistike(putnikId);
      } catch (e) {
        debugPrint('❌ Greška pri dohvatanju statistika za period $period: $e');
        return {
          'putovanja': 0,
          'otkazivanja': 0,
          'poslednje': 'Greška pri učitavanju',
          'uspesnost': 0,
          'error': true,
        };
      }
    }).handleError((error) {
      debugPrint('❌ Stream error za statistike: $error');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'poslednje': 'Stream greška',
        'uspesnost': 0,
        'error': true,
      };
    });
  }

  // 📅 GODIŠNJE STATISTIKE (2025)
  Future<Map<String, dynamic>> _getGodisnjeStatistike(String putnikId) async {
    final startOfYear = DateTime(2025, 1, 1);
    final endOfYear = DateTime(2025, 12, 31);

    final response = await supabase
        .from('putovanja_istorija')
        .select('*')
        .eq('putnik_id', putnikId)
        .gte('created_at', startOfYear.toIso8601String())
        .lte('created_at', endOfYear.toIso8601String())
        .order('created_at', ascending: false);

    int putovanja = 0;
    int otkazivanja = 0;
    String? poslednje;
    double ukupanPrihod = 0;

    for (final record in response) {
      if (record['status'] == 'pokupljen') {
        putovanja++;
        ukupanPrihod += (record['iznos_placanja'] ?? 0).toDouble();
      } else if (record['status'] == 'otkazan') {
        otkazivanja++;
      }

      if (poslednje == null && record['created_at'] != null) {
        final datum = DateTime.parse(record['created_at']);
        poslednje = '${datum.day}/${datum.month}/${datum.year}';
      }
    }

    final ukupno = putovanja + otkazivanja;
    final uspesnost = ukupno > 0 ? ((putovanja / ukupno) * 100).round() : 0;

    return {
      'putovanja': putovanja,
      'otkazivanja': otkazivanja,
      'poslednje': poslednje ?? 'Nema podataka',
      'uspesnost': uspesnost,
      'ukupan_prihod': ukupanPrihod.toStringAsFixed(0),
    };
  }

  // 🏆 UKUPNE STATISTIKE (SVI PODACI)
  Future<Map<String, dynamic>> _getUkupneStatistike(String putnikId) async {
    final response = await supabase
        .from('putovanja_istorija')
        .select('*')
        .eq('putnik_id', putnikId)
        .order('created_at', ascending: false);

    int putovanja = 0;
    int otkazivanja = 0;
    String? poslednje;
    double ukupanPrihod = 0;

    for (final record in response) {
      if (record['status'] == 'pokupljen') {
        putovanja++;
        ukupanPrihod += (record['iznos_placanja'] ?? 0).toDouble();
      } else if (record['status'] == 'otkazan') {
        otkazivanja++;
      }

      if (poslednje == null && record['created_at'] != null) {
        final datum = DateTime.parse(record['created_at']);
        poslednje = '${datum.day}/${datum.month}/${datum.year}';
      }
    }

    final ukupno = putovanja + otkazivanja;
    final uspesnost = ukupno > 0 ? ((putovanja / ukupno) * 100).round() : 0;

    return {
      'putovanja': putovanja,
      'otkazivanja': otkazivanja,
      'poslednje': poslednje ?? 'Nema podataka',
      'uspesnost': uspesnost,
      'ukupan_prihod': ukupanPrihod.toStringAsFixed(0),
    };
  }

  // 📊 HELPER METODA ZA KREIRANJE REDA STATISTIKE
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajPlacanje(
      String putnikId, double iznos, String mesec) async {
    try {
      // � Učitaj trenutnog vozača
      final currentDriver = await _getCurrentDriver();

      // �📅 Konvertuj string meseca u datume
      final Map<String, dynamic> datumi = _konvertujMesecUDatume(mesec);

      final uspeh = await MesecniPutnikService.azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        currentDriver, // Koristi trenutnog vozača umesto hardkodovanog
        datumi['pocetakMeseca'] as DateTime,
        datumi['krajMeseca'] as DateTime,
      );

      if (uspeh) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Plaćanje od ${iznos.toStringAsFixed(0)} din za $mesec je sačuvano'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Greška pri čuvanju plaćanja'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    }
  }

  // � GENERIČKA FUNKCIJA ZA STATISTIKE PO MESECIMA
  Future<Map<String, dynamic>> _getStatistikeZaMesec(
      String putnikId, int mesec, int godina) async {
    try {
      final DateTime mesecStart = DateTime(godina, mesec, 1);
      final DateTime mesecEnd = DateTime(godina, mesec + 1, 0, 23, 59, 59);

      final String startStr = mesecStart.toIso8601String().split('T')[0];
      final String endStr = mesecEnd.toIso8601String().split('T')[0];

      // Dohvati sva putovanja za dati mesec
      final response = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum, status, pokupljen, created_at')
          .eq('putnik_id', putnikId)
          .gte('datum', startStr)
          .lte('datum', endStr)
          .order('created_at', ascending: false);

      final putovanja = response as List<dynamic>;

      List<String> uspesniDatumi = [];
      List<String> otkazaniDatumi = [];
      String? poslednjiDatum;

      // Procesuiraj putovanja po datumima
      for (final putovanje in putovanja) {
        final datum = putovanje['datum'] as String;
        final status = putovanje['status'] as String?;
        final pokupljen = putovanje['pokupljen'] as bool?;

        poslednjiDatum ??= datum;

        if (status == 'pokupljen' || pokupljen == true) {
          if (!uspesniDatumi.contains(datum)) {
            uspesniDatumi.add(datum);
          }
        } else if (status == 'otkazan' || status == 'nije_se_pojavio') {
          if (!otkazaniDatumi.contains(datum) &&
              !uspesniDatumi.contains(datum)) {
            otkazaniDatumi.add(datum);
          }
        }
      }

      final int brojPutovanja = uspesniDatumi.length;
      final int brojOtkazivanja = otkazaniDatumi.length;
      final int ukupno = brojPutovanja + brojOtkazivanja;
      final double uspesnost =
          ukupno > 0 ? (brojPutovanja / ukupno * 100) : 0.0;

      return {
        'putovanja': brojPutovanja,
        'otkazivanja': brojOtkazivanja,
        'uspesnost': uspesnost.toStringAsFixed(1),
        'poslednje': poslednjiDatum != null
            ? _formatDatum(DateTime.parse(poslednjiDatum))
            : null,
      };
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju statistika za $mesec/$godina: $e');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'uspesnost': '0.0',
        'poslednje': 'Greška pri učitavanju',
      };
    }
  }

  // �📅 HELPER FUNKCIJE ZA MESECE
  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return '${_getMonthName(now.month)} ${now.year}';
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

  // 💰 PROVERI DA LI JE MESEC PLAĆEN
  bool _isMonthPaid(String monthYear, MesecniPutnik putnik) {
    if (putnik.vremePlacanja == null ||
        putnik.cena == null ||
        putnik.cena! <= 0) {
      return false;
    }

    // Ako imamo precizne podatke o plaćenom mesecu, koristi ih
    if (putnik.placeniMesec != null && putnik.placenaGodina != null) {
      // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
      final parts = monthYear.split(' ');
      if (parts.length != 2) return false;

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) return false;

      final monthNumber = _getMonthNumber(monthName);
      if (monthNumber == 0) return false;

      // Proveri da li se plaćeni mesec i godina poklapaju
      return putnik.placeniMesec == monthNumber && putnik.placenaGodina == year;
    }

    // Fallback na staru logiku (za postojeće podatke)
    final parts = monthYear.split(' ');
    if (parts.length != 2) return false;

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) return false;

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) return false;

    // Proveri da li se vreme plaćanja poklapaju sa ovim mesecom
    final paymentDate = putnik.vremePlacanja!;
    return paymentDate.year == year && paymentDate.month == monthNumber;
  }

  // 📅 HELPER: DOBIJ BROJ MESECA IZ IMENA
  int _getMonthNumber(String monthName) {
    const months = [
      '', // 0 - ne postoji
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
      'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar'
    ];

    for (int i = 1; i < months.length; i++) {
      if (months[i] == monthName) {
        return i;
      }
    }
    return 0; // Ne postoji
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
      'Decembar'
    ];
    return months[month];
  }

  // 📅 STATIC HELPER FUNKCIJE - za korišćenje iz drugih widgeta
  static String _getCurrentMonthYearStatic() {
    final now = DateTime.now();
    return '${_getMonthNameStatic(now.month)} ${now.year}';
  }

  static List<String> _getMonthOptionsStatic() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthNameStatic(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  static String _getMonthNameStatic(int month) {
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
      'Decembar'
    ];
    return months[month];
  }

  // 💰 STATIC PROVERI DA LI JE MESEC PLAĆEN
  static bool _isMonthPaidStatic(String monthYear, MesecniPutnik putnik) {
    if (putnik.vremePlacanja == null ||
        putnik.cena == null ||
        putnik.cena! <= 0) {
      return false;
    }

    // Ako imamo precizne podatke o plaćenom mesecu, koristi ih
    if (putnik.placeniMesec != null && putnik.placenaGodina != null) {
      // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
      final parts = monthYear.split(' ');
      if (parts.length != 2) return false;

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) return false;

      final monthNumber = _getMonthNumberStatic(monthName);
      if (monthNumber == 0) return false;

      // Proveri da li se plaćeni mesec i godina poklapaju
      return putnik.placeniMesec == monthNumber && putnik.placenaGodina == year;
    }

    // Fallback na staru logiku (za postojeće podatke)
    final parts = monthYear.split(' ');
    if (parts.length != 2) return false;

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) return false;

    final monthNumber = _getMonthNumberStatic(monthName);
    if (monthNumber == 0) return false;

    // Proveri da li se vreme plaćanja poklapaju sa ovim mesecom
    final paymentDate = putnik.vremePlacanja!;
    return paymentDate.year == year && paymentDate.month == monthNumber;
  }

  // 📅 STATIC HELPER: DOBIJ BROJ MESECA IZ IMENA
  static int _getMonthNumberStatic(String monthName) {
    const months = [
      '', // 0 - ne postoji
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
      'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar'
    ];

    for (int i = 1; i < months.length; i++) {
      if (months[i] == monthName) {
        return i;
      }
    }
    return 0; // Ne postoji
  }

  // 📊 DOBIJ MESEČNE STATISTIKE ZA SEPTEMBAR 2025
  Future<Map<String, dynamic>> _getMesecneStatistike(String putnikId) async {
    try {
      final DateTime septembarStart = DateTime(2025, 9, 1);
      final DateTime septembarEnd = DateTime(2025, 9, 30, 23, 59, 59);

      final String startStr = septembarStart.toIso8601String().split('T')[0];
      final String endStr = septembarEnd.toIso8601String().split('T')[0];

      // Dohvati sva putovanja za septembar 2025
      final response = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum, status, pokupljen, created_at')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum', startStr)
          .lte('datum', endStr)
          .order('datum', ascending: false);

      // Broji jedinstvene datume kada je pokupljen
      final Set<String> uspesniDatumi = {};
      final Set<String> otkazaniDatumi = {};
      String? poslednjiDatum;

      for (final red in response) {
        final String datum = red['datum'] as String;
        final bool pokupljen = red['pokupljen'] as bool? ?? false;
        final String status = red['status'] as String? ?? '';

        poslednjiDatum ??= datum;

        if (pokupljen || status == 'pokupljen') {
          uspesniDatumi.add(datum);
        } else if (status == 'otkazan' || status == 'nije_se_pojavio') {
          otkazaniDatumi.add(datum);
        }
      }

      final int putovanja = uspesniDatumi.length;
      final int otkazivanja = otkazaniDatumi.length;
      final int ukupno = putovanja + otkazivanja;
      final double uspesnost = ukupno > 0 ? (putovanja / ukupno * 100) : 0.0;

      return {
        'putovanja': putovanja,
        'otkazivanja': otkazivanja,
        'uspesnost': uspesnost.toStringAsFixed(1),
        'poslednje': poslednjiDatum != null
            ? _formatDatum(DateTime.parse(poslednjiDatum))
            : null,
      };
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju mesečnih statistika: $e');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'uspesnost': '0.0',
        'poslednje': null,
      };
    }
  }

  // Helper funkcija za konvertovanje meseca u datume
  Map<String, dynamic> _konvertujMesecUDatume(String izabranMesec) {
    // Parsiraj izabrani mesec (format: "Septembar 2025")
    final parts = izabranMesec.split(' ');
    if (parts.length != 2) {
      throw Exception('Neispravno format meseca: $izabranMesec');
    }

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) {
      throw Exception('Neispravna godina: ${parts[1]}');
    }

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) {
      throw Exception('Neispravno ime meseca: $monthName');
    }

    DateTime pocetakMeseca = DateTime(year, monthNumber, 1);
    DateTime krajMeseca = DateTime(year, monthNumber + 1, 0, 23, 59, 59);

    return {
      'pocetakMeseca': pocetakMeseca,
      'krajMeseca': krajMeseca,
      'mesecBroj': monthNumber,
      'godina': year,
    };
  }

  // 📅 BUILDER ZA CHECKBOX RADNIH DANA
  Widget _buildRadniDanCheckbox(String danKod, String danNaziv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _noviRadniDani[danKod] ?? false,
              onChanged: (bool? value) {
                setState(() {
                  _noviRadniDani[danKod] = value ?? false;
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            danNaziv,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 📊 PRIKAŽI DETALJNE STATISTIKE PUTNIKA
  void _prikaziDetaljeStatistike(MesecniPutnik putnik) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MesecniPutnikDetaljiScreen(putnik: putnik),
      ),
    );
  }
}
