/// Model za finansijske troškove (v2_finansije_troskovi tabela)
class V2FinansijeTrosak {
  final String id;
  final String naziv;
  final String tip;
  final double iznos;
  final bool mesecno;
  final bool aktivan;
  final String? vozacId;
  final int? mesec;
  final int? godina;
  final DateTime? createdAt;

  V2FinansijeTrosak({
    required this.id,
    required this.naziv,
    required this.tip,
    required this.iznos,
    this.mesecno = false,
    this.aktivan = true,
    this.vozacId,
    this.mesec,
    this.godina,
    this.createdAt,
  });

  factory V2FinansijeTrosak.fromJson(Map<String, dynamic> json) {
    return V2FinansijeTrosak(
      id: json['id'] as String? ?? '',
      naziv: json['naziv'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0.0,
      mesecno: json['mesecno'] as bool? ?? false,
      aktivan: json['aktivan'] as bool? ?? true,
      vozacId: json['vozac_id'] as String?,
      mesec: json['mesec'] as int?,
      godina: json['godina'] as int?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'naziv': naziv,
      'tip': tip,
      'iznos': iznos,
      'mesecno': mesecno,
      'aktivan': aktivan,
      'vozac_id': vozacId,
      'mesec': mesec,
      'godina': godina,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
