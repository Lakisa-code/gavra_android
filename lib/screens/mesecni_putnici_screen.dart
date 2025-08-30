import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';

class MesecniPutniciScreen extends StatefulWidget {
  const MesecniPutniciScreen({Key? key}) : super(key: key);

  @override
  State<MesecniPutniciScreen> createState() => _MesecniPutniciScreenState();
}

class _MesecniPutniciScreenState extends State<MesecniPutniciScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'svi'; // 'svi', 'radnik', 'ucenik'

  // Promenljive za dodavanje/editovanje putnika
  String _novoIme = '';
  String _noviTip = 'radnik';
  String _novaTipSkole = '';
  String _noviBrojTelefona = '';
  String _novaAdresaBelaCrkva = '';
  String _novaAdresaVrsac = '';
  String _noviPolazakBelaCrkva = '07:00';
  String _noviPolazakVrsac = '16:00';
  double _novaCenaMeseca = 0.0;

  // TextEditingController-i za edit dialog
  late TextEditingController _imeController;
  late TextEditingController _tipSkoleController;
  late TextEditingController _brojTelefonaController;
  late TextEditingController _adresaBelaCrkvaController;
  late TextEditingController _adresaVrsacController;
  late TextEditingController _polazakBelaCrkvaController;
  late TextEditingController _polazakVrsacController;
  late TextEditingController _cenaMesecaController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _imeController = TextEditingController();
    _tipSkoleController = TextEditingController();
    _brojTelefonaController = TextEditingController();
    _adresaBelaCrkvaController = TextEditingController();
    _adresaVrsacController = TextEditingController();
    _polazakBelaCrkvaController = TextEditingController();
    _polazakVrsacController = TextEditingController();
    _cenaMesecaController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _imeController.dispose();
    _tipSkoleController.dispose();
    _brojTelefonaController.dispose();
    _adresaBelaCrkvaController.dispose();
    _adresaVrsacController.dispose();
    _polazakBelaCrkvaController.dispose();
    _polazakVrsacController.dispose();
    _cenaMesecaController.dispose();
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
                  setState(() {
                    _selectedFilter =
                        _selectedFilter == 'radnik' ? 'svi' : 'radnik';
                  });
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
                    final brojRadnika =
                        snapshot.data!.where((p) => p.tip == 'radnik').length;
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
                  setState(() {
                    _selectedFilter =
                        _selectedFilter == 'ucenik' ? 'svi' : 'ucenik';
                  });
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
                    final brojUcenika =
                        snapshot.data!.where((p) => p.tip == 'ucenik').length;
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
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          const SizedBox(height: 16),

          // 📋 LISTA PUTNIKA
          Expanded(
            child: StreamBuilder<List<MesecniPutnik>>(
              stream: MesecniPutnikService.streamMesecniPutnici(),
              builder: (context, snapshot) {
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
                        Icon(Icons.error, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Greška pri učitavanju putnika',
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
                      ],
                    ),
                  );
                }

                final putnici = snapshot.data ?? [];

                // Filtriranje po search terme i tipu putnika
                final filteredPutnici = putnici.where((putnik) {
                  // Filtriraj po search termu
                  bool matchesSearch = true;
                  if (_searchController.text.isNotEmpty) {
                    final searchTerm = _searchController.text.toLowerCase();
                    matchesSearch =
                        putnik.putnikIme.toLowerCase().contains(searchTerm) ||
                            (putnik.brojTelefona
                                    ?.toLowerCase()
                                    .contains(searchTerm) ??
                                false) ||
                            putnik.tip.toLowerCase().contains(searchTerm);
                  }

                  // Filtriraj po tipu putnika
                  bool matchesType = true;
                  if (_selectedFilter != 'svi') {
                    matchesType = putnik.tip == _selectedFilter;
                  }

                  return matchesSearch && matchesType;
                }).toList();

                // Sortiranje po abecednom redu (ime putnika)
                filteredPutnici.sort((a, b) => a.putnikIme
                    .toLowerCase()
                    .compareTo(b.putnikIme.toLowerCase()));

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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pokaziDetalje(putnik),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sa rednim brojem, imenom i statusom
              Row(
                children: [
                  // Redni broj
                  Text(
                    '$redniBroj.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                  _buildStatusChip(putnik),
                ],
              ),

              const SizedBox(height: 8),

              // Osnovne informacije
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    putnik.tip.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (putnik.tipSkole != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.school, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      putnik.tipSkole!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),

              if (putnik.brojTelefona != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      putnik.brojTelefona!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Putovanja i statistike
              Row(
                children: [
                  _buildStatistikaPill(
                    '${putnik.brojPutovanja} putovanja',
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  if (putnik.brojOtkazivanja > 0)
                    _buildStatistikaPill(
                      '${putnik.brojOtkazivanja} otkazivanja',
                      Colors.orange,
                    ),
                ],
              ),

              // Radni dani
              if (putnik.radniDani.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Radni dani: ${putnik.radniDani}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],

              // Action buttons
              const SizedBox(height: 12),

              // Kompaktni grid sa svim akcijama
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Osnovne akcije
                  if (putnik.brojTelefona != null)
                    _buildCompactButton(
                      onPressed: () => _pozoviBroj(putnik.brojTelefona!),
                      icon: Icons.phone,
                      label: 'Pozovi',
                      color: Colors.green,
                    ),

                  _buildCompactButton(
                    onPressed: () => _toggleAktivnost(putnik),
                    icon: putnik.aktivan ? Icons.pause : Icons.play_arrow,
                    label: putnik.aktivan ? 'Deaktiviraj' : 'Aktiviraj',
                    color: putnik.aktivan ? Colors.orange : Colors.green,
                  ),

                  _buildCompactButton(
                    onPressed: () => _editPutnik(putnik),
                    icon: Icons.edit,
                    label: 'Uredi',
                    color: Colors.blue,
                  ),

                  _buildCompactButton(
                    onPressed: () => _obrisiPutnika(putnik),
                    icon: Icons.delete,
                    label: 'Obriši',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(MesecniPutnik putnik) {
    Color color;
    String text;

    if (!putnik.aktivan) {
      color = Colors.grey;
      text = 'NEAKTIVAN';
    } else {
      color = Colors.green;
      text = 'AKTIVAN';
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatistikaPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 90, // Fiksna širina za ujednačenost
      height: 32, // Kompaktna visina
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _pokaziDetalje(MesecniPutnik putnik) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(putnik.putnikIme),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Tip', putnik.tip),
              if (putnik.tipSkole != null)
                _buildDetailRow('Tip škole', putnik.tipSkole!),
              if (putnik.brojTelefona != null)
                _buildDetailRow('Telefon', putnik.brojTelefona!),
              _buildDetailRow(
                  'Status', putnik.aktivan ? 'Aktivan' : 'Neaktivan'),
              _buildDetailRow('Odsutnost', putnik.status),
              _buildDetailRow('Radni dani', putnik.radniDani),
              _buildDetailRow(
                  'Broj putovanja', putnik.brojPutovanja.toString()),
              _buildDetailRow(
                  'Broj otkazivanja', putnik.brojOtkazivanja.toString()),
              _buildDetailRow('Cena meseca',
                  '${putnik.ukupnaCenaMeseca.toStringAsFixed(0)} RSD'),
              _buildDetailRow('Period',
                  '${putnik.datumPocetkaMeseca.day}/${putnik.datumPocetkaMeseca.month} - ${putnik.datumKrajaMeseca.day}/${putnik.datumKrajaMeseca.month}'),
              if (putnik.polazakBelaCrkva != null)
                _buildDetailRow('Polazak BC', putnik.polazakBelaCrkva!),
              if (putnik.adresaBelaCrkva != null)
                _buildDetailRow('Adresa BC', putnik.adresaBelaCrkva!),
              if (putnik.polazakVrsac != null)
                _buildDetailRow('Polazak Vršac', putnik.polazakVrsac!),
              if (putnik.adresaVrsac != null)
                _buildDetailRow('Adresa Vršac', putnik.adresaVrsac!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editPutnik(putnik);
            },
            child: const Text('Uredi'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
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
      _noviPolazakBelaCrkva = putnik.polazakBelaCrkva ?? '07:00';
      _noviPolazakVrsac = putnik.polazakVrsac ?? '16:00';
      _novaCenaMeseca = putnik.ukupnaCenaMeseca;

      // Postavi vrednosti u controller-e
      _imeController.text = _novoIme;
      _tipSkoleController.text = _novaTipSkole;
      _brojTelefonaController.text = _noviBrojTelefona;
      _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
      _adresaVrsacController.text = _novaAdresaVrsac;
      _polazakBelaCrkvaController.text = _noviPolazakBelaCrkva;
      _polazakVrsacController.text = _noviPolazakVrsac;
      _cenaMesecaController.text = _novaCenaMeseca.toString();
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
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) =>
                    _novaCenaMeseca = double.tryParse(value) ?? 0.0,
                decoration: const InputDecoration(
                  labelText: 'Cena mesečne karte',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: _cenaMesecaController,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Aktivan: '),
                  Switch(
                    value: putnik.aktivan,
                    onChanged: (value) =>
                        _azurirajStatusAktivnosti(putnik, value),
                  ),
                ],
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
    final cenaMeseca = double.tryParse(_cenaMesecaController.text) ?? 0.0;

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
        radniDani: originalPutnik.radniDani,
        aktivan: originalPutnik.aktivan,
        status: originalPutnik.status,
        datumPocetkaMeseca: originalPutnik.datumPocetkaMeseca,
        datumKrajaMeseca: originalPutnik.datumKrajaMeseca,
        ukupnaCenaMeseca: cenaMeseca,
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

  Future<void> _azurirajStatusAktivnosti(
      MesecniPutnik putnik, bool noviStatus) async {
    try {
      final azuriranPutnik = MesecniPutnik(
        id: putnik.id,
        putnikIme: putnik.putnikIme,
        tip: putnik.tip,
        tipSkole: putnik.tipSkole,
        brojTelefona: putnik.brojTelefona,
        polazakBelaCrkva: putnik.polazakBelaCrkva,
        adresaBelaCrkva: putnik.adresaBelaCrkva,
        polazakVrsac: putnik.polazakVrsac,
        adresaVrsac: putnik.adresaVrsac,
        tipPrikazivanja: putnik.tipPrikazivanja,
        radniDani: putnik.radniDani,
        aktivan: noviStatus,
        status: putnik.status,
        datumPocetkaMeseca: putnik.datumPocetkaMeseca,
        datumKrajaMeseca: putnik.datumKrajaMeseca,
        ukupnaCenaMeseca: putnik.ukupnaCenaMeseca,
        brojPutovanja: putnik.brojPutovanja,
        brojOtkazivanja: putnik.brojOtkazivanja,
        poslednjiPutovanje: putnik.poslednjiPutovanje,
        createdAt: putnik.createdAt,
        updatedAt: DateTime.now(),
      );

      await MesecniPutnikService.azurirajMesecnogPutnika(azuriranPutnik);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status ažuriran na: ${noviStatus ? "Aktivan" : "Neaktivan"}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri ažuriranju statusa: $e')),
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
      _noviPolazakBelaCrkva = '07:00';
      _noviPolazakVrsac = '16:00';
      _novaCenaMeseca = 0.0;

      // Očisti controller-e
      _imeController.clear();
      _tipSkoleController.clear();
      _brojTelefonaController.clear();
      _adresaBelaCrkvaController.clear();
      _adresaVrsacController.clear();
      _polazakBelaCrkvaController.text = '07:00';
      _polazakVrsacController.text = '16:00';
      _cenaMesecaController.text = '0.0';
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
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) =>
                    _novaCenaMeseca = double.tryParse(value) ?? 0.0,
                decoration: const InputDecoration(
                  labelText: 'Cena mesečne karte',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: _cenaMesecaController,
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
    final polazakBelaCrkva = _polazakBelaCrkvaController.text.trim().isEmpty
        ? '07:00'
        : _polazakBelaCrkvaController.text.trim();
    final polazakVrsac = _polazakVrsacController.text.trim().isEmpty
        ? '16:00'
        : _polazakVrsacController.text.trim();
    final cenaMeseca = double.tryParse(_cenaMesecaController.text) ?? 0.0;

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
        polazakBelaCrkva: polazakBelaCrkva,
        adresaBelaCrkva: adresaBelaCrkva.isEmpty ? null : adresaBelaCrkva,
        polazakVrsac: polazakVrsac,
        adresaVrsac: adresaVrsac.isEmpty ? null : adresaVrsac,
        datumPocetkaMeseca:
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        datumKrajaMeseca:
            DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        ukupnaCenaMeseca: cenaMeseca,
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
}

