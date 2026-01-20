import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 🚗 VOZILA SERVICE - Kolska knjiga
/// Evidencija vozila i njihovo tehničko stanje
class VozilaService {
  static SupabaseClient get _supabase => supabase;

  /// Dohvati sva vozila
  static Future<List<Vozilo>> getVozila() async {
    try {
      final response = await _supabase.from('vozila').select().order('registarski_broj');
      return (response as List).map((row) => Vozilo.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Dohvati jedno vozilo
  static Future<Vozilo?> getVozilo(String id) async {
    try {
      final response = await _supabase.from('vozila').select().eq('id', id).single();
      return Vozilo.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Ažuriraj kolsku knjigu vozila
  static Future<bool> updateKolskaKnjiga(String id, Map<String, dynamic> podaci) async {
    try {
      await _supabase.from('vozila').update(podaci).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dohvati vozila kojima ističe registracija (u narednih X dana)
  static Future<List<Vozilo>> getVozilaIstekRegistracije({int dana = 30}) async {
    try {
      final now = DateTime.now();
      final zaXDana = now.add(Duration(days: dana));

      final response = await _supabase
          .from('vozila')
          .select()
          .not('registracija_vazi_do', 'is', null)
          .lte('registracija_vazi_do', zaXDana.toIso8601String().split('T')[0])
          .order('registracija_vazi_do');

      return (response as List).map((row) => Vozilo.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ažuriraj broj mesta vozila
  static Future<bool> updateBrojMesta(String id, int brojMesta) async {
    try {
      await _supabase.from('vozila').update({'broj_mesta': brojMesta}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ISTORIJA SERVISA ====================

  /// Dodaj zapis u istoriju vozila
  static Future<bool> addIstorijuServisa({
    required String voziloId,
    required String tip,
    DateTime? datum,
    int? km,
    String? opis,
    double? cena,
    String? pozicija,
  }) async {
    try {
      await _supabase.from('vozila_istorija').insert({
        'vozilo_id': voziloId,
        'tip': tip,
        'datum': datum?.toIso8601String().split('T')[0],
        'km': km,
        'opis': opis,
        'cena': cena,
        'pozicija': pozicija,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dohvati istoriju servisa za vozilo
  static Future<List<IstorijaSevisa>> getIstorijuServisa(String voziloId, {String? tip}) async {
    try {
      var query = _supabase.from('vozila_istorija').select().eq('vozilo_id', voziloId);

      if (tip != null) {
        query = query.eq('tip', tip);
      }

      final response = await query.order('datum', ascending: false);
      return (response as List).map((row) => IstorijaSevisa.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obriši zapis iz istorije
  static Future<bool> deleteIstorijuServisa(String id) async {
    try {
      await _supabase.from('vozila_istorija').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Model za istoriju servisa
class IstorijaSevisa {
  final String id;
  final String voziloId;
  final String tip;
  final DateTime? datum;
  final int? km;
  final String? opis;
  final double? cena;
  final String? pozicija;
  final DateTime createdAt;

  IstorijaSevisa({
    required this.id,
    required this.voziloId,
    required this.tip,
    this.datum,
    this.km,
    this.opis,
    this.cena,
    this.pozicija,
    required this.createdAt,
  });

  factory IstorijaSevisa.fromJson(Map<String, dynamic> json) {
    return IstorijaSevisa(
      id: json['id']?.toString() ?? '',
      voziloId: json['vozilo_id']?.toString() ?? '',
      tip: json['tip'] as String? ?? '',
      datum: json['datum'] != null ? DateTime.tryParse(json['datum'].toString()) : null,
      km: json['km'] as int?,
      opis: json['opis'] as String?,
      cena: json['cena'] != null ? (json['cena'] as num).toDouble() : null,
      pozicija: json['pozicija'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  /// Ikona za tip
  String get ikona {
    switch (tip) {
      case 'mali_servis':
        return '🔧';
      case 'veliki_servis':
        return '🛠️';
      case 'alternator':
        return '⚡';
      case 'gume_prednje':
        return '🛞';
      case 'gume_zadnje':
        return '🛞';
      case 'akumulator':
        return '🔋';
      case 'plocice':
        return '🛑';
      case 'trap':
        return '🔩';
      case 'registracija':
        return '📋';
      default:
        return '📝';
    }
  }

  /// Naziv tipa
  String get tipNaziv {
    switch (tip) {
      case 'mali_servis':
        return 'Mali servis';
      case 'veliki_servis':
        return 'Veliki servis';
      case 'alternator':
        return 'Alternator';
      case 'gume_prednje':
        return 'Gume prednje';
      case 'gume_zadnje':
        return 'Gume zadnje';
      case 'akumulator':
        return 'Akumulator';
      case 'plocice':
        return 'Pločice';
      case 'trap':
        return 'Trap';
      case 'registracija':
        return 'Registracija';
      default:
        return 'Ostalo';
    }
  }
}

/// Model za vozilo - Kolska knjiga
class Vozilo {
  final String id;
  final String registarskiBroj;
  final String? marka;
  final String? model;
  final int? godinaProizvodnje;
  final int? brojMesta;
  final String? naziv;

  // Kolska knjiga
  final String? brojSasije;
  final DateTime? registracijaVaziDo;
  final DateTime? maliServisDatum;
  final int? maliServisKm;
  final DateTime? velikiServisDatum;
  final int? velikiServisKm;
  final DateTime? alternatorDatum;
  final int? alternatorKm;
  final DateTime? gumeDatum;
  final String? gumeOpis;
  final DateTime? gumePrednjeDatum;
  final String? gumePrednjeOpis;
  final int? gumePrednjeKm;
  final DateTime? gumeZadnjeDatum;
  final String? gumeZadnjeOpis;
  final int? gumeZadnjeKm;
  final String? napomena;
  // Nova polja
  final DateTime? akumulatorDatum;
  final int? akumulatorKm;
  final DateTime? plociceDatum;
  final int? plociceKm;
  final DateTime? trapDatum;
  final int? trapKm;
  final String? radio;

  Vozilo({
    required this.id,
    required this.registarskiBroj,
    this.marka,
    this.model,
    this.godinaProizvodnje,
    this.brojMesta,
    this.naziv,
    this.brojSasije,
    this.registracijaVaziDo,
    this.maliServisDatum,
    this.maliServisKm,
    this.velikiServisDatum,
    this.velikiServisKm,
    this.alternatorDatum,
    this.alternatorKm,
    this.gumeDatum,
    this.gumeOpis,
    this.gumePrednjeDatum,
    this.gumePrednjeOpis,
    this.gumePrednjeKm,
    this.gumeZadnjeDatum,
    this.gumeZadnjeOpis,
    this.gumeZadnjeKm,
    this.napomena,
    this.akumulatorDatum,
    this.akumulatorKm,
    this.plociceDatum,
    this.plociceKm,
    this.trapDatum,
    this.trapKm,
    this.radio,
  });

  factory Vozilo.fromJson(Map<String, dynamic> json) {
    return Vozilo(
      id: json['id']?.toString() ?? '',
      registarskiBroj: json['registarski_broj'] as String? ?? '',
      marka: json['marka'] as String?,
      model: json['model'] as String?,
      godinaProizvodnje: json['godina_proizvodnje'] as int?,
      brojMesta: json['broj_mesta'] as int?,
      naziv: json['naziv'] as String?,
      brojSasije: json['broj_sasije'] as String?,
      registracijaVaziDo: _parseDate(json['registracija_vazi_do']),
      maliServisDatum: _parseDate(json['mali_servis_datum']),
      maliServisKm: json['mali_servis_km'] as int?,
      velikiServisDatum: _parseDate(json['veliki_servis_datum']),
      velikiServisKm: json['veliki_servis_km'] as int?,
      alternatorDatum: _parseDate(json['alternator_datum']),
      alternatorKm: json['alternator_km'] as int?,
      gumeDatum: _parseDate(json['gume_datum']),
      gumeOpis: json['gume_opis'] as String?,
      gumePrednjeDatum: _parseDate(json['gume_prednje_datum']),
      gumePrednjeOpis: json['gume_prednje_opis'] as String?,
      gumePrednjeKm: json['gume_prednje_km'] as int?,
      gumeZadnjeDatum: _parseDate(json['gume_zadnje_datum']),
      gumeZadnjeOpis: json['gume_zadnje_opis'] as String?,
      gumeZadnjeKm: json['gume_zadnje_km'] as int?,
      akumulatorDatum: _parseDate(json['akumulator_datum']),
      akumulatorKm: json['akumulator_km'] as int?,
      plociceDatum: _parseDate(json['plocice_datum']),
      plociceKm: json['plocice_km'] as int?,
      trapDatum: _parseDate(json['trap_datum']),
      trapKm: json['trap_km'] as int?,
      radio: json['radio'] as String?,
      napomena: json['napomena'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Prikaži naziv
  String get displayNaziv {
    if (naziv != null && naziv!.isNotEmpty) return naziv!;
    if (marka != null && model != null) {
      return '$marka $model${brojMesta != null ? ' ($brojMesta mesta)' : ''}';
    }
    return registarskiBroj;
  }

  /// Da li registracija ističe uskoro (30 dana)
  bool get registracijaIstice {
    if (registracijaVaziDo == null) return false;
    final danaDoIsteka = registracijaVaziDo!.difference(DateTime.now()).inDays;
    return danaDoIsteka <= 30;
  }

  /// Da li je registracija istekla
  bool get registracijaIstekla {
    if (registracijaVaziDo == null) return false;
    return registracijaVaziDo!.isBefore(DateTime.now());
  }

  /// Koliko dana do isteka registracije
  int? get danaDoIstekaRegistracije {
    if (registracijaVaziDo == null) return null;
    return registracijaVaziDo!.difference(DateTime.now()).inDays;
  }

  /// Formatiran datum
  static String formatDatum(DateTime? datum) {
    if (datum == null) return '-';
    return '${datum.day}.${datum.month}.${datum.year}';
  }
}
