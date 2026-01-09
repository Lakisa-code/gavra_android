import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finansije_service.dart';

/// 💰 FINANSIJE SCREEN
/// Prikazuje prihode, troškove i neto zaradu
class FinansijeScreen extends StatefulWidget {
  const FinansijeScreen({super.key});

  @override
  State<FinansijeScreen> createState() => _FinansijeScreenState();
}

class _FinansijeScreenState extends State<FinansijeScreen> {
  FinansijskiIzvestaj? _izvestaj;
  List<Trosak> _troskovi = [];
  bool _isLoading = true;

  final _formatBroja = NumberFormat('#,###', 'sr');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final izvestaj = await FinansijeService.getIzvestaj();
    final troskovi = await FinansijeService.getTroskovi();

    setState(() {
      _izvestaj = izvestaj;
      _troskovi = troskovi;
      _isLoading = false;
    });
  }

  String _formatIznos(double iznos) {
    return '${_formatBroja.format(iznos.round())} din';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Finansije'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTroskoviDialog,
            tooltip: 'Podesi troškove',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _izvestaj == null
              ? const Center(child: Text('Greška pri učitavanju'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // NEDELJA
                        _buildPeriodCard(
                          icon: '📅',
                          naslov: 'Ova nedelja',
                          podnaslov: _izvestaj!.nedeljaPeriod,
                          prihod: _izvestaj!.prihodNedelja,
                          troskovi: _izvestaj!.troskoviNedelja,
                          neto: _izvestaj!.netoNedelja,
                          voznjiLabel: '${_izvestaj!.voznjiNedelja} vožnji',
                          color: Colors.blue,
                        ),

                        const SizedBox(height: 16),

                        // MESEC
                        _buildPeriodCard(
                          icon: '🗓️',
                          naslov: 'Ovaj mesec',
                          podnaslov: _getMesecNaziv(DateTime.now().month),
                          prihod: _izvestaj!.prihodMesec,
                          troskovi: _izvestaj!.troskoviMesec,
                          neto: _izvestaj!.netoMesec,
                          voznjiLabel: '${_izvestaj!.voznjiMesec} vožnji',
                          color: Colors.green,
                        ),

                        const SizedBox(height: 16),

                        // GODINA
                        _buildPeriodCard(
                          icon: '📊',
                          naslov: 'Ova godina',
                          podnaslov: '${DateTime.now().year}',
                          prihod: _izvestaj!.prihodGodina,
                          troskovi: _izvestaj!.troskoviGodina,
                          neto: _izvestaj!.netoGodina,
                          voznjiLabel: '${_izvestaj!.voznjiGodina} vožnji',
                          color: Colors.purple,
                        ),

                        const SizedBox(height: 16),

                        // PROŠLA GODINA
                        _buildPeriodCard(
                          icon: '📜',
                          naslov: 'Prošla godina',
                          podnaslov: '${_izvestaj!.proslaGodina}',
                          prihod: _izvestaj!.prihodProslaGodina,
                          troskovi: _izvestaj!.troskoviProslaGodina,
                          neto: _izvestaj!.netoProslaGodina,
                          voznjiLabel: '${_izvestaj!.voznjiProslaGodina} vožnji',
                          color: Colors.orange,
                        ),

                        const SizedBox(height: 24),

                        // TROŠKOVI DETALJI
                        _buildTroskoviCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPeriodCard({
    required String icon,
    required String naslov,
    required String podnaslov,
    required double prihod,
    required double troskovi,
    required double neto,
    required String voznjiLabel,
    required Color color,
  }) {
    final isPositive = neto >= 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        naslov,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        podnaslov,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    voznjiLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Prihod
            _buildRow('Prihod', prihod, Colors.green.shade700, isPlus: true),
            const SizedBox(height: 8),

            // Troškovi
            _buildRow('Troškovi', troskovi, Colors.red.shade700, isMinus: true),

            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),

            // NETO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NETO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatIznos(neto.abs()),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double iznos, Color color, {bool isPlus = false, bool isMinus = false}) {
    String prefix = '';
    if (isPlus) prefix = '+';
    if (isMinus) prefix = '-';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          '$prefix${_formatIznos(iznos)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTroskoviCard() {
    final poTipu = _izvestaj?.troskoviPoTipu ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📋 Mesečni troškovi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatIznos(_izvestaj?.ukupnoMesecniTroskovi ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista po tipu
            _buildTrosakRow('👷 Plate', poTipu['plata'] ?? 0),
            _buildTrosakRow('🏦 Kredit', poTipu['kredit'] ?? 0),
            _buildTrosakRow('⛽ Gorivo', poTipu['gorivo'] ?? 0),
            _buildTrosakRow('🔧 Amortizacija', poTipu['amortizacija'] ?? 0),
            _buildTrosakRow('📋 Ostalo', poTipu['ostalo'] ?? 0),

            const SizedBox(height: 16),

            // Dugme za podešavanje
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showTroskoviDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Podesi troškove'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrosakRow(String label, double iznos) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _formatIznos(iznos),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: iznos > 0 ? Colors.red.shade600 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _getMesecNaziv(int mesec) {
    const meseci = [
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
    return meseci[mesec];
  }

  void _showTroskoviDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚙️ Podesi troškove',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unesi mesečne iznose',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Lista troškova
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _troskovi.length,
                    itemBuilder: (context, index) {
                      final trosak = _troskovi[index];
                      return _buildTrosakEditTile(trosak);
                    },
                  ),
                ),

                // Dodaj novi
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _showDodajTrosakDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj novi trošak'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrosakEditTile(Trosak trosak) {
    return Card(
      child: ListTile(
        leading: Text(trosak.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(trosak.displayNaziv),
        subtitle: Text(trosak.tip),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatIznos(trosak.iznos),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editTrosak(trosak),
            ),
          ],
        ),
      ),
    );
  }

  void _editTrosak(Trosak trosak) {
    final controller = TextEditingController(text: trosak.iznos.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${trosak.emoji} ${trosak.displayNaziv}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mesečni iznos (din)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () async {
              final noviIznos = double.tryParse(controller.text) ?? 0;
              await FinansijeService.updateTrosak(trosak.id, noviIznos);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context); // Zatvori i bottom sheet
              _loadData();
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  void _showDodajTrosakDialog() {
    final nazivController = TextEditingController();
    final iznosController = TextEditingController();
    String selectedTip = 'ostalo';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('➕ Novi trošak'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nazivController,
                decoration: const InputDecoration(
                  labelText: 'Naziv',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedTip,
                decoration: const InputDecoration(
                  labelText: 'Tip',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'plata', child: Text('👷 Plata')),
                  DropdownMenuItem(value: 'kredit', child: Text('🏦 Kredit')),
                  DropdownMenuItem(value: 'gorivo', child: Text('⛽ Gorivo')),
                  DropdownMenuItem(value: 'amortizacija', child: Text('🔧 Amortizacija')),
                  DropdownMenuItem(value: 'ostalo', child: Text('📋 Ostalo')),
                ],
                onChanged: (value) => setStateDialog(() => selectedTip = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iznosController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mesečni iznos (din)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            TextButton(
              onPressed: () async {
                if (nazivController.text.isEmpty) return;
                final iznos = double.tryParse(iznosController.text) ?? 0;
                await FinansijeService.addTrosak(nazivController.text, selectedTip, iznos);
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context); // Zatvori i bottom sheet
                _loadData();
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }
}
