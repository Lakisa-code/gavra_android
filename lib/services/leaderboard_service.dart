import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 🏆💀 LEADERBOARD SERVICE
/// Wall of Fame / Wall of Shame sistem
/// Računa uspešnost putnika po tipu (učenik/radnik) za tekući mesec
class LeaderboardService {
  static SupabaseClient get _supabase => supabase;

  /// Dohvati leaderboard za određeni tip putnika
  /// Vraća Top 5 (najbolji) i Bottom 5 (najgori)
  static Future<LeaderboardData> getLeaderboard({
    required String tipPutnika, // 'ucenik' ili 'radnik'
  }) async {
    try {
      // 1. Dohvati sve putnike ovog tipa
      final putnici = await _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime')
          .eq('tip', tipPutnika)
          .eq('aktivan', true)
          .eq('obrisan', false);

      if (putnici.isEmpty) {
        return LeaderboardData.empty();
      }

      // 2. Dohvati sve voznje_log zapise za ovaj mesec
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final firstOfMonthStr = firstOfMonth.toIso8601String().split('T')[0];

      final voznjeLogs = await _supabase
          .from('voznje_log')
          .select('putnik_id, tip')
          .gte('datum', firstOfMonthStr)
          .inFilter('tip', ['voznja', 'otkazivanje']);

      // 3. Izračunaj statistiku za svakog putnika
      final Map<String, int> voznjePoPutniku = {};
      final Map<String, int> otkazivanjaPoPutniku = {};

      for (final log in voznjeLogs) {
        final putnikId = log['putnik_id'] as String?;
        final tip = log['tip'] as String?;
        if (putnikId == null || tip == null) continue;

        if (tip == 'voznja') {
          voznjePoPutniku[putnikId] = (voznjePoPutniku[putnikId] ?? 0) + 1;
        } else if (tip == 'otkazivanje') {
          otkazivanjaPoPutniku[putnikId] = (otkazivanjaPoPutniku[putnikId] ?? 0) + 1;
        }
      }

      // 4. Kreiraj listu sa uspešnošću
      final List<LeaderboardEntry> entries = [];

      for (final putnik in putnici) {
        final id = putnik['id']?.toString() ?? '';
        final ime = putnik['putnik_ime'] as String? ?? 'Nepoznato';

        final voznje = voznjePoPutniku[id] ?? 0;
        final otkazivanja = otkazivanjaPoPutniku[id] ?? 0;
        final ukupno = voznje + otkazivanja;

        // Preskoči putnike bez aktivnosti ovog meseca
        if (ukupno == 0) continue;

        final uspesnost = (voznje / ukupno * 100).round();

        entries.add(LeaderboardEntry(
          putnikId: id,
          ime: ime,
          voznje: voznje,
          otkazivanja: otkazivanja,
          uspesnost: uspesnost,
        ));
      }

      // 5. Sortiraj - najbolji prvo
      entries.sort((a, b) => b.uspesnost.compareTo(a.uspesnost));

      // 6. Uzmi top 5 i bottom 5
      final top5 = entries.take(5).toList();

      // Bottom 5 - od kraja, ali obrnuto (najgori prvi)
      final bottom5 = entries.length > 5 ? entries.reversed.take(5).toList() : <LeaderboardEntry>[];

      // Dodaj ikone
      _assignIcons(top5, isWallOfFame: true);
      _assignIcons(bottom5, isWallOfFame: false);

      return LeaderboardData(
        wallOfFame: top5,
        wallOfShame: bottom5,
        mesec: _getMonthName(now.month),
        godina: now.year,
      );
    } catch (e) {
      return LeaderboardData.empty();
    }
  }

  /// 🛰️ REALTIME STREAM: Prati promene u voznje_log i osvežava leaderboard
  static Stream<LeaderboardData> streamLeaderboard({required String tipPutnika}) async* {
    yield await getLeaderboard(tipPutnika: tipPutnika);

    // Slušaj promene u voznje_log
    await for (final _ in supabase.from('voznje_log').stream(primaryKey: ['id'])) {
      yield await getLeaderboard(tipPutnika: tipPutnika);
    }
  }

  /// Dodeli ikone po rangu
  static void _assignIcons(List<LeaderboardEntry> entries, {required bool isWallOfFame}) {
    final icons = isWallOfFame
        ? ['👑', '🏆', '🥇', '⭐', '✅'] // Wall of Fame
        : ['💀', '🐢', '🫣', '⚠️', '🚨']; // Wall of Shame

    for (int i = 0; i < entries.length && i < icons.length; i++) {
      entries[i] = entries[i].copyWith(icon: icons[i]);
    }
  }

  /// Ime meseca na srpskom
  static String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}

/// Jedan unos u leaderboard-u
class LeaderboardEntry {
  final String putnikId;
  final String ime;
  final int voznje;
  final int otkazivanja;
  final int uspesnost; // 0-100%
  final String icon;

  LeaderboardEntry({
    required this.putnikId,
    required this.ime,
    required this.voznje,
    required this.otkazivanja,
    required this.uspesnost,
    this.icon = '',
  });

  LeaderboardEntry copyWith({String? icon}) {
    return LeaderboardEntry(
      putnikId: putnikId,
      ime: ime,
      voznje: voznje,
      otkazivanja: otkazivanja,
      uspesnost: uspesnost,
      icon: icon ?? this.icon,
    );
  }
}

/// Kompletni podaci za leaderboard
class LeaderboardData {
  final List<LeaderboardEntry> wallOfFame;
  final List<LeaderboardEntry> wallOfShame;
  final String mesec;
  final int godina;

  LeaderboardData({
    required this.wallOfFame,
    required this.wallOfShame,
    required this.mesec,
    required this.godina,
  });

  factory LeaderboardData.empty() {
    return LeaderboardData(
      wallOfFame: [],
      wallOfShame: [],
      mesec: '',
      godina: 0,
    );
  }

  bool get isEmpty => wallOfFame.isEmpty && wallOfShame.isEmpty;
}
