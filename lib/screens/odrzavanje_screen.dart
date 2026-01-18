import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/vozila_service.dart';

/// 📖 KOLSKA KNJIGA
/// Tehničko praćenje vozila - servisi, registracija, gume...
class OdrzavanjeScreen extends StatefulWidget {
  const OdrzavanjeScreen({super.key});

  @override
  State<OdrzavanjeScreen> createState() => _OdrzavanjeScreenState();
}

class _OdrzavanjeScreenState extends State<OdrzavanjeScreen> {
  List<Vozilo> _vozila = [];
  bool _isLoading = true;
  Vozilo? _selectedVozilo;

  final _formatBroja = NumberFormat('#,###', 'sr');

  @override
  void initState() {
    super.initState();
    _loadVozila();
  }

  Future<void> _loadVozila() async {
    setState(() => _isLoading = true);
    final vozila = await VozilaService.getVozila();
    setState(() {
      _vozila = vozila;
      _isLoading = false;
      // Ako je bilo selektovano vozilo, osveži ga
      if (_selectedVozilo != null) {
        _selectedVozilo = vozila.firstWhere(
          (v) => v.id == _selectedVozilo!.id,
          orElse: () => vozila.first,
        );
      }
    });
  }

  void _selectVozilo(Vozilo? vozilo) {
    setState(() {
      _selectedVozilo = vozilo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Kolska knjiga'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVozila,
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vozila.isEmpty
              ? const Center(child: Text('Nema vozila u bazi'))
              : Column(
                  children: [
                    // Dropdown za izbor vozila
                    _buildVoziloDropdown(),

                    // Karton vozila
                    Expanded(
                      child: _selectedVozilo == null
                          ? const Center(
                              child: Text(
                                'Izaberi vozilo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : _buildKolskaKnjiga(),
                    ),
                  ],
                ),
    );
  }

  // Boje vozila - 066 plava, 088 beli, 093 crvena, 097 bela, 102 plava
  Color _getVoziloColor(String registarskiBroj) {
    if (registarskiBroj.contains('066')) return Colors.blue;
    if (registarskiBroj.contains('088')) return Colors.white;
    if (registarskiBroj.contains('093')) return Colors.red;
    if (registarskiBroj.contains('097')) return Colors.white;
    if (registarskiBroj.contains('102')) return Colors.blue;
    return Colors.grey.shade400; // Siva za ostale
  }

  // Dani do isteka registracije
  int? _getDanaDoIsteka(Vozilo vozilo) {
    if (vozilo.registracijaVaziDo == null) return null;
    return vozilo.registracijaVaziDo!.difference(DateTime.now()).inDays;
  }

  // Informativna senka za 15-30 dana do isteka (žuta/limeta)
  List<BoxShadow>? _getRegistracijaSenka(Vozilo vozilo) {
    final danaDoIsteka = _getDanaDoIsteka(vozilo);
    if (danaDoIsteka == null) return null;

    // Samo za 15-30 dana (≤14 dana već ima widget na home screenu)
    if (danaDoIsteka >= 15 && danaDoIsteka <= 30) {
      return [
        BoxShadow(
          color: Colors.lime.withValues(alpha: 0.6),
          blurRadius: 12,
          spreadRadius: 3,
        ),
      ];
    }
    return null;
  }

  // Slika tablice za vozilo
  String _getTablicaImage(String registarskiBroj) {
    if (registarskiBroj.contains('066')) return 'assets/tablica_066.png';
    if (registarskiBroj.contains('088')) return 'assets/tablica_088.png';
    if (registarskiBroj.contains('093')) return 'assets/tablica_093.png';
    if (registarskiBroj.contains('097')) return 'assets/tablica_097.png';
    if (registarskiBroj.contains('102')) return 'assets/tablica_102.png';
    return 'assets/tablica_066.png'; // fallback
  }

  // Da li treba tamni okvir (za bele ikonice)
  Color _getVoziloBorderColor(String registarskiBroj, bool isSelected, Color color) {
    if (isSelected) return color == Colors.white ? Colors.black : color;
    if (color == Colors.white) return Colors.grey.shade600; // Tamni okvir za belo
    return Colors.grey.shade300;
  }

  // Dijalog za promenu broja mesta
  Future<void> _editBrojMesta(Vozilo vozilo) async {
    final controller = TextEditingController(text: vozilo.brojMesta?.toString() ?? '');

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Broj mesta - ${vozilo.registarskiBroj}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Broj mesta',
            hintText: 'npr. 8, 10, 14...',
            prefixIcon: Icon(Icons.event_seat),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () {
              final broj = int.tryParse(controller.text);
              Navigator.pop(context, broj);
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );

    if (result != null && result != vozilo.brojMesta) {
      await VozilaService.updateBrojMesta(vozilo.id, result);
      await _loadVozila();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broj mesta za ${vozilo.registarskiBroj}: $result')),
        );
      }
    }
  }

  Widget _buildVoziloDropdown() {
    // Sortiraj: 066 levo, 102 desno, ostali po redu
    final sortedVozila = List<Vozilo>.from(_vozila)
      ..sort((a, b) {
        if (a.registarskiBroj.contains('066')) return -1;
        if (b.registarskiBroj.contains('066')) return 1;
        if (a.registarskiBroj.contains('102')) return 1;
        if (b.registarskiBroj.contains('102')) return -1;
        return a.registarskiBroj.compareTo(b.registarskiBroj);
      });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: sortedVozila.map((vozilo) {
            final isSelected = _selectedVozilo?.id == vozilo.id;
            final color = _getVoziloColor(vozilo.registarskiBroj);
            final borderColor = _getVoziloBorderColor(vozilo.registarskiBroj, isSelected, color);
            final tablicaImage = _getTablicaImage(vozilo.registarskiBroj);
            final registracijaSenka = _getRegistracijaSenka(vozilo);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () => _selectVozilo(vozilo),
                onLongPress: () => _editBrojMesta(vozilo),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kombi ikona
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (color == Colors.white ? Colors.grey.shade200 : color.withValues(alpha: 0.2))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                        boxShadow: registracijaSenka, // 🟡 Informativna senka 15-30 dana
                      ),
                      child: Icon(
                        Icons.airport_shuttle,
                        size: 32,
                        color: color,
                        shadows: [
                          Shadow(
                            color: Colors.grey.shade600,
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Tablica - slika
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected ? Colors.amber : Colors.transparent,
                          width: isSelected ? 2 : 0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.asset(
                          tablicaImage,
                          width: 60,
                          height: 15,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Broj mesta
                    Text(
                      '${vozilo.brojMesta ?? '?'} mesta',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKolskaKnjiga() {
    final v = _selectedVozilo!;

    return RefreshIndicator(
      onRefresh: _loadVozila,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header sa osnovnim info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.displayNaziv,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registracija: ${v.registarskiBroj}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (v.godinaProizvodnje != null)
                      Text(
                        'Godina: ${v.godinaProizvodnje}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Broj šasije
            _buildEditableField(
              icon: '🔢',
              label: 'Broj šasije (VIN)',
              value: v.brojSasije,
              onEdit: () => _editTextField('broj_sasije', 'Broj šasije', v.brojSasije),
            ),

            // Registracija važi do
            _buildEditableField(
              icon: '📋',
              label: 'Registracija važi do',
              value: Vozilo.formatDatum(v.registracijaVaziDo),
              valueColor: v.registracijaIstekla
                  ? Colors.red
                  : v.registracijaIstice
                      ? Colors.orange
                      : null,
              badge: v.registracijaIstekla
                  ? 'ISTEKLA!'
                  : v.registracijaIstice
                      ? '${v.danaDoIstekaRegistracije} dana'
                      : null,
              badgeColor: v.registracijaIstekla ? Colors.red : Colors.orange,
              onEdit: () => _editDateField('registracija_vazi_do', 'Registracija važi do', v.registracijaVaziDo),
            ),

            // Napomena
            _buildEditableField(
              icon: '📝',
              label: 'Napomena',
              value: v.napomena ?? '-',
              onEdit: () => _editTextField('napomena', 'Napomena', v.napomena, multiline: true),
            ),

            const Divider(height: 32),

            // Mali servis
            _buildEditableField(
              icon: '🔧',
              label: 'Mali servis',
              value: _formatServis(v.maliServisDatum, v.maliServisKm),
              onEdit: () => _editServisField('mali_servis', 'Mali servis', v.maliServisDatum, v.maliServisKm),
            ),

            // Veliki servis
            _buildEditableField(
              icon: '🛠️',
              label: 'Veliki servis',
              value: _formatServis(v.velikiServisDatum, v.velikiServisKm),
              onEdit: () => _editServisField('veliki_servis', 'Veliki servis', v.velikiServisDatum, v.velikiServisKm),
            ),

            // Alternator
            _buildEditableField(
              icon: '⚡',
              label: 'Alternator',
              value: _formatServis(v.alternatorDatum, v.alternatorKm),
              onEdit: () => _editServisField('alternator', 'Alternator', v.alternatorDatum, v.alternatorKm),
            ),

            // Akumulator
            _buildEditableField(
              icon: '🔋',
              label: 'Akumulator',
              value: _formatServis(v.akumulatorDatum, v.akumulatorKm),
              onEdit: () => _editServisField('akumulator', 'Akumulator', v.akumulatorDatum, v.akumulatorKm),
            ),

            // Pločice
            _buildEditableField(
              icon: '🛑',
              label: 'Pločice (kočnice)',
              value: _formatServis(v.plociceDatum, v.plociceKm),
              onEdit: () => _editServisField('plocice', 'Pločice', v.plociceDatum, v.plociceKm),
            ),

            // Trap
            _buildEditableField(
              icon: '🔩',
              label: 'Trap',
              value: _formatServis(v.trapDatum, v.trapKm),
              onEdit: () => _editServisField('trap', 'Trap', v.trapDatum, v.trapKm),
            ),

            const Divider(height: 32),

            // Gume prednje
            _buildEditableField(
              icon: '🛞',
              label: 'Gume prednje',
              value: v.gumePrednjeOpis ?? v.gumeOpis ?? '-',
              subtitle: v.gumePrednjeDatum != null
                  ? 'Menjane: ${Vozilo.formatDatum(v.gumePrednjeDatum)}'
                  : v.gumeDatum != null
                      ? 'Menjane: ${Vozilo.formatDatum(v.gumeDatum)}'
                      : null,
              onEdit: () =>
                  _editGumeField('prednje', v.gumePrednjeDatum ?? v.gumeDatum, v.gumePrednjeOpis ?? v.gumeOpis),
            ),

            // Gume zadnje
            _buildEditableField(
              icon: '🛞',
              label: 'Gume zadnje',
              value: v.gumeZadnjeOpis ?? '-',
              subtitle: v.gumeZadnjeDatum != null ? 'Menjane: ${Vozilo.formatDatum(v.gumeZadnjeDatum)}' : null,
              onEdit: () => _editGumeField('zadnje', v.gumeZadnjeDatum, v.gumeZadnjeOpis),
            ),

            const Divider(height: 32),

            // Radio code
            _buildEditableField(
              icon: '📻',
              label: 'Radio code',
              value: v.radio,
              onEdit: () => _editTextField('radio', 'Radio code', v.radio),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _formatServis(DateTime? datum, int? km) {
    if (datum == null && km == null) return '-';
    final parts = <String>[];
    if (datum != null) parts.add(Vozilo.formatDatum(datum));
    if (km != null) parts.add('${_formatBroja.format(km)} km');
    return parts.join(' • ');
  }

  Widget _buildEditableField({
    required String icon,
    required String label,
    required String? value,
    String? subtitle,
    Color? valueColor,
    String? badge,
    Color? badgeColor,
    required VoidCallback onEdit,
  }) {
    return Card(
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? '-',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: valueColor,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor?.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EDIT DIALOGS
  // ═══════════════════════════════════════════════════════════════

  void _editTextField(String field, String label, String? currentValue, {bool multiline = false}) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Unesi $label',
          ),
          maxLines: multiline ? 4 : 1,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () async {
              final success = await VozilaService.updateKolskaKnjiga(
                _selectedVozilo!.id,
                {field: controller.text.isEmpty ? null : controller.text},
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                _loadVozila();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Sačuvano')),
                );
              }
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  void _editDateField(String field, String label, DateTime? currentValue) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentValue ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: label,
    );

    if (picked != null) {
      final success = await VozilaService.updateKolskaKnjiga(
        _selectedVozilo!.id,
        {field: picked.toIso8601String().split('T')[0]},
      );
      if (success) {
        _loadVozila();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Sačuvano')),
          );
        }
      }
    }
  }

  void _editServisField(String prefix, String label, DateTime? datum, int? km) {
    DateTime? selectedDatum = datum;
    final kmController = TextEditingController(text: km?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Datum
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDatum ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDatum = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Datum',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        selectedDatum != null
                            ? '${selectedDatum!.day}.${selectedDatum!.month}.${selectedDatum!.year}'
                            : 'Izaberi datum',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kilometraža
                  TextField(
                    controller: kmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kilometraža',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed),
                      suffixText: 'km',
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () async {
                      final kmValue = int.tryParse(kmController.text);
                      final success = await VozilaService.updateKolskaKnjiga(
                        _selectedVozilo!.id,
                        {
                          '${prefix}_datum': selectedDatum?.toIso8601String().split('T')[0],
                          '${prefix}_km': kmValue,
                        },
                      );

                      // Dodaj u istoriju
                      if (success && (selectedDatum != null || kmValue != null)) {
                        await VozilaService.addIstorijuServisa(
                          voziloId: _selectedVozilo!.id,
                          tip: prefix,
                          datum: selectedDatum,
                          km: kmValue,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (success) {
                        _loadVozila();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Sačuvano')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Sačuvaj'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editGumeField(String pozicija, DateTime? datum, String? opis) {
    DateTime? selectedDatum = datum;
    final opisController = TextEditingController(text: opis ?? '');
    final isPrednje = pozicija == 'prednje';
    final label = isPrednje ? 'Gume prednje' : 'Gume zadnje';

    // Tipovi guma sa emoji
    String? selectedTip;
    // Pokušaj prepoznati tip iz opisa
    if (opis != null) {
      if (opis.contains('☀️') || opis.toLowerCase().contains('letn')) {
        selectedTip = 'letnje';
      } else if (opis.contains('❄️') || opis.toLowerCase().contains('zimsk')) {
        selectedTip = 'zimske';
      } else if (opis.contains('🌤️') ||
          opis.toLowerCase().contains('m+s') ||
          opis.toLowerCase().contains('univerzal')) {
        selectedTip = 'ms';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '🛞 $label',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tip guma - brzi izbor
                  const Text('Tip guma:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTipGumaChip(
                          '☀️ Letnje',
                          'letnje',
                          selectedTip,
                          (tip) => setStateDialog(() => selectedTip = tip),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTipGumaChip(
                          '❄️ Zimske',
                          'zimske',
                          selectedTip,
                          (tip) => setStateDialog(() => selectedTip = tip),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTipGumaChip(
                          '🌤️ M+S',
                          'ms',
                          selectedTip,
                          (tip) => setStateDialog(() => selectedTip = tip),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Opis guma
                  TextField(
                    controller: opisController,
                    decoration: const InputDecoration(
                      labelText: 'Marka i dimenzija',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      hintText: 'npr. Michelin 215/65 R16',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Datum zamene
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDatum ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDatum = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Datum zamene',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        selectedDatum != null
                            ? '${selectedDatum!.day}.${selectedDatum!.month}.${selectedDatum!.year}'
                            : 'Izaberi datum',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () async {
                      // Složi opis sa tipom guma
                      String finalOpis = '';
                      if (selectedTip != null) {
                        final tipEmoji = selectedTip == 'letnje'
                            ? '☀️'
                            : selectedTip == 'zimske'
                                ? '❄️'
                                : '🌤️';
                        finalOpis = tipEmoji;
                      }
                      if (opisController.text.isNotEmpty) {
                        finalOpis += finalOpis.isNotEmpty ? ' ${opisController.text}' : opisController.text;
                      }

                      // Sačuvaj u vozila tabelu
                      final updateData = isPrednje
                          ? {
                              'gume_prednje_datum': selectedDatum?.toIso8601String().split('T')[0],
                              'gume_prednje_opis': finalOpis.isEmpty ? null : finalOpis,
                            }
                          : {
                              'gume_zadnje_datum': selectedDatum?.toIso8601String().split('T')[0],
                              'gume_zadnje_opis': finalOpis.isEmpty ? null : finalOpis,
                            };

                      final success = await VozilaService.updateKolskaKnjiga(
                        _selectedVozilo!.id,
                        updateData,
                      );

                      // Dodaj u istoriju
                      if (success && selectedDatum != null) {
                        await VozilaService.addIstorijuServisa(
                          voziloId: _selectedVozilo!.id,
                          tip: isPrednje ? 'gume_prednje' : 'gume_zadnje',
                          datum: selectedDatum,
                          opis: finalOpis.isEmpty ? null : finalOpis,
                          pozicija: pozicija,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (success) {
                        _loadVozila();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Sačuvano')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Sačuvaj'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipGumaChip(String label, String value, String? selected, Function(String?) onTap) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onTap(isSelected ? null : value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade800 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
