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
  List<LicnaStavka> _licneStavke = [];

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
    final licne = await FinansijeService.getLicneStavke();

    if (mounted) {
      setState(() {
        _izvestaj = izvestaj;
        _licneStavke = licne;
        _isLoading = false;
      });
    }
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTroskoviDialog,
            tooltip: 'Podesi troškove',
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

                        const SizedBox(height: 24),

                        // TROŠKOVI DETALJI
                        _buildTroskoviCard(),

                        const SizedBox(height: 24),

                        // ---------------- DUGOVI I UŠTEĐEVINA ----------------
                        const Text(
                          'LIČNE FINANSIJE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildLicneFinansijeCard(),

                        const SizedBox(height: 24),
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

  Widget _buildRow(String label, double iznos, Color color, {bool isMinus = false, bool isPlus = false}) {
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
            _buildTrosakRow('📝 Registracija', poTipu['registracija'] ?? 0),
            _buildTrosakRow('🚗 YU auto', poTipu['yu_auto'] ?? 0),
            _buildTrosakRow('🛠️ Majstori', poTipu['majstori'] ?? 0),
            _buildTrosakRow('🏛️ Porez', poTipu['porez'] ?? 0),
            _buildTrosakRow('👶 Alimentacija', poTipu['alimentacija'] ?? 0),
            _buildTrosakRow('🧾 Računi', poTipu['racuni'] ?? 0),
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
    // Kontroleri za svaku kategoriju - NE POPUNJAVAJ POSTOJEĆE (SABIRANJE)
    final plateController = TextEditingController();
    final kreditController = TextEditingController();
    final gorivoController = TextEditingController();
    final amortizacijaController = TextEditingController();
    final registracijaController = TextEditingController();
    final yuAutoController = TextEditingController();
    final majstoriController = TextEditingController();
    final ostaloController = TextEditingController();
    final porezController = TextEditingController();
    final alimentacijaController = TextEditingController();
    final racuniController = TextEditingController();

    // Mapping za trenutne vrednosti
    final poTipu = _izvestaj?.troskoviPoTipu ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '⚙️ Dodaj troškove',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unesi iznos koji želiš da DODAŠ na trenutni trošak.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Plate
                  _buildTrosakInputRow('💰', 'Plate', plateController, currentTotal: poTipu['plata']),
                  const SizedBox(height: 12),

                  // Kredit
                  _buildTrosakInputRow('🏦', 'Kredit', kreditController, currentTotal: poTipu['kredit']),
                  const SizedBox(height: 12),

                  // Gorivo
                  _buildTrosakInputRow('⛽', 'Gorivo', gorivoController, currentTotal: poTipu['gorivo']),
                  const SizedBox(height: 12),

                  // Amortizacija
                  _buildTrosakInputRow('🔧', 'Amortizacija', amortizacijaController,
                      currentTotal: poTipu['amortizacija']),
                  const SizedBox(height: 12),

                  // Registracija
                  _buildTrosakInputRow('📝', 'Registracija', registracijaController,
                      currentTotal: poTipu['registracija']),
                  const SizedBox(height: 12),

                  // YU auto
                  _buildTrosakInputRow('🚗', 'YU auto', yuAutoController, currentTotal: poTipu['yu_auto']),
                  const SizedBox(height: 12),

                  // Majstori
                  _buildTrosakInputRow('🛠️', 'Majstori', majstoriController, currentTotal: poTipu['majstori']),
                  const SizedBox(height: 12),

                  // Porez
                  _buildTrosakInputRow('🏛️', 'Porez', porezController, currentTotal: poTipu['porez']),
                  const SizedBox(height: 12),

                  // Alimentacija
                  _buildTrosakInputRow('👶', 'Alimentacija', alimentacijaController,
                      currentTotal: poTipu['alimentacija']),
                  const SizedBox(height: 12),

                  // Računi
                  _buildTrosakInputRow('🧾', 'Računi', racuniController, currentTotal: poTipu['racuni']),
                  const SizedBox(height: 12),

                  // Ostalo
                  _buildTrosakInputRow('📋', 'Ostalo', ostaloController, currentTotal: poTipu['ostalo']),
                  const SizedBox(height: 24),

                  // Sačuvaj dugme
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _saveTroskovi(
                          plate: double.tryParse(plateController.text) ?? 0,
                          kredit: double.tryParse(kreditController.text) ?? 0,
                          gorivo: double.tryParse(gorivoController.text) ?? 0,
                          amortizacija: double.tryParse(amortizacijaController.text) ?? 0,
                          registracija: double.tryParse(registracijaController.text) ?? 0,
                          yuAuto: double.tryParse(yuAutoController.text) ?? 0,
                          majstori: double.tryParse(majstoriController.text) ?? 0,
                          ostalo: double.tryParse(ostaloController.text) ?? 0,
                          porez: double.tryParse(porezController.text) ?? 0,
                          alimentacija: double.tryParse(alimentacijaController.text) ?? 0,
                          racuni: double.tryParse(racuniController.text) ?? 0,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadData();
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Dodaj troškove'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green, // Visual cue for Adding
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrosakInputRow(String emoji, String label, TextEditingController controller, {double? currentTotal}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  if (currentTotal != null && currentTotal > 0)
                    Text('Trenutno: ${_formatBroja.format(currentTotal)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'Dodaj...',
                  suffixText: 'din',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveTroskovi({
    required double plate,
    required double kredit,
    required double gorivo,
    required double amortizacija,
    required double registracija,
    required double yuAuto,
    required double majstori,
    required double ostalo,
    required double porez,
    required double alimentacija,
    required double racuni,
  }) async {
    // Dodaj NOVI trošak samo ako je iznos > 0
    await _addTrosakIfPositive('Plate', 'plata', plate);
    await _addTrosakIfPositive('Kredit', 'kredit', kredit);
    await _addTrosakIfPositive('Gorivo', 'gorivo', gorivo);
    await _addTrosakIfPositive('Amortizacija', 'amortizacija', amortizacija);
    await _addTrosakIfPositive('Registracija', 'registracija', registracija);
    await _addTrosakIfPositive('YU auto', 'yu_auto', yuAuto);
    await _addTrosakIfPositive('Majstori', 'majstori', majstori);
    await _addTrosakIfPositive('Porez', 'porez', porez);
    await _addTrosakIfPositive('Alimentacija', 'alimentacija', alimentacija);
    await _addTrosakIfPositive('Računi', 'racuni', racuni);
    await _addTrosakIfPositive('Ostalo', 'ostalo', ostalo);
  }

  Future<void> _addTrosakIfPositive(String naziv, String tip, double iznos) async {
    if (iznos != 0) {
      // Dozvoljava i negativne za ispravke
      await FinansijeService.addTrosak(naziv, tip, iznos);
    }
  }

  Widget _buildLicneFinansijeCard() {
    double ukupnoDug = 0;
    double ukupnoStednja = 0;

    for (var s in _licneStavke) {
      if (s.tip == 'dug') ukupnoDug += s.iznos;
      if (s.tip == 'stednja') ukupnoStednja += s.iznos;
    }

    final ukupnoStanje = ukupnoStednja - ukupnoDug;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lični Bilans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: _showAddLicnoDialog,
                ),
              ],
            ),
            const Divider(),
            _buildRow('Ušteđevina', ukupnoStednja, Colors.green.shade700, isPlus: true),
            const SizedBox(height: 8),
            _buildRow('Dugovi', ukupnoDug, Colors.red.shade700, isMinus: true),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Slobodna sredstva', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _formatBroja.format(ukupnoStanje),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ukupnoStanje >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (_licneStavke.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Detalji:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              ..._licneStavke.map((e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    leading: Text(e.tip == 'dug' ? '🔴' : '🟢'),
                    title: Text(e.naziv),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatBroja.format(e.iznos),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 16),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => _showAddLicnoDialog(stavka: e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey, size: 16),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Obriši stavku?'),
                                content: Text('Da li želiš da obrišeš "${e.naziv}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ne')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Da', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FinansijeService.deleteLicnaStavka(e.id);
                              _loadData();
                            }
                          },
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddLicnoDialog({LicnaStavka? stavka}) {
    String tip = stavka?.tip ?? 'stednja';
    String valuta = 'RSD';
    final nazivController = TextEditingController(text: stavka?.naziv ?? '');
    final iznosController =
        TextEditingController(text: stavka?.iznos != null ? (stavka?.iznos ?? 0).toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(stavka == null ? 'Nova lična stavka' : 'Izmeni stavku'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<String>(
                groupValue: tip,
                onChanged: (String? v) {
                  if (v != null) setState(() => tip = v);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Dug'),
                        value: 'dug',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Štednja'),
                        value: 'stednja',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: nazivController,
                decoration: const InputDecoration(labelText: 'Naziv (npr. "Za sobu")'),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: iznosController,
                      decoration: const InputDecoration(labelText: 'Iznos'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: valuta,
                      decoration: const InputDecoration(labelText: 'Valuta'),
                      items: const [
                        DropdownMenuItem(value: 'RSD', child: Text('RSD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => valuta = v);
                      },
                    ),
                  ),
                ],
              ),
              if (valuta == 'EUR')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Računam kurs: 1 EUR = 117.2 RSD',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            ElevatedButton(
              onPressed: () async {
                final naziv = nazivController.text.trim();
                var iznos = double.tryParse(iznosController.text) ?? 0;

                if (valuta == 'EUR') {
                  iznos = iznos * 117.2; // Konverzija
                }

                if (naziv.isNotEmpty && iznos > 0) {
                  if (stavka == null) {
                    await FinansijeService.addLicnaStavka(tip, naziv, iznos);
                  } else {
                    await FinansijeService.updateLicnaStavka(stavka.id, tip, naziv, iznos);
                  }

                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }
}
