/// Model za lokaciju vozača (v2_vozac_lokacije tabela)
class V2VozacLokacija {
  final String id;
  final String vozacId;
  final double lat;
  final double lng;
  final String? grad;
  final String? vremePolaska;
  final String? smer;
  final Map<String, dynamic>? putniciEta;
  final bool aktivan;
  final DateTime? updatedAt;

  V2VozacLokacija({
    required this.id,
    required this.vozacId,
    required this.lat,
    required this.lng,
    this.grad,
    this.vremePolaska,
    this.smer,
    this.putniciEta,
    this.aktivan = false,
    this.updatedAt,
  });

  factory V2VozacLokacija.fromJson(Map<String, dynamic> json) {
    return V2VozacLokacija(
      id: json['id'] as String? ?? '',
      vozacId: json['vozac_id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      grad: json['grad'] as String?,
      vremePolaska: json['vreme_polaska'] as String?,
      smer: json['smer'] as String?,
      putniciEta: json['putnici_eta'] as Map<String, dynamic>?,
      aktivan: json['aktivan'] as bool? ?? false,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vozac_id': vozacId,
      'lat': lat,
      'lng': lng,
      'grad': grad,
      'vreme_polaska': vremePolaska,
      'smer': smer,
      'putnici_eta': putniciEta,
      'aktivan': aktivan,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
