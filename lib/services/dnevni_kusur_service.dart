import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

/// JEDNOSTAVAN DNEVNI KUSUR SERVIS
/// Vozač unese koliko ima sitnih para kad krene na smenu - to je to!
class DnevniKusurService {
  static const String _kusurPrefix = 'dnevni_kusur_';

  static final StreamController<Map<String, double>> _kusurController =
      StreamController<Map<String, double>>.broadcast();

  /// 🌅 JUTARNJI UNOS - vozač unese koliko ima sitnih para za danas
  static Future<bool> unesiJutarnjiKusur(String vozac, double iznos) async {
    final today = DateTime.now();
    final todayKey = '$_kusurPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    try {
      // Proveri da li je već uneo kusur danas
      final prefs = await SharedPreferences.getInstance();
      final vecUnesen = prefs.getBool('${todayKey}_unesen') ?? false;

      if (vecUnesen) {
        return false; // Već je uneo kusur danas
      }

      // Sačuvaj lokalno
      await prefs.setDouble(todayKey, iznos);
      await prefs.setBool('${todayKey}_unesen', true);
      await prefs.setString('${todayKey}_vreme', today.toIso8601String());

      // Ažuriraj bazu (vozaci.kusur kolonu)
      await supabase.rpc<void>(
        'update_vozac_kusur',
        params: {
          'vozac_ime': vozac,
          'novi_kusur': iznos,
        },
      ).timeout(const Duration(seconds: 3));

      // Emituj update
      _kusurController.add({vozac: iznos});

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 💰 DOBIJ TRENUTNI KUSUR za danas
  static Future<double> getTrenutniKusur(String vozac) async {
    final today = DateTime.now();
    final todayKey = '$_kusurPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(todayKey) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// ❓ DA LI JE VEĆ UNEO KUSUR DANAS
  static Future<bool> daLiJeUneoKusurDanas(String vozac) async {
    final today = DateTime.now();
    final todayKey = '$_kusurPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${todayKey}_unesen') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 🌊 STREAM za real-time kusur
  static Stream<double> streamKusurZaVozaca(String vozac) async* {
    // Pošalji trenutnu vrednost
    final trenutni = await getTrenutniKusur(vozac);
    yield trenutni;

    // Slušaj za ažuriranja
    await for (final update in _kusurController.stream) {
      if (update.containsKey(vozac)) {
        yield update[vozac]!;
      }
    }
  }

  /// 🧹 OBRIŠI STARE KUSUR PODATKE (starije od 7 dana)
  static Future<void> ocistiStareKusurPodatke() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateTime.now();

      for (final key in keys) {
        if (key.startsWith(_kusurPrefix)) {
          final parts = key.split('_');
          if (parts.length >= 5) {
            try {
              final year = int.parse(parts[2]);
              final month = int.parse(parts[3]);
              final day = int.parse(parts[4]);
              final kusurDate = DateTime(year, month, day);

              // Obriši ako je stariji od 7 dana
              if (today.difference(kusurDate).inDays > 7) {
                await prefs.remove(key);
              }
            } catch (e) {
              // Ako ne može da parsira datum, obriši key
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      // Greška u čišćenju - nije kritična
    }
  }
}
