import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 💰 FINANSIJE SERVICE
/// Računa prihode, troškove i neto zaradu
class FinansijeService {
  static SupabaseClient get _supabase => supabase;

  /// Dohvati ukupan prihod za period
  static Future<double> getPrihodZaPeriod(DateTime from, DateTime to) async {
    try {
      final response = await _supabase
          .from('voznje_log')
          .select('iznos')
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .gte('datum', from.toIso8601String().split('T')[0])
          .lte('datum', to.toIso8601String().split('T')[0]);

      double ukupno = 0;
      for (final row in response) {
        final iznos = row['iznos'];
        if (iznos != null) {
          ukupno += (iznos is num) ? iznos.toDouble() : double.tryParse(iznos.toString()) ?? 0;
        }
      }
      return ukupno;
    } catch (e) {
      return 0;
    }
  }

  /// Dohvati broj vožnji za period
  static Future<int> getBrojVoznjiZaPeriod(DateTime from, DateTime to) async {
    try {
      final response = await _supabase
          .from('voznje_log')
          .select('id')
          .eq('tip', 'voznja')
          .gte('datum', from.toIso8601String().split('T')[0])
          .lte('datum', to.toIso8601String().split('T')[0]);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

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

  /// Dohvati troškove za tekući mesec
  static Future<List<Trosak>> getTroskoviTekuciMesec() async {
    final now = DateTime.now();
    return getTroskovi(mesec: now.month, godina: now.year);
  }

  /// Dohvati ukupne troškove za mesec/godinu
  static Future<double> getUkupniTroskoviZaMesec(int mesec, int godina) async {
    final troskovi = await getTroskovi(mesec: mesec, godina: godina);
    double ukupno = 0;
    for (final t in troskovi) {
      ukupno += t.iznos;
    }
    return ukupno;
  }

  /// Dohvati ukupne troškove za celu godinu
  static Future<double> getUkupniTroskoviZaGodinu(int godina) async {
    try {
      final response =
          await _supabase.from('finansije_troskovi').select('iznos').eq('aktivan', true).eq('godina', godina);

      double ukupno = 0;
      for (final row in response) {
        final iznos = row['iznos'];
        if (iznos != null) {
          ukupno += (iznos is num) ? iznos.toDouble() : double.tryParse(iznos.toString()) ?? 0;
        }
      }
      return ukupno;
    } catch (e) {
      return 0;
    }
  }

  /// Dohvati ukupne troškove kreirane u zadatom periodu (po created_at ili mesec/godina)
  static Future<double> getUkupniTroskoviZaPeriod(DateTime from, DateTime to) async {
    try {
      // PROVERA: Ako period pokriva tačno jedan ceo mesec, koristi getUkupniTroskoviZaMesec
      // Ovo omogućava bolju preciznost za unose koji nisu u voznje_log već u finansije_troskovi (fix Zadatak 1)
      if (from.day == 1 && to.day >= 28 && from.month == to.month) {
        final lastDayOfMonth = DateTime(to.year, to.month + 1, 0).day;
        if (to.day == lastDayOfMonth) {
          return getUkupniTroskoviZaMesec(from.month, from.year);
        }
      }

      final response = await _supabase
          .from('finansije_troskovi')
          .select('iznos')
          .eq('aktivan', true)
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      double ukupno = 0;
      for (final row in response) {
        final iznos = row['iznos'];
        if (iznos != null) {
          ukupno += (iznos is num) ? iznos.toDouble() : double.tryParse(iznos.toString()) ?? 0;
        }
      }
      return ukupno;
    } catch (e) {
      debugPrint('❌ [Finansije] Greška pri dohvatanju troškova za period: $e');
      return 0;
    }
  }

  /// Dohvati troškove po tipu za mesec/godinu
  static Future<Map<String, double>> getTroskoviPoTipu({int? mesec, int? godina}) async {
    final troskovi = await getTroskovi(mesec: mesec, godina: godina);
    final Map<String, double> poTipu = {
      'plata': 0,
      'kredit': 0,
      'gorivo': 0,
      'amortizacija': 0,
      'registracija': 0,
      'yu_auto': 0,
      'majstori': 0,
      'ostalo': 0,
      'porez': 0,
      'alimentacija': 0,
      'racuni': 0,
    };

    for (final t in troskovi) {
      poTipu[t.tip] = (poTipu[t.tip] ?? 0) + t.iznos;
    }
    return poTipu;
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

  /// Dohvati ukupna potraživanja (iznosi koji nisu plaćeni)
  static Future<double> getPotrazivanja() async {
    try {
      // 1. Dohvati sve aktivne putnike
      final response = await _supabase.from('registrovani_putnici').select('*').eq('aktivan', true);

      double ukupno = 0;
      for (final row in response) {
        final polasciPoDanu = row['polasci_po_danu'];
        if (polasciPoDanu == null) continue;

        final String tip = (row['tip'] ?? 'Radnik').toString().toLowerCase();
        final bool jeMesecni = tip == 'radnik' || tip == 'ucenik' || tip == 'učenik';

        Map<String, dynamic> polasci;
        if (polasciPoDanu is String) {
          polasci = Map<String, dynamic>.from(const JsonDecoder().convert(polasciPoDanu));
        } else {
          polasci = Map<String, dynamic>.from(polasciPoDanu);
        }

        // Prođi kroz sve dane (pon, uto...)
        polasci.forEach((dan, mesta) {
          if (mesta is Map) {
            if (jeMesecni) {
              // ZA RADNIKE/UČENIKE: Brojimo samo JEDNOM po danu ako je bilo koje pokupljeno a neplaćeno
              bool imaDugZaOvajDan = false;
              double cenaDug = 0;

              mesta.forEach((mesto, podaci) {
                if (podaci is Map) {
                  final bool jePokupljen = podaci['pokupljen'] == true;
                  final bool jePlacen = podaci['placen'] == true || podaci['placeno'] == true;

                  if (jePokupljen && !jePlacen) {
                    imaDugZaOvajDan = true;
                    // Uzimamo iznos iz polaska ili iz putnika
                    final iznos = podaci['iznos'] ?? podaci['cena'] ?? row['cena_po_danu'] ?? 0;
                    cenaDug = (iznos is num) ? iznos.toDouble() : double.tryParse(iznos.toString()) ?? 0;
                  }
                }
              });

              if (imaDugZaOvajDan) {
                ukupno += cenaDug;
              }
            } else {
              // ZA DNEVNE/POŠILJKE: Brojimo SVAKI pokupljen i neplaćen polazak
              mesta.forEach((mesto, podaci) {
                if (podaci is Map) {
                  final bool jePokupljen = podaci['pokupljen'] == true;
                  final bool jePlacen = podaci['placen'] == true || podaci['placeno'] == true;

                  if (jePokupljen && !jePlacen) {
                    final iznos = podaci['iznos'] ?? podaci['cena'] ?? row['cena_po_danu'] ?? 0;
                    ukupno += (iznos is num) ? iznos.toDouble() : double.tryParse(iznos.toString()) ?? 0;
                  }
                }
              });
            }
          }
        });
      }
      return ukupno;
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
