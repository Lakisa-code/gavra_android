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

  /// Dohvati ukupne troškove kreirane u zadatom periodu (po created_at)
  static Future<double> getUkupniTroskoviZaPeriod(DateTime from, DateTime to) async {
    try {
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

      // 🔄 AUTOMATIZACIJA: Ako je trošak "kredit", smanji iznos duga "Kredit" u ličnim finansijama
      if (tip == 'kredit') {
        _smanjiDugZaKredit(iznos);
      }

      return true;
    } catch (e) {
      debugPrint('❌ [Finansije] Greška pri dodavanju troška $naziv: $e');
      return false;
    }
  }

  /// Pomoćna funkcija za smanjenje duga kredita
  static Future<void> _smanjiDugZaKredit(double iznosRata) async {
    try {
      // 1. Nađi stavku "Kredit" ili "kredit" u dugovima
      final response = await _supabase
          .from('finansije_licno')
          .select()
          .eq('tip', 'dug')
          .ilike('naziv', '%kredit%') // Case-insensitive traženje "kredit" u nazivu
          .limit(1);

      if ((response as List).isNotEmpty) {
        final dug = response.first;
        final stariIznos = (dug['iznos'] is num) ? (dug['iznos'] as num).toDouble() : 0.0;
        final noviIznos = stariIznos - iznosRata;

        // 2. Ažuriraj iznos duga (ne ide ispod nule)
        await _supabase.from('finansije_licno').update({'iznos': noviIznos > 0 ? noviIznos : 0}).eq('id', dug['id']);

        debugPrint('📉 [Finansije] Dug za kredit smanjen za $iznosRata. Novo stanje: $noviIznos');
      }
    } catch (e) {
      debugPrint('⚠️ Greška pri automatskom smanjenju duga: $e');
    }
  }

  // ---------------- LIČNE FINANSIJE (Dugovi / Ušteđevina) ----------------

  /// Dohvati sve lične stavke
  static Future<List<LicnaStavka>> getLicneStavke() async {
    try {
      final response = await _supabase.from('finansije_licno').select().order('created_at');
      return (response as List).map((row) => LicnaStavka.fromJson(row)).toList();
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju ličnih stavki: $e');
      return [];
    }
  }

  /// Dodaj ličnu stavku
  static Future<bool> addLicnaStavka(String tip, String naziv, double iznos) async {
    try {
      await _supabase.from('finansije_licno').insert({
        'tip': tip,
        'naziv': naziv,
        'iznos': iznos,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Greška pri dodavanju lične stavke: $e');
      return false;
    }
  }

  /// Ažuriraj ličnu stavku
  static Future<bool> updateLicnaStavka(String id, String tip, String naziv, double iznos) async {
    try {
      await _supabase.from('finansije_licno').update({
        'tip': tip,
        'naziv': naziv,
        'iznos': iznos,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Greška pri ažuriranju lične stavke: $e');
      return false;
    }
  }

  /// Obriši ličnu stavku
  static Future<bool> deleteLicnaStavka(String id) async {
    try {
      await _supabase.from('finansije_licno').delete().eq('id', id);
      return true;
    } catch (e) {
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

  /// Dohvati kompletan finansijski izveštaj
  static Future<FinansijskiIzvestaj> getIzvestaj() async {
    final now = DateTime.now();

    // Ova nedelja (ponedeljak - nedelja)
    final weekday = now.weekday;
    final mondayThisWeek = now.subtract(Duration(days: weekday - 1));
    final sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));
    final startOfWeek = DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day);
    final endOfWeek = DateTime(sundayThisWeek.year, sundayThisWeek.month, sundayThisWeek.day, 23, 59, 59);

    // Ovaj mesec
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Ova godina
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

    // Prošla godina
    final proslaGodina = now.year - 1;
    final startOfProslaGodina = DateTime(proslaGodina, 1, 1);
    final endOfProslaGodina = DateTime(proslaGodina, 12, 31, 23, 59, 59);

    // Prihodi
    final prihodNedelja = await getPrihodZaPeriod(startOfWeek, endOfWeek);
    final prihodMesec = await getPrihodZaPeriod(startOfMonth, endOfMonth);
    final prihodGodina = await getPrihodZaPeriod(startOfYear, endOfYear);
    final prihodProslaGodina = await getPrihodZaPeriod(startOfProslaGodina, endOfProslaGodina);

    // Vožnje
    final voznjiNedelja = await getBrojVoznjiZaPeriod(startOfWeek, endOfWeek);
    final voznjiMesec = await getBrojVoznjiZaPeriod(startOfMonth, endOfMonth);
    final voznjiGodina = await getBrojVoznjiZaPeriod(startOfYear, endOfYear);
    final voznjiProslaGodina = await getBrojVoznjiZaPeriod(startOfProslaGodina, endOfProslaGodina);

    // 📊 TROŠKOVI - PRAVILNO PO MESECIMA/GODINAMA

    // Tekući mesec - stvarni troškovi
    final troskoviTekuciMesec = await getUkupniTroskoviZaMesec(now.month, now.year);
    final troskoviPoTipu = await getTroskoviPoTipu(mesec: now.month, godina: now.year);

    // Nedelja - stvarni troškovi uneti ove nedelje (po created_at)
    final troskoviNedelja = await getUkupniTroskoviZaPeriod(startOfWeek, endOfWeek);

    // Ova godina - zbir svih meseci ove godine
    final troskoviOvaGodina = await getUkupniTroskoviZaGodinu(now.year);

    // Prošla godina - zbir svih meseci prošle godine
    final troskoviProslaGodinaIznos = await getUkupniTroskoviZaGodinu(proslaGodina);

    // Dani u mesecu do sad (za proporciju prikaza)
    // ❌ UKLONJENO: Proporcionalno računanje (zbunjivalo korinika)
    // Sada prikazujemo PUNE mesečne troškove
    // final danaUMesecu = endOfMonth.day;
    // final danaProsloDosad = now.day;
    // final proporcionalnaTroskoviMesec = troskoviTekuciMesec * (danaProsloDosad / danaUMesecu);

    return FinansijskiIzvestaj(
      // Nedelja
      prihodNedelja: prihodNedelja,
      troskoviNedelja: troskoviNedelja,
      netoNedelja: prihodNedelja - troskoviNedelja,
      voznjiNedelja: voznjiNedelja,
      // Mesec - KORISTI PUNE TROŠKOVE
      prihodMesec: prihodMesec,
      troskoviMesec: troskoviTekuciMesec,
      netoMesec: prihodMesec - troskoviTekuciMesec,
      voznjiMesec: voznjiMesec,
      // Godina
      prihodGodina: prihodGodina,
      troskoviGodina: troskoviOvaGodina,
      netoGodina: prihodGodina - troskoviOvaGodina,
      voznjiGodina: voznjiGodina,
      // Prošla godina - STVARNI troškovi iz baze
      prihodProslaGodina: prihodProslaGodina,
      troskoviProslaGodina: troskoviProslaGodinaIznos,
      netoProslaGodina: prihodProslaGodina - troskoviProslaGodinaIznos,
      voznjiProslaGodina: voznjiProslaGodina,
      proslaGodina: proslaGodina,
      // Detalji troškova
      troskoviPoTipu: troskoviPoTipu,
      ukupnoMesecniTroskovi: troskoviTekuciMesec,
      // Datumi
      startNedelja: startOfWeek,
      endNedelja: endOfWeek,
    );
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
    required this.startNedelja,
    required this.endNedelja,
  });

  /// Formatiran datum nedelje
  String get nedeljaPeriod {
    return '${startNedelja.day}.${startNedelja.month}. - ${endNedelja.day}.${endNedelja.month}.';
  }
}

/// Model za lične finansije (dug/ušteđevina)
class LicnaStavka {
  final String id;
  final String tip; // 'stednja' ili 'dug'
  final String naziv;
  final double iznos;

  LicnaStavka({
    required this.id,
    required this.tip,
    required this.naziv,
    required this.iznos,
  });

  factory LicnaStavka.fromJson(Map<String, dynamic> json) {
    return LicnaStavka(
      id: json['id'].toString(),
      tip: json['tip'] as String,
      naziv: json['naziv'] as String,
      iznos: (json['iznos'] is num)
          ? (json['iznos'] as num).toDouble()
          : double.tryParse(json['iznos']?.toString() ?? '0') ?? 0,
    );
  }
}
