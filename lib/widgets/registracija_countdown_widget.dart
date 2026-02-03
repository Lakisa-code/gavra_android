import 'package:flutter/material.dart';

import '../screens/odrzavanje_screen.dart';
import '../services/vozila_service.dart';

/// Helper klasa za deljene podatke o registraciji
class _RegistracijaData {
  static Vozilo? najblizeVozilo;
  static int? danaDoIsteka;
  static bool isLoading = true;
  static final List<VoidCallback> _listeners = [];

  static void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  static void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  static Future<void> load() async {
    try {
      final vozila = await VozilaService.getVozila();

      Vozilo? najblize;
      int? minDana;

      for (final v in vozila) {
        if (v.registracijaVaziDo != null) {
          final dana = v.registracijaVaziDo!.difference(DateTime.now()).inDays;
          if (minDana == null || dana < minDana) {
            minDana = dana;
            najblize = v;
          }
        }
      }

      najblizeVozilo = najblize;
      danaDoIsteka = minDana;
      isLoading = false;
      _notifyListeners();
    } catch (e) {
      isLoading = false;
      _notifyListeners();
    }
  }

  // Slika tablice za vozilo
  static String getTablicaImage(String registarskiBroj) {
    if (registarskiBroj.contains('066')) return 'assets/tablica_066.png';
    if (registarskiBroj.contains('088')) return 'assets/tablica_088.png';
    if (registarskiBroj.contains('093')) return 'assets/tablica_093.png';
    if (registarskiBroj.contains('097')) return 'assets/tablica_097.png';
    if (registarskiBroj.contains('102')) return 'assets/tablica_102.png';
    return 'assets/tablica_066.png';
  }

  // Boja teksta za dane - nijanse od 14 do 0
  static Color getDanaColor() {
    if (danaDoIsteka == null) return Colors.grey;
    if (danaDoIsteka! < 0) return Colors.red.shade900; // Istekla - tamno crvena
    if (danaDoIsteka! <= 2) return Colors.red; // 0-2 dana - crvena
    if (danaDoIsteka! <= 5) return Colors.deepOrange; // 3-5 dana - tamno narandžasta
    if (danaDoIsteka! <= 8) return Colors.orange; // 6-8 dana - narandžasta
    if (danaDoIsteka! <= 11) return Colors.amber; // 9-11 dana - žuta
    return Colors.lime; // 12-14 dana - limeta
  }
}

/// 🏷️ TABLICA WIDGET - samo slika tablice (leva strana)
class RegistracijaTablicaWidget extends StatefulWidget {
  const RegistracijaTablicaWidget({super.key});

  @override
  State<RegistracijaTablicaWidget> createState() => _RegistracijaTablicaWidgetState();
}

class _RegistracijaTablicaWidgetState extends State<RegistracijaTablicaWidget> {
  @override
  void initState() {
    super.initState();
    _RegistracijaData.addListener(_onDataChanged);
    if (_RegistracijaData.isLoading) {
      _RegistracijaData.load();
    }
  }

