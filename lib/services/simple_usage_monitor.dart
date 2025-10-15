import 'package:shared_preferences/shared_preferences.dart';

/// Jednostavan servis za praćenje Supabase potrošnje
/// Automatski broji pozive i upozorava kad je potrebno
class SimpleUsageMonitor {
  static int _dnevniPozivi = 0;
  static DateTime _poslednjeDatum = DateTime.now();

  /// Pokretanje monitoring servisa - pozovite u main()
  static Future<void> pokreni() async {
    final prefs = await SharedPreferences.getInstance();

    // Učitaj sačuvane podatke
    _dnevniPozivi = prefs.getInt('dnevni_pozivi') ?? 0;
    final sacuvano = prefs.getString('poslednje_datum');

    if (sacuvano != null) {
      _poslednjeDatum = DateTime.parse(sacuvano);
    }

    // Resetuj ako je novi dan
    final danas = DateTime.now();
    if (danas.day != _poslednjeDatum.day) {
      await _resetujBrojac();
    }
  }

  /// Pozovite svaki put kad koristite Supabase
  /// Primer: SimpleUsageMonitor.brojPoziv(); supabase.from('tabela').select();
  static Future<void> brojPoziv() async {
    try {
      _dnevniPozivi++;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dnevni_pozivi', _dnevniPozivi);

      // Progresivna upozorenja
      if (_dnevniPozivi == 50) {
        print('📊 INFO: 50 API poziva danas - sve u redu!');
      } else if (_dnevniPozivi == 100) {
        print('⚠️ PAŽNJA: 100 poziva danas - možda previše testiranja?');
      } else if (_dnevniPozivi == 200) {
        print('🔥 UPOZORENJE: 200+ poziva danas - proverite optimizaciju!');
      }
    } catch (e) {
      // Ignoriši greške u brojanju da ne remeti główną funkcionalnost
      print('SimpleUsageMonitor greška: $e');
    }
  }

  /// Cache sistemski podaci
  static Map<String, String>? _cachedStats;
  static DateTime? _lastCacheTime;

  /// Dobij jednostavnu statistiku - ažurirano za Supabase 2025 limite
  static Future<Map<String, String>> dobijStatistiku() async {
    // Proverava cache (važi 30 sekundi)
    if (_cachedStats != null && _lastCacheTime != null) {
      final cacheAge = DateTime.now().difference(_lastCacheTime!);
      if (cacheAge.inSeconds < 30) {
        return _cachedStats!;
      }
    }

    // 🎉 ODLIČO: API pozivi su sada UNLIMITED u Supabase Free tier!
    // Fokus je sada na Active Users (50,000/mesečno) i Database Size (500MB)

    // Poboljšana procena korisnika:
    // Development faza: 1 dev = ~5-15 poziva dnevno
    // Production: 1 user = ~2-8 poziva dnevno
    final dnevniUsers = (_dnevniPozivi / 8).round(); // Realističnija procena
    final mesecniUsers = dnevniUsers * 30;
    final procenatUsers = (mesecniUsers / 50000 * 100).round();

    String status;
    if (procenatUsers < 20) {
      status = '🟢 ODLIČNO';
    } else if (procenatUsers < 50) {
      status = '🟡 DOBRO';
    } else if (procenatUsers < 80) {
      status = '🟠 PAŽNJA';
    } else {
      status = '🔴 OPREZ';
    }

    final rezultat = {
      'dnevni_pozivi': '$_dnevniPozivi',
      'procenjeni_users': '$dnevniUsers korisnika danas',
      'mesecna_procena': '$mesecniUsers od 50,000 korisnika',
      'procenat': '$procenatUsers%',
      'status': status,
      'poruka': _dobijPoruku(procenatUsers),
      'api_status': '✅ UNLIMITED (Free tier)',
      'database_limit': '500 MB',
      'storage_limit': '1 GB',
      'egress_limit': '5 GB',
      'last_update': DateTime.now().toString().substring(0, 19), // YYYY-MM-DD HH:mm:ss
    };

    // Cache rezultate
    _cachedStats = rezultat;
    _lastCacheTime = DateTime.now();

    return rezultat;
  }

  static Future<void> _resetujBrojac() async {
    _dnevniPozivi = 0;
    _poslednjeDatum = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dnevni_pozivi', 0);
    await prefs.setString('poslednje_datum', _poslednjeDatum.toIso8601String());
  }

  static String _dobijPoruku(int procenat) {
    if (procenat < 20) {
      return 'Odličo! API pozivi su UNLIMITED. Pazite na korisnike (50k limit).';
    } else if (procenat < 50) {
      return 'Dobro. Pratite broj aktivnih korisnika mesečno.';
    } else if (procenat < 80) {
      return 'Pažnja! Blizu ste 50k korisnika. Optimizujte ili upgrade.';
    } else {
      return 'OPREZ! Preko 80% user limita. Supabase Pro (25 USD) preporučen.';
    }
  }
}
