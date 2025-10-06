import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/daily_checkin_service.dart';
import '../utils/vozac_boja.dart';
import '../utils/logging.dart';
import '../theme.dart'; // DODANO za theme extensions

class DailyCheckInScreen extends StatefulWidget {
  final String vozac;
  final VoidCallback onCompleted;

  const DailyCheckInScreen({
    Key? key,
    required this.vozac,
    required this.onCompleted,
  }) : super(key: key);

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen>
    with TickerProviderStateMixin {
  final TextEditingController _kusurController = TextEditingController();
  final FocusNode _kusurFocusNode = FocusNode();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // Auto-focus na input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kusurFocusNode.requestFocus();
      // 📊 NOVI: Proveri da li treba prikazati popis iz prethodnog dana
      _checkForPreviousDayReport();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _kusurController.dispose();
    _kusurFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitKusur() async {
    if (_kusurController.text.trim().isEmpty) {
      _showError('Unesite iznos sitnog novca!');
      return;
    }

    final double? iznos = double.tryParse(_kusurController.text.trim());
    if (iznos == null || iznos < 0) {
      _showError('Unesite valjan iznos!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DailyCheckInService.saveCheckIn(widget.vozac, iznos);

      if (mounted) {
        // Haptic feedback
        HapticFeedback.lightImpact();

        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Dobro jutro ${widget.vozac}! Uspešno zabeleženo.'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.successPrimary,
            duration: const Duration(seconds: 2),
          ),
        );

        // Čekaj malo pa zatvori
        await Future<void>.delayed(const Duration(milliseconds: 500));
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Greška: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.dangerPrimary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vozacColor = VozacBoja.get(widget.vozac);

    // Mekše jutarnje boje - pastelne verzije vozačevih boja
    final softVozacColor = Color.lerp(vozacColor, Colors.white, 0.4)!;
    final warmBackground =
        Color.lerp(vozacColor, const Color(0xFFFFF8E1), 0.8)!;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Tamni background za jutro
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2C2C), // Tamna jutarnja boja
              warmBackground.withOpacity(0.15),
              softVozacColor.withOpacity(0.1),
              const Color(0xFF1A1A1A), // Vraća se na tamno
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    // Jutarnja ikona - mekša i toplija
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            softVozacColor.withOpacity(0.8),
                            softVozacColor.withOpacity(0.4),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: softVozacColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                          // Dodatni warm glow
                          BoxShadow(
                            color: const Color(0xFFFFE0B2).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.light_mode_outlined, // Mekša jutarnja ikona
                        size: 60,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Jutarnji pozdrav
                    Text(
                      'Dobro jutro',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.95),
                        shadows: [
                          Shadow(
                            color: softVozacColor.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.vozac,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: softVozacColor,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Mekše instrukcije
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: softVozacColor.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: softVozacColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Unesite iznos sitnog novca za kusur',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Input field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: vozacColor.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _kusurController,
                        focusNode: _kusurFocusNode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 24,
                          ),
                          suffixText: 'RSD',
                          suffixStyle: TextStyle(
                            color: softVozacColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: softVozacColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                        ),
                        onSubmitted: (_) => _submitKusur(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitKusur,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: softVozacColor,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: softVozacColor.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Potvrdi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 📊 NOVI: Proveri da li treba prikazati popis iz prethodnog dana
  Future<void> _checkForPreviousDayReport() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (yesterday.weekday == 6 || yesterday.weekday == 7) {
        dlog(
            '🚫 Preskačem automatski popis za vikend (${yesterday.weekday == 6 ? "Subota" : "Nedelja"})');
        return;
      }

      // Proveri da li postoji popis od juče
      final lastReport =
          await DailyCheckInService.getLastDailyReport(widget.vozac);

      if (lastReport != null && mounted) {
        // POSTOJI RUČNI POPIS - Prikaži ga
        _showPreviousDayReportDialog(lastReport);
      } else {
        // NEMA RUČNOG POPISA - Generiši automatski
        final automatskiPopis =
            await DailyCheckInService.generateAutomaticReport(
                widget.vozac, yesterday);

        if (automatskiPopis != null && mounted) {
          // Prikaži automatski generisan popis
          _showAutomaticReportDialog(automatskiPopis);
        }
      }
    } catch (e) {
      dlog('Greška pri proveri prethodnog popisa: $e');
    }
  }

  // 📊 DIALOG ZA PRIKAZ POPISA IZ PRETHODNOG DANA
  void _showPreviousDayReportDialog(Map<String, dynamic> lastReport) {
    final datum = lastReport['datum'] as DateTime;
    final vozacColor = VozacBoja.get(widget.vozac);
    final popis = lastReport['popis'] as Map<String, dynamic>;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: vozacColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '� RUČNI POPIS - ${datum.day}.${datum.month}.${datum.year}',
              style: TextStyle(
                color: vozacColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vozač header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: vozacColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: vozacColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '👤 VOZAČ: ${widget.vozac}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: vozacColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Statistike
                _buildStatistikaRow(
                    '💰 Ukupan pazar',
                    '${popis['ukupanPazar']?.toStringAsFixed(0) ?? 0} din',
                    Theme.of(context).colorScheme.successPrimary),
                _buildStatistikaRow(
                    '👥 Dodati putnici',
                    '${popis['dodatiPutnici'] ?? 0}',
                    Theme.of(context).colorScheme.primary),
                _buildStatistikaRow(
                    '✅ Pokupljeni putnici',
                    '${popis['pokupljeniPutnici'] ?? 0}',
                    Theme.of(context).colorScheme.successPrimary),
                _buildStatistikaRow(
                    '💳 Naplaćeni putnici',
                    '${popis['naplaceniPutnici'] ?? 0}',
                    Theme.of(context).colorScheme.workerPrimary),
                _buildStatistikaRow(
                    '❌ Otkazani putnici',
                    '${popis['otkazaniPutnici'] ?? 0}',
                    Theme.of(context).colorScheme.dangerPrimary),
                _buildStatistikaRow(
                    '💸 Dugovi',
                    '${popis['dugoviPutnici'] ?? 0}',
                    Theme.of(context).colorScheme.studentPrimary),
                _buildStatistikaRow('🎫 Mesečne karte',
                    '${popis['mesecneKarte'] ?? 0}', Colors.purple),
                _buildStatistikaRow(
                    '🛣️ Kilometraža',
                    '${popis['kilometraza']?.toStringAsFixed(1) ?? 0} km',
                    Colors.indigo),
                if (popis['sitanNovac'] != null && (popis['sitanNovac'] as num) > 0)
                  _buildStatistikaRow(
                      '🪙 Sitan novac',
                      '${popis['sitanNovac']?.toStringAsFixed(0) ?? 0} din',
                      Colors.amber),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: vozacColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: vozacColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: vozacColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '💡 Sada možete uneti sitan novac za današnji dan.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: vozacColor.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: vozacColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('👤 Razumem'),
          ),
        ],
      ),
    );
  }