  @override
  void dispose() {
    _RegistracijaData.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _openKolskaKnjiga() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OdrzavanjeScreen()),
    ).then((_) => _RegistracijaData.load());
  }

  @override
  Widget build(BuildContext context) {
    // Sakrij ako nema podataka ili ako je vise od 14 dana do isteka
    if (_RegistracijaData.isLoading ||
        _RegistracijaData.najblizeVozilo == null ||
        (_RegistracijaData.danaDoIsteka != null && _RegistracijaData.danaDoIsteka! > 14)) {
      return const SizedBox.shrink();
    }

    final tablicaImage = _RegistracijaData.getTablicaImage(
      _RegistracijaData.najblizeVozilo!.registarskiBroj,
    );

    return GestureDetector(
      onTap: _openKolskaKnjiga,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          tablicaImage,
          width: 75,
          height: 19,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 📊 BROJAČ WIDGET - samo broj dana (desna strana)
class RegistracijaBrojacWidget extends StatefulWidget {
  const RegistracijaBrojacWidget({super.key});

  @override
  State<RegistracijaBrojacWidget> createState() => _RegistracijaBrojacWidgetState();
}

class _RegistracijaBrojacWidgetState extends State<RegistracijaBrojacWidget> {
  @override
  void initState() {
    super.initState();
    _RegistracijaData.addListener(_onDataChanged);
    if (_RegistracijaData.isLoading) {
      _RegistracijaData.load();
    }
  }

  @override
  void dispose() {
    _RegistracijaData.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _openKolskaKnjiga() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OdrzavanjeScreen()),
    ).then((_) => _RegistracijaData.load());
  }

  @override
  Widget build(BuildContext context) {
    // Sakrij ako nema podataka ili ako je vise od 14 dana do isteka
    if (_RegistracijaData.isLoading ||
        _RegistracijaData.najblizeVozilo == null ||
        (_RegistracijaData.danaDoIsteka != null && _RegistracijaData.danaDoIsteka! > 14)) {
      return const SizedBox.shrink();
    }

    final danaDoIsteka = _RegistracijaData.danaDoIsteka!;
    final danaText = danaDoIsteka < 0 ? '-${danaDoIsteka.abs()}d' : '${danaDoIsteka}d';

    return GestureDetector(
      onTap: _openKolskaKnjiga,
      child: Text(
        danaText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _RegistracijaData.getDanaColor(),
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

/// 🚗 ORIGINALNI REGISTRACIJA COUNTDOWN WIDGET (za kompatibilnost)
class RegistracijaCountdownWidget extends StatefulWidget {
  const RegistracijaCountdownWidget({super.key});

  @override
  State<RegistracijaCountdownWidget> createState() => _RegistracijaCountdownWidgetState();
}

class _RegistracijaCountdownWidgetState extends State<RegistracijaCountdownWidget> {
  @override
  void initState() {
    super.initState();
    _RegistracijaData.addListener(_onDataChanged);
    if (_RegistracijaData.isLoading) {
      _RegistracijaData.load();
    }
  }

  @override
  void dispose() {
    _RegistracijaData.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _openKolskaKnjiga() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OdrzavanjeScreen()),
    ).then((_) => _RegistracijaData.load());
  }

  // Boje vozila
  Color _getVoziloColor(String registarskiBroj) {
    if (registarskiBroj.contains('066')) return Colors.blue;
    if (registarskiBroj.contains('088')) return Colors.white;
    if (registarskiBroj.contains('093')) return Colors.red;
    if (registarskiBroj.contains('097')) return Colors.white;
    if (registarskiBroj.contains('102')) return Colors.blue;
    return Colors.grey.shade400;
  }

  Color _getBorderColor(Color color) {
    if (color == Colors.white) return Colors.grey.shade600;
    return color;
  }

  @override
  Widget build(BuildContext context) {
    if (_RegistracijaData.isLoading || _RegistracijaData.najblizeVozilo == null) {
      return const SizedBox.shrink();
    }

    final vozilo = _RegistracijaData.najblizeVozilo!;
    final color = _getVoziloColor(vozilo.registarskiBroj);
    final borderColor = _getBorderColor(color);
    final tablicaImage = _RegistracijaData.getTablicaImage(vozilo.registarskiBroj);
    final danaDoIsteka = _RegistracijaData.danaDoIsteka!;
    final danaText = danaDoIsteka < 0 ? '-${danaDoIsteka.abs()}d' : '${danaDoIsteka}d';

    return GestureDetector(
      onTap: _openKolskaKnjiga,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color == Colors.white ? Colors.grey.shade200 : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 2),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.amber, width: 2),
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
          Text(
            danaText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _RegistracijaData.getDanaColor(),
            ),
          ),
        ],
      ),
    );
  }
}
