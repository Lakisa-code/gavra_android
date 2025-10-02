import 'package:flutter/material.dart';
import '../models/putovanja_istorija.dart';
import '../services/putovanja_istorija_service.dart';
import '../widgets/custom_back_button.dart';
import '../theme.dart'; // Za theme boje

class PutovanjaIstorijaScreen extends StatefulWidget {
  const PutovanjaIstorijaScreen({Key? key}) : super(key: key);

  @override
  State<PutovanjaIstorijaScreen> createState() =>
      _PutovanjaIstorijaScreenState();
}

class _PutovanjaIstorijaScreenState extends State<PutovanjaIstorijaScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'svi'; // 'svi', 'mesecni', 'dnevni'

  // Varijable za dodavanje novog putovanja
  String _noviPutnikIme = '';
  String _noviPutnikTelefon = '';
  double _novaCena = 0.0;
  String _noviTipPutnika = 'regularni';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const GradientBackButton(),
        automaticallyImplyLeading: false,
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
        ),
        title: const Text('Istorija Putovanja',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(),
            tooltip: 'Izaberi datum',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter tip putnika',
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'svi',
                child: Text('Svi putnici'),
              ),
              const PopupMenuItem(
                value: 'mesecni',
                child: Text('Mesečni putnici'),
              ),
              const PopupMenuItem(
                value: 'dnevni',
                child: Text('Dnevni putnici'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 📅 DATE & FILTER INFO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.indigo.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datum: ${_formatDate(_selectedDate)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filter: ${_getFilterText(_selectedFilter)}',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),

          // 📋 LISTA PUTOVANJA
          Expanded(
            child: StreamBuilder<List<PutovanjaIstorija>>(
              stream: PutovanjaIstorijaService.streamPutovanjaZaDatum(
                  _selectedDate),
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
                        Icon(Icons.error,
                            size: 64,
                            color: Theme.of(context).colorScheme.dangerPrimary),
                        const SizedBox(height: 16),
                        Text(
                          'Greška pri učitavanju putovanja',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.dangerPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.dangerPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final svaPutovanja = snapshot.data ?? [];

                // Filtriranje po tipu putnika
                final putovanja = svaPutovanja.where((putovanje) {
                  if (_selectedFilter == 'svi') return true;
                  return putovanje.tipPutnika == _selectedFilter;
                }).toList();

                if (putovanja.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_bus_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nema putovanja za izabrani datum',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Izaberite drugi datum ili dodajte nova putovanja',
                          style: TextStyle(color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Grupiranje po vremenu polaska
                final Map<String, List<PutovanjaIstorija>> grupisanaPutovanja =
                    {};
                for (final putovanje in putovanja) {
                  final vreme = putovanje.vremePolaska;
                  if (!grupisanaPutovanja.containsKey(vreme)) {
                    grupisanaPutovanja[vreme] = [];
                  }
                  grupisanaPutovanja[vreme]!.add(putovanje);
                }

                final sortedKeys = grupisanaPutovanja.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final vreme = sortedKeys[index];
                    final putovanjaGrupe = grupisanaPutovanja[vreme]!;

                    return _buildVremeGroup(vreme, putovanjaGrupe);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _dodajNovoPutovanje(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        tooltip: 'Dodaj novo putovanje',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVremeGroup(String vreme, List<PutovanjaIstorija> putovanja) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sa vremenom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  vreme,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${putovanja.length} putnik${putovanja.length == 1 ? '' : 'a'}',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista putnika
          ...putovanja.map((putovanje) => _buildPutovanjeCard(putovanje)),
        ],
      ),
    );
  }

  Widget _buildPutovanjeCard(PutovanjaIstorija putovanje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sa imenom i tipom
          Row(
            children: [
              Expanded(
                child: Text(
                  putovanje.putnikIme,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTipChip(putovanje.tipPutnika),
            ],
          ),

          const SizedBox(height: 8),

          // Adresa polaska
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  putovanje.adresaPolaska,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),

          // Telefon ako postoji
          if (putovanje.brojTelefona != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  putovanje.brojTelefona!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Status putovanja
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BC → Vršac',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(putovanje.status),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vršac → BC',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(putovanje.status),
                  ],
                ),
              ),
            ],
          ),

          // Cena
          if (putovanje.cena > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (putovanje.cena > 0) ...[
                  Icon(Icons.monetization_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.successPrimary),
                  const SizedBox(width: 4),
                  Text(
                    '${putovanje.cena.toStringAsFixed(0)} RSD',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.successPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Action buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _editPutovanje(putovanje),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Uredi'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _updateStatus(putovanje),
                icon: const Icon(Icons.update, size: 16),
                label: const Text('Status'),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipChip(String tip) {
    final isMesecni = tip == 'mesecni';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMesecni
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMesecni
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.3),
        ),
      ),
      child: Text(
        isMesecni ? 'MESEČNI' : 'DNEVNI',
        style: TextStyle(
          color: isMesecni
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Theme.of(context).colorScheme.warningPrimary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pokupljen':
        color = Colors.green;
        text = 'POKUPLJEN';
        break;
      case 'otkazao_poziv':
        color = Colors.orange;
        text = 'OTKAZAO';
        break;
      case 'nije_se_pojavio':
      default:
        color = Colors.red;
        text = 'NIJE SE POJAVIO';
        break;
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const meseci = [
      '',
      'januar',
      'februar',
      'mart',
      'april',
      'maj',
      'jun',
      'jul',
      'avgust',
      'septembar',
      'oktobar',
      'novembar',
      'decembar'
    ];

    const dani = [
      '',
      'ponedeljak',
      'utorak',
      'sreda',
      'četvrtak',
      'petak',
      'subota',
      'nedelja'
    ];

    return '${dani[date.weekday]}, ${date.day}. ${meseci[date.month]} ${date.year}.';
  }

  String _getFilterText(String filter) {
    switch (filter) {
      case 'mesecni':
        return 'Mesečni putnici';
      case 'dnevni':
        return 'Dnevni putnici';
      case 'svi':
      default:
        return 'Svi putnici';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Izaberite datum',
      cancelText: 'Odustani',
      confirmText: 'Potvrdi',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _dodajNovoPutovanje() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj novo putovanje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ime putnika',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _noviPutnikIme = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => _noviPutnikTelefon = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Cena (RSD)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _novaCena = double.tryParse(value) ?? 0.0,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                value: _noviTipPutnika,
                items: ['regularni', 'mesecni'].map((tip) {
                  return DropdownMenuItem(value: tip, child: Text(tip));
                }).toList(),
                onChanged: (value) => _noviTipPutnika = value ?? 'regularni',
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
            onPressed: _sacuvajNovoPutovanje,
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajNovoPutovanje() async {
    if (_noviPutnikIme.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final novoPutovanje = PutovanjaIstorija(
        id: '', // Biće automatski generisan u Supabase
        putnikIme: _noviPutnikIme.trim(),
        brojTelefona: _noviPutnikTelefon.trim().isEmpty
            ? null
            : _noviPutnikTelefon.trim(),
        adresaPolaska: 'Bela Crkva', // Default vrednost
        vremePolaska: '07:00', // Default vrednost
        tipPutnika: _noviTipPutnika,
        statusBelaCrkvaVrsac: 'nije_se_pojavio',
        statusVrsacBelaCrkva: 'nije_se_pojavio',
        cena: _novaCena,
        datum: _selectedDate,
        vremeAkcije: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await PutovanjaIstorijaService.dodajPutovanje(novoPutovanje);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Putovanje je uspešno dodato'),
            backgroundColor: Colors.green,
          ),
        );

        // Resetuj forme
        setState(() {
          _noviPutnikIme = '';
          _noviPutnikTelefon = '';
          _novaCena = 0.0;
          _noviTipPutnika = 'regularni';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _editPutovanje(PutovanjaIstorija putovanje) {
    // Postavi vrednosti za edit
    setState(() {
      _noviPutnikIme = putovanje.putnikIme;
      _noviPutnikTelefon = putovanje.brojTelefona ?? '';
      _novaCena = putovanje.cena;
      _noviTipPutnika = putovanje.tipPutnika;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uredi putovanje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => _noviPutnikIme = value,
                decoration: const InputDecoration(
                  labelText: 'Ime putnika',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _noviPutnikIme),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _noviPutnikTelefon = value,
                decoration: const InputDecoration(
                  labelText: 'Broj telefona',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _noviPutnikTelefon),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => _novaCena = double.tryParse(value) ?? 0.0,
                decoration: const InputDecoration(
                  labelText: 'Cena',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _novaCena.toString()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _noviTipPutnika,
                decoration: const InputDecoration(
                  labelText: 'Tip putnika',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'regularni', child: Text('Regularni')),
                  DropdownMenuItem(value: 'povoljni', child: Text('Povoljni')),
                  DropdownMenuItem(
                      value: 'besplatni', child: Text('Besplatni')),
                ],
                onChanged: (value) => setState(() => _noviTipPutnika = value!),
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
            onPressed: () => _sacuvajEditPutovanje(putovanje),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajEditPutovanje(
      PutovanjaIstorija originalPutovanje) async {
    if (_noviPutnikIme.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ime putnika je obavezno')),
      );
      return;
    }

    try {
      final editovanoPutovanje = PutovanjaIstorija(
        id: originalPutovanje.id,
        mesecniPutnikId: originalPutovanje.mesecniPutnikId,
        putnikIme: _noviPutnikIme.trim(),
        brojTelefona: _noviPutnikTelefon.trim().isEmpty
            ? null
            : _noviPutnikTelefon.trim(),
        adresaPolaska: originalPutovanje.adresaPolaska,
        vremePolaska: originalPutovanje.vremePolaska,
        tipPutnika: _noviTipPutnika,
        statusBelaCrkvaVrsac: originalPutovanje.statusBelaCrkvaVrsac,
        statusVrsacBelaCrkva: originalPutovanje.statusVrsacBelaCrkva,
        cena: _novaCena,
        datum: originalPutovanje.datum,
        vremeAkcije: originalPutovanje.vremeAkcije,
        createdAt: originalPutovanje.createdAt,
        updatedAt: DateTime.now(),
      );

      await PutovanjaIstorijaService.azurirajPutovanje(editovanoPutovanje);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Putovanje je uspešno ažurirano'),
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

  void _updateStatus(PutovanjaIstorija putovanje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ažuriranje statusa za ${putovanje.putnikIme}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bela Crkva → Vršac:'),
            DropdownButton<String>(
              value: putovanje.statusBelaCrkvaVrsac,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: 'nije_se_pojavio', child: Text('Nije se pojavio')),
                DropdownMenuItem(value: 'prisutan', child: Text('Prisutan')),
                DropdownMenuItem(value: 'otsutan', child: Text('Odsutan')),
              ],
              onChanged: (value) =>
                  _updateStatusBelaCrkvaVrsac(putovanje, value!),
            ),
            const SizedBox(height: 16),
            const Text('Vršac → Bela Crkva:'),
            DropdownButton<String>(
              value: putovanje.statusVrsacBelaCrkva,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: 'nije_se_pojavio', child: Text('Nije se pojavio')),
                DropdownMenuItem(value: 'prisutan', child: Text('Prisutan')),
                DropdownMenuItem(value: 'otsutan', child: Text('Odsutan')),
              ],
              onChanged: (value) =>
                  _updateStatusVrsacBelaCrkva(putovanje, value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatusBelaCrkvaVrsac(
      PutovanjaIstorija putovanje, String noviStatus) async {
    final azuriranoPutovanje = PutovanjaIstorija(
      id: putovanje.id,
      mesecniPutnikId: putovanje.mesecniPutnikId,
      putnikIme: putovanje.putnikIme,
      brojTelefona: putovanje.brojTelefona,
      adresaPolaska: putovanje.adresaPolaska,
      vremePolaska: putovanje.vremePolaska,
      tipPutnika: putovanje.tipPutnika,
      statusBelaCrkvaVrsac: noviStatus,
      statusVrsacBelaCrkva: putovanje.statusVrsacBelaCrkva,
      cena: putovanje.cena,
      datum: putovanje.datum,
      vremeAkcije: putovanje.vremeAkcije,
      createdAt: putovanje.createdAt,
      updatedAt: DateTime.now(),
    );

    await PutovanjaIstorijaService.azurirajPutovanje(azuriranoPutovanje);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status ažuriran na: $noviStatus')),
      );
    }
  }

  Future<void> _updateStatusVrsacBelaCrkva(
      PutovanjaIstorija putovanje, String noviStatus) async {
    final azuriranoPutovanje = PutovanjaIstorija(
      id: putovanje.id,
      mesecniPutnikId: putovanje.mesecniPutnikId,
      putnikIme: putovanje.putnikIme,
      brojTelefona: putovanje.brojTelefona,
      adresaPolaska: putovanje.adresaPolaska,
      vremePolaska: putovanje.vremePolaska,
      tipPutnika: putovanje.tipPutnika,
      statusBelaCrkvaVrsac: putovanje.statusBelaCrkvaVrsac,
      statusVrsacBelaCrkva: noviStatus,
      cena: putovanje.cena,
      datum: putovanje.datum,
      vremeAkcije: putovanje.vremeAkcije,
      createdAt: putovanje.createdAt,
      updatedAt: DateTime.now(),
    );

    await PutovanjaIstorijaService.azurirajPutovanje(azuriranoPutovanje);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status ažuriran na: $noviStatus')),
      );
    }
  }
}