  // 🤖 DIALOG ZA AUTOMATSKI GENERISAN POPIS
  void _showAutomaticReportDialog(Map<String, dynamic> automatskiPopis) async {
    final datum = DateTime.parse(automatskiPopis['datum'] as String);
    final controller = TextEditingController(
        text: (automatskiPopis['sitanNovac'] as num?)?.toStringAsFixed(0) ?? '0');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: Theme.of(context).colorScheme.studentPrimary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🤖 AUTOMATSKI POPIS - ${datum.day}.${datum.month}.${datum.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.studentPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(0),
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .studentPrimary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .studentPrimary
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color:
                                  Theme.of(context).colorScheme.studentPrimary,
                              size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pošto niste uradili ručni popis juče, aplikacija je automatski generisala popis.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .studentPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vozač header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .studentPrimary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.studentPrimary,
                            width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '🤖 AUTOMATSKI VOZAČ: ${widget.vozac}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.studentPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistike
                    _buildStatistikaRow(
                        '💰 Ukupan pazar',
                        '${automatskiPopis['ukupanPazar']?.toStringAsFixed(0) ?? 0} din',
                        Theme.of(context).colorScheme.successPrimary),
                    _buildStatistikaRow(
                        '👥 Dodati putnici',
                        '${automatskiPopis['dodatiPutnici'] ?? 0}',
                        Theme.of(context).colorScheme.primary),
                    _buildStatistikaRow(
                        '✅ Pokupljeni putnici',
                        '${automatskiPopis['pokupljeniPutnici'] ?? 0}',
                        Theme.of(context).colorScheme.successPrimary),
                    _buildStatistikaRow(
                        '💳 Naplaćeni putnici',
                        '${automatskiPopis['naplaceniPutnici'] ?? 0}',
                        Theme.of(context).colorScheme.workerPrimary),
                    _buildStatistikaRow(
                        '❌ Otkazani putnici',
                        '${automatskiPopis['otkazaniPutnici'] ?? 0}',
                        Theme.of(context).colorScheme.dangerPrimary),
                    _buildStatistikaRow(
                        '� Dugovi',
                        '${automatskiPopis['dugoviPutnici'] ?? 0}',
                        Colors.orange),
                    _buildStatistikaRow(
                        '📋 Mesečne karte',
                        '${automatskiPopis['mesecneKarte'] ?? 0}',
                        Colors.purple),
                    _buildStatistikaRow(
                        '🚗 Kilometraža',
                        '${automatskiPopis['kilometraza']?.toStringAsFixed(1) ?? 0} km',
                        Colors.indigo),

                    const SizedBox(height: 20),

                    // Kusur input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '🪙 SITAN NOVAC (KUSUR)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Unesite iznos kusura',
                                suffixText: 'din',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '💡 Možete urediti iznos kusura koji ste imali juče.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Samo prikaži'),
          ),
          ElevatedButton(
            onPressed: () {
              // Ažuriraj sitan novac u automatskom popisu
              final newSitanNovac = double.tryParse(controller.text) ?? 0.0;
              automatskiPopis['sitanNovac'] = newSitanNovac;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('🤖 Sačuvaj kusur'),
          ),
        ],
      ),
    );

    // Ako je korisnik ažurirao kusur, sačuvaj u bazu
    if (result == true) {
      try {
        await _updateAutomatskiPopisSitanNovac(
            automatskiPopis, automatskiPopis['sitanNovac'] as double);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Kusur je ažuriran u automatskom popisu'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Greška pri ažuriranju kusura: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper za statistike
  Widget _buildStatistikaRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ažuriraj sitan novac u automatskom popisu
  Future<void> _updateAutomatskiPopisSitanNovac(
      Map<String, dynamic> automatskiPopis, double newSitanNovac) async {
    final supabase = Supabase.instance.client;
    final datum = DateTime.parse(automatskiPopis['datum'] as String);

    await supabase.from('daily_reports').upsert({
      'vozac': automatskiPopis['vozac'],
      'datum': datum.toIso8601String().split('T')[0],
      'ukupan_pazar': automatskiPopis['ukupanPazar'],
      'sitan_novac': newSitanNovac, // Ažurirani kusur
      'dodati_putnici': automatskiPopis['dodatiPutnici'],
      'otkazani_putnici': automatskiPopis['otkazaniPutnici'],
      'naplaceni_putnici': automatskiPopis['naplaceniPutnici'],
      'pokupljeni_putnici': automatskiPopis['pokupljeniPutnici'],
      'dugovi_putnici': automatskiPopis['dugoviPutnici'],
      'mesecne_karte': automatskiPopis['mesecneKarte'],
      'kilometraza': automatskiPopis['kilometraza'],
      'automatski_generisal': automatskiPopis['automatskiGenerisal'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
