import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/putnik.dart';
import 'dart:async';

/// 💰 DEPOZIT SERVICE - koristi postojeće tabele sa real-time stream
class DepozitService {
  static final _supabase = Supabase.instance.client;
  static final _depozitController =
      StreamController<Map<String, double>>.broadcast();

  /// 🔄 STREAM DEPOZITA SVIH VOZAČA - REAL-TIME
  static Stream<Map<String, double>> get depozitStream =>
      _depozitController.stream;

  /// 💾 SAVE DEPOZIT - dodaj depozit u putovanje
  static Future<void> saveDepozit(String vozac, double iznos) async {
    try {
      // Kreirati dummy putovanje za depozit
      final putnik = Putnik(
        ime: 'DEPOZIT - $vozac',
        polazak: '00:00',
        dan: _getDanFromDate(DateTime.now()),
        grad: 'Depozit',
        mesecnaKarta: false,
        adresa: 'Depozit vozača',
        vozac: vozac,
        dodaoVozac: vozac,
        depozit: iznos,
        iznosPlacanja: 0.0, // Depozit nije cena putovanja
      );

      // Sačuvaj u putovanja_istorija
      await _supabase
          .from('putovanja_istorija')
          .insert(putnik.toPutovanjaIstorijaMap());

      // Trigger stream update
      _broadcastDepozitUpdate();
    } catch (e) {
      throw Exception('Greška pri čuvanju depozita: $e');
    }
  }

  /// 📖 LOAD DEPOZIT - učitaj depozit za danas
  static Future<double> loadDepozit(String vozac) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select('depozit')
          .eq('vozac', vozac)
          .eq('datum', today)
          .like('putnik_ime', 'DEPOZIT - %')
          .maybeSingle();

      return response?['depozit']?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 📊 LOAD ALL DEPOZITS - za sve vozače danas
  static Future<Map<String, double>> loadAllDepozits() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select('vozac, depozit')
          .eq('datum', today)
          .like('putnik_ime', 'DEPOZIT - %');

      final Map<String, double> depoziti = {};
      for (final row in response) {
        final vozac = row['vozac'] as String?;
        final iznos = row['depozit'] as double?;
        if (vozac != null && iznos != null) {
          depoziti[vozac] = iznos;
        }
      }

      return depoziti;
    } catch (e) {
      return {};
    }
  }

  /// 🗓️ HELPER - dan iz datuma
  static String _getDanFromDate(DateTime date) {
    const dani = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    return dani[date.weekday - 1];
  }

  /// 🔄 START REAL-TIME LISTENING
  static void startRealtimeSync() {
    final today = DateTime.now().toIso8601String().split('T')[0];

    _supabase
        .from('putovanja_istorija')
        .stream(primaryKey: ['id'])
        .eq('datum', today)
        .listen((data) {
          // Filter lokalno za depozite
          final hasDepozit = data.any((row) =>
              (row['putnik_ime'] as String?)?.startsWith('DEPOZIT - ') == true);

          if (hasDepozit) {
            _broadcastDepozitUpdate();
          }
        });
  }

  /// 📡 BROADCAST DEPOZIT UPDATE
  static Future<void> _broadcastDepozitUpdate() async {
    final allDepozits = await loadAllDepozits();
    _depozitController.add(allDepozits);
  }

  /// 🛑 DISPOSE RESOURCES
  static void dispose() {
    _depozitController.close();
  }
}
