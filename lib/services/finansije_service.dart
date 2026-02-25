import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 💰 FINANSIJE SERVICE
/// Računa prihode, troškove i neto zaradu
class FinansijeService {
  static SupabaseClient get _supabase => supabase;

  /// Dohvati sve aktivne troškove za određeni mesec/godinu
  static Future<List<Trosak>> getTroskovi({int? mesec, int? godina}) async {
    try {
      var query = _supabase.from('finansije_troskovi').select('*, vozaci(ime)').eq('aktivan', true);

      if (mesec != null) {
        query = query.eq('mesec', mesec);
      }
      if (godina != null) {
        query = query.eq('godina', godina);
      }

      final response = await query.order('tip');
      return (response as List).map((row) => Trosak.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ažuriraj trošak
  static Future<bool> updateTrosak(String id, double noviIznos) async {
    try {
      await _supabase
          .from('finansije_troskovi')
          .update({'iznos': noviIznos, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dodaj novi trošak za određeni mesec/godinu
  static Future<bool> addTrosak(String naziv, String tip, double iznos, {int? mesec, int? godina}) async {
    try {
      final now = DateTime.now();
      debugPrint(
          '📝 [Finansije] Dodajem trošak: $naziv ($tip) = $iznos za ${mesec ?? now.month}/${godina ?? now.year}');
      await _supabase.from('finansije_troskovi').insert({
        'naziv': naziv,
        'tip': tip,
        'iznos': iznos,
        'mesecno': true,
        'aktivan': true,
        'mesec': mesec ?? now.month,
        'godina': godina ?? now.year,
      });
      debugPrint('✅ [Finansije] Trošak dodat uspešno: $naziv');

      return true;
    } catch (e) {
      debugPrint('❌ [Finansije] Greška pri dodavanju troška $naziv: $e');
      return false;
    }
  }

  /// Obriši trošak (soft delete)
  static Future<bool> deleteTrosak(String id) async {
    try {
      await _supabase.from('finansije_troskovi').update({'aktivan': false}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dohvati ukupna potraživanja (putnici s vožnjama koji nisu platili u tekućem mesecu)
  static Future<double> getPotrazivanja() async {
    try {
      final now = DateTime.now();
      final mesec = now.month;
      final godina = now.year;

      // Dohvati sve putnike koji su imali vožnje ovaj mesec
      final voznjeResp = await _supabase
          .from('voznje_log')
          .select('putnik_id')
          .eq('tip', 'voznja')
          .filter('datum', 'gte', '$godina-${mesec.toString().padLeft(2, '0')}-01')
          .filter('datum', 'lte', '$godina-${mesec.toString().padLeft(2, '0')}-31');

      final putnikIds =
          (voznjeResp as List).map((r) => r['putnik_id'] as String?).where((id) => id != null).toSet().toList();

      if (putnikIds.isEmpty) return 0;

      // Od tih putnika, koji su platili ovaj mesec
      final uplateResp = await _supabase
          .from('voznje_log')
          .select('putnik_id')
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .filter('datum', 'gte', '$godina-${mesec.toString().padLeft(2, '0')}-01')
          .filter('datum', 'lte', '$godina-${mesec.toString().padLeft(2, '0')}-31');

      final placeniIds = (uplateResp as List).map((r) => r['putnik_id'] as String?).where((id) => id != null).toSet();

      // Putnici s dugom = imaju vožnje ali nisu platili
      final duznici = putnikIds.where((id) => !placeniIds.contains(id)).toList();

      // Proceni dug: 1500 din po dnevnom, 6000 po mesečnom (prosek)
      // Tačniji pristup: broji voznje * cena_po_danu za dnevne
      if (duznici.isEmpty) return 0;

      final putnicResp =
          await _supabase.from('registrovani_putnici').select('id, tip, cena_po_danu').inFilter('id', duznici);

      double ukupnoDug = 0;
      for (final p in putnicResp as List) {
        final tip = p['tip'] as String? ?? '';
        final cenaPoDanu = (p['cena_po_danu'] as num?)?.toDouble();

        if (tip == 'mesecni' || tip == 'radnik' || tip == 'ucenik') {
          // Mesečni - paušal 6000 ako nema cenu
          ukupnoDug += cenaPoDanu != null ? cenaPoDanu * 22 : 6000;
        } else {
          // Dnevni - procena po broju vožnji
          final brojVoznjiResp = await _supabase
              .from('voznje_log')
              .select('id')
              .eq('putnik_id', p['id'] as String)
              .eq('tip', 'voznja')
              .filter('datum', 'gte', '$godina-${mesec.toString().padLeft(2, '0')}-01')
              .filter('datum', 'lte', '$godina-${mesec.toString().padLeft(2, '0')}-31');
          final brojVoznji = (brojVoznjiResp as List).length;
          ukupnoDug += brojVoznji * (cenaPoDanu ?? 300);
        }
      }

      return ukupnoDug;
    } catch (e) {
      debugPrint('❌ [Finansije] Greška pri računanju potraživanja: $e');
      return 0;
    }
  }

  /// Dohvati kompletan finansijski izveštaj (Optimizovano via RPC)
  static Future<FinansijskiIzvestaj> getIzvestaj() async {
    try {
      final now = DateTime.now();
      final rpcResponse = await _supabase.rpc('get_full_finance_report');
      final data = Map<String, dynamic>.from(rpcResponse);

      final n = data['nedelja'];
      final m = data['mesec'];
      final g = data['godina'];
      final p = data['prosla'];
      final tPoTipuRaw = Map<String, dynamic>.from(data['troskovi_po_tipu'] ?? {});
      final Map<String, double> troskoviPoTipu = tPoTipuRaw.map(
        (key, value) => MapEntry(key, (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0),
      );

      // Potraživanja (frontend calculation for accuracy)
      final potrazivanja = await getPotrazivanja();

      // Datumi nedelje (ponedeljak - nedelja)
      final weekday = now.weekday;
      final mondayThisWeek = now.subtract(Duration(days: weekday - 1));
      final sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));

      return FinansijskiIzvestaj(
        prihodNedelja: _toDouble(n['prihod']),
        troskoviNedelja: _toDouble(n['troskovi']),
        netoNedelja: _toDouble(n['prihod']) - _toDouble(n['troskovi']),
        voznjiNedelja: n['voznje'] ?? 0,
        prihodMesec: _toDouble(m['prihod']),
        troskoviMesec: _toDouble(m['troskovi']),
        netoMesec: _toDouble(m['prihod']) - _toDouble(m['troskovi']),
        voznjiMesec: m['voznje'] ?? 0,
        prihodGodina: _toDouble(g['prihod']),
        troskoviGodina: _toDouble(g['troskovi']),
        netoGodina: _toDouble(g['prihod']) - _toDouble(g['troskovi']),
        voznjiGodina: g['voznje'] ?? 0,
        prihodProslaGodina: _toDouble(p['prihod']),
        troskoviProslaGodina: _toDouble(p['troskovi']),
        netoProslaGodina: _toDouble(p['prihod']) - _toDouble(p['troskovi']),
        voznjiProslaGodina: p['voznje'] ?? 0,
        proslaGodina: now.year - 1,
        troskoviPoTipu: troskoviPoTipu,
        ukupnoMesecniTroskovi: _toDouble(m['troskovi']),
        potrazivanja: potrazivanja,
        startNedelja: mondayThisWeek,
        endNedelja: sundayThisWeek,
      );
    } catch (e) {
      debugPrint('❌ [Finansije] Greška pri dohvatanju RPC izveštaja: $e');
      // Fallback na staru metodu ili prazan izvestaj
      return _getEmptyIzvestaj();
    }
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0;
    return (val is num) ? val.toDouble() : double.tryParse(val.toString()) ?? 0;
  }

  static FinansijskiIzvestaj _getEmptyIzvestaj() {
    final now = DateTime.now();
    return FinansijskiIzvestaj(
      prihodNedelja: 0,
      troskoviNedelja: 0,
      netoNedelja: 0,
      voznjiNedelja: 0,
      prihodMesec: 0,
      troskoviMesec: 0,
      netoMesec: 0,
      voznjiMesec: 0,
      prihodGodina: 0,
      troskoviGodina: 0,
      netoGodina: 0,
      voznjiGodina: 0,
      prihodProslaGodina: 0,
      troskoviProslaGodina: 0,
      netoProslaGodina: 0,
      voznjiProslaGodina: 0,
      proslaGodina: now.year - 1,
      troskoviPoTipu: {},
      ukupnoMesecniTroskovi: 0,
      potrazivanja: 0,
      startNedelja: now,
      endNedelja: now,
    );
  }

  /// Dohvati izveštaj za specifičan period (Custom Range)
  static Future<Map<String, dynamic>> getIzvestajZaPeriod(DateTime from, DateTime to) async {
    try {
      final response = await _supabase.rpc('get_custom_finance_report', params: {
        'p_from': from.toIso8601String().split('T')[0],
        'p_to': to.toIso8601String().split('T')[0],
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('❌ [Finansije] Greška custom report: $e');
      return {'prihod': 0, 'voznje': 0, 'troskovi': 0, 'neto': 0};
    }
  }

  /// 🛰️ REALTIME STREAM: Prati promene u relevantnim tabelama i osvežava izveštaj
  static Stream<FinansijskiIzvestaj> streamIzvestaj() async* {
    // Emituj inicijalne podatke
    yield await getIzvestaj();

    // Listen na promene u voznje_log i finansije_troskovi
    final voznjeStream = supabase.from('voznje_log').stream(primaryKey: ['id']);
    final troskoviStream = supabase.from('finansije_troskovi').stream(primaryKey: ['id']);

    // Svaki put kada se bilo koja tabela promeni, osveži ceo izveštaj
    // (Ovo je malo "skuplje", ali admin panelu je bitna tačnost)
    await for (final _ in StreamGroup.merge([voznjeStream, troskoviStream])) {
      yield await getIzvestaj();
    }
  }
}

/// Model za jedan trošak
class Trosak {
  final String id;
  final String naziv;
  final String tip;
  final double iznos;
  final bool mesecno;
  final bool aktivan;
  final String? vozacId;
  final String? vozacIme;
  final int? mesec;
  final int? godina;

  Trosak({
    required this.id,
    required this.naziv,
    required this.tip,
    required this.iznos,
    required this.mesecno,
    required this.aktivan,
    this.vozacId,
    this.vozacIme,
    this.mesec,
    this.godina,
  });

  factory Trosak.fromJson(Map<String, dynamic> json) {
    // Izvuci ime vozača iz join-a
    String? vozacIme;
    if (json['vozaci'] != null && json['vozaci'] is Map) {
      vozacIme = json['vozaci']['ime'] as String?;
    }

    return Trosak(
      id: json['id']?.toString() ?? '',
      naziv: json['naziv'] as String? ?? '',
      tip: json['tip'] as String? ?? 'ostalo',
      iznos: (json['iznos'] is num)
          ? (json['iznos'] as num).toDouble()
          : double.tryParse(json['iznos']?.toString() ?? '0') ?? 0,
      mesecno: json['mesecno'] as bool? ?? true,
      aktivan: json['aktivan'] as bool? ?? true,
      vozacId: json['vozac_id']?.toString(),
      vozacIme: vozacIme,
      mesec: json['mesec'] as int?,
      godina: json['godina'] as int?,
    );
  }

  /// Prikaži naziv (koristi ime vozača za plate)
  String get displayNaziv {
    if (tip == 'plata' && vozacIme != null) {
      return 'Plata - $vozacIme';
    }
    return naziv;
  }

  /// Emoji za tip troška
  String get emoji {
    switch (tip) {
      case 'plata':
        return '👷';
      case 'kredit':
        return '🏦';
      case 'gorivo':
        return '⛽';
      case 'amortizacija':
        return '🔧';
      case 'registracija':
        return '🛠️';
      case 'yu_auto':
        return '🇷🇸';
      case 'majstori':
        return '👨‍🔧';
      case 'ostalo':
        return '📋';
      case 'porez':
        return '🏛️';
      case 'alimentacija':
        return '👶';
      case 'racuni':
        return '🧾';
      default:
        return '❓';
    }
  }
}

/// Model za finansijski izveštaj
class FinansijskiIzvestaj {
  // Nedelja
  final double prihodNedelja;
  final double troskoviNedelja;
  final double netoNedelja;
  final int voznjiNedelja;

  // Mesec
  final double prihodMesec;
  final double troskoviMesec;
  final double netoMesec;
  final int voznjiMesec;

  // Godina
  final double prihodGodina;
  final double troskoviGodina;
  final double netoGodina;
  final int voznjiGodina;

  // Prošla godina
  final double prihodProslaGodina;
  final double troskoviProslaGodina;
  final double netoProslaGodina;
  final int voznjiProslaGodina;
  final int proslaGodina;

  // Detalji
  final Map<String, double> troskoviPoTipu;
  final double ukupnoMesecniTroskovi;
  final double potrazivanja;

  // Datumi
  final DateTime startNedelja;
  final DateTime endNedelja;

  FinansijskiIzvestaj({
    required this.prihodNedelja,
    required this.troskoviNedelja,
    required this.netoNedelja,
    required this.voznjiNedelja,
    required this.prihodMesec,
    required this.troskoviMesec,
    required this.netoMesec,
    required this.voznjiMesec,
    required this.prihodGodina,
    required this.troskoviGodina,
    required this.netoGodina,
    required this.voznjiGodina,
    required this.prihodProslaGodina,
    required this.troskoviProslaGodina,
    required this.netoProslaGodina,
    required this.voznjiProslaGodina,
    required this.proslaGodina,
    required this.troskoviPoTipu,
    required this.ukupnoMesecniTroskovi,
    required this.potrazivanja,
    required this.startNedelja,
    required this.endNedelja,
  });

  /// Formatiran datum nedelje
  String get nedeljaPeriod {
    return '${startNedelja.day}.${startNedelja.month}. - ${endNedelja.day}.${endNedelja.month}.';
  }
}
