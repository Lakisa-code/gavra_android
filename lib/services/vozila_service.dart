import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚗 VOZILA SERVICE - Kolska knjiga
/// Evidencija vozila i njihovo tehničko stanje
class VozilaService {
  static final _supabase = Supabase.instance.client;

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
