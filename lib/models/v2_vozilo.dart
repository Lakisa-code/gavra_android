/// Model za vozila (v2_vozila tabela)
class V2Vozilo {
  final String id;
  final String registarskiBroj;
  final String? marka;
  final String? model;
  final int? godinaProizvodnje;
  final String? brojSasije;
  final double? kilometraza;
  final DateTime? registracijaVaziDo;
  // Servisni podaci
  final DateTime? maliServisDatum;
  final double? maliServisKm;
  final DateTime? velikiServisDatum;
  final double? velikiServisKm;
  final DateTime? alternatorDatum;
  final double? alternatorKm;
  final DateTime? akumulatorDatum;
  final double? akumulatorKm;
  final DateTime? gumeDatum;
  final String? gumeOpis;
  final DateTime? gumePredneDatum;
  final String? gumePredneOpis;
  final double? gumePredneKm;
  final DateTime? gumeZadnjeDatum;
  final String? gumeZadnjeOpis;
  final double? gumeZadnjeKm;
  final DateTime? plociceDatum;
  final double? plociceKm;
  final DateTime? plocicePredneDatum;
  final double? plocicePredneKm;
  final DateTime? plociceZadnjeDatum;
  final double? plociceZadnjeKm;
  final DateTime? trapDatum;
  final double? trapKm;
  final String? radio;
  final String? napomena;

  V2Vozilo({
    required this.id,
    required this.registarskiBroj,
    this.marka,
    this.model,
    this.godinaProizvodnje,
    this.brojSasije,
    this.kilometraza,
    this.registracijaVaziDo,
    this.maliServisDatum,
    this.maliServisKm,
    this.velikiServisDatum,
    this.velikiServisKm,
    this.alternatorDatum,
    this.alternatorKm,
    this.akumulatorDatum,
    this.akumulatorKm,
    this.gumeDatum,
    this.gumeOpis,
    this.gumePredneDatum,
    this.gumePredneOpis,
    this.gumePredneKm,
    this.gumeZadnjeDatum,
    this.gumeZadnjeOpis,
    this.gumeZadnjeKm,
    this.plociceDatum,
    this.plociceKm,
    this.plocicePredneDatum,
    this.plocicePredneKm,
    this.plociceZadnjeDatum,
    this.plociceZadnjeKm,
    this.trapDatum,
    this.trapKm,
    this.radio,
    this.napomena,
  });

  factory V2Vozilo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v != null ? DateTime.tryParse(v as String) : null;
    double? parseNum(dynamic v) => v != null ? (v as num).toDouble() : null;

    return V2Vozilo(
      id: json['id'] as String? ?? '',
      registarskiBroj: json['registarski_broj'] as String? ?? '',
      marka: json['marka'] as String?,
      model: json['model'] as String?,
      godinaProizvodnje: json['godina_proizvodnje'] as int?,
      brojSasije: json['broj_sasije'] as String?,
      kilometraza: parseNum(json['kilometraza']),
      registracijaVaziDo: parseDate(json['registracija_vazi_do']),
      maliServisDatum: parseDate(json['mali_servis_datum']),
      maliServisKm: parseNum(json['mali_servis_km']),
      velikiServisDatum: parseDate(json['veliki_servis_datum']),
      velikiServisKm: parseNum(json['veliki_servis_km']),
      alternatorDatum: parseDate(json['alternator_datum']),
      alternatorKm: parseNum(json['alternator_km']),
      akumulatorDatum: parseDate(json['akumulator_datum']),
      akumulatorKm: parseNum(json['akumulator_km']),
      gumeDatum: parseDate(json['gume_datum']),
      gumeOpis: json['gume_opis'] as String?,
      gumePredneDatum: parseDate(json['gume_prednje_datum']),
      gumePredneOpis: json['gume_prednje_opis'] as String?,
      gumePredneKm: parseNum(json['gume_prednje_km']),
      gumeZadnjeDatum: parseDate(json['gume_zadnje_datum']),
      gumeZadnjeOpis: json['gume_zadnje_opis'] as String?,
      gumeZadnjeKm: parseNum(json['gume_zadnje_km']),
      plociceDatum: parseDate(json['plocice_datum']),
      plociceKm: parseNum(json['plocice_km']),
      plocicePredneDatum: parseDate(json['plocice_prednje_datum']),
      plocicePredneKm: parseNum(json['plocice_prednje_km']),
      plociceZadnjeDatum: parseDate(json['plocice_zadnje_datum']),
      plociceZadnjeKm: parseNum(json['plocice_zadnje_km']),
      trapDatum: parseDate(json['trap_datum']),
      trapKm: parseNum(json['trap_km']),
      radio: json['radio'] as String?,
      napomena: json['napomena'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registarski_broj': registarskiBroj,
      'marka': marka,
      'model': model,
      'godina_proizvodnje': godinaProizvodnje,
      'broj_sasije': brojSasije,
      'kilometraza': kilometraza,
      'registracija_vazi_do': registracijaVaziDo?.toIso8601String(),
      'mali_servis_datum': maliServisDatum?.toIso8601String(),
      'mali_servis_km': maliServisKm,
      'veliki_servis_datum': velikiServisDatum?.toIso8601String(),
      'veliki_servis_km': velikiServisKm,
      'alternator_datum': alternatorDatum?.toIso8601String(),
      'alternator_km': alternatorKm,
      'akumulator_datum': akumulatorDatum?.toIso8601String(),
      'akumulator_km': akumulatorKm,
      'gume_datum': gumeDatum?.toIso8601String(),
      'gume_opis': gumeOpis,
      'gume_prednje_datum': gumePredneDatum?.toIso8601String(),
      'gume_prednje_opis': gumePredneOpis,
      'gume_prednje_km': gumePredneKm,
      'gume_zadnje_datum': gumeZadnjeDatum?.toIso8601String(),
      'gume_zadnje_opis': gumeZadnjeOpis,
      'gume_zadnje_km': gumeZadnjeKm,
      'plocice_datum': plociceDatum?.toIso8601String(),
      'plocice_km': plociceKm,
      'plocice_prednje_datum': plocicePredneDatum?.toIso8601String(),
      'plocice_prednje_km': plocicePredneKm,
      'plocice_zadnje_datum': plociceZadnjeDatum?.toIso8601String(),
      'plocice_zadnje_km': plociceZadnjeKm,
      'trap_datum': trapDatum?.toIso8601String(),
      'trap_km': trapKm,
      'radio': radio,
      'napomena': napomena,
    };
  }
}
