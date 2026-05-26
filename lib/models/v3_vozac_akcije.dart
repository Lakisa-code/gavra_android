import 'package:cloud_firestore/cloud_firestore.dart';

class V3VozacAkcija {
  final String id;
  final String vozacId;
  final String vozacIme;
  final DateTime datum;
  final String tipAkcije; // 'pokupio' ili 'naplata'
  final String putnikId;
  final String putnikIme;
  final double iznos; // samo za naplate
  final DateTime? createdAt;
  final String? createdBy;

  const V3VozacAkcija({
    required this.id,
    required this.vozacId,
    required this.vozacIme,
    required this.datum,
    required this.tipAkcije,
    required this.putnikId,
    required this.putnikIme,
    this.iznos = 0.0,
    this.createdAt,
    this.createdBy,
  });

  factory V3VozacAkcija.fromJson(Map<String, dynamic> json) {
    return V3VozacAkcija(
      id: json['id'] as String? ?? '',
      vozacId: json['vozac_id'] as String? ?? '',
      vozacIme: json['vozac_ime'] as String? ?? '',
      datum: DateTime.parse(json['datum'] as String? ?? DateTime.now().toIso8601String()),
      tipAkcije: json['tip_akcije'] as String? ?? '',
      putnikId: json['putnik_id'] as String? ?? '',
      putnikIme: json['putnik_ime'] as String? ?? '',
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vozac_id': vozacId,
      'vozac_ime': vozacIme,
      'datum': datum.toIso8601String(),
      'tip_akcije': tipAkcije,
      'putnik_id': putnikId,
      'putnik_ime': putnikIme,
      'iznos': iznos,
      'created_at': createdAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  V3VozacAkcija copyWith({
    String? id,
    String? vozacId,
    String? vozacIme,
    DateTime? datum,
    String? tipAkcije,
    String? putnikId,
    String? putnikIme,
    double? iznos,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return V3VozacAkcija(
      id: id ?? this.id,
      vozacId: vozacId ?? this.vozacId,
      vozacIme: vozacIme ?? this.vozacIme,
      datum: datum ?? this.datum,
      tipAkcije: tipAkcije ?? this.tipAkcije,
      putnikId: putnikId ?? this.putnikId,
      putnikIme: putnikIme ?? this.putnikIme,
      iznos: iznos ?? this.iznos,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is V3VozacAkcija &&
        other.id == id &&
        other.vozacId == vozacId &&
        other.vozacIme == vozacIme &&
        other.datum == datum &&
        other.tipAkcije == tipAkcije &&
        other.putnikId == putnikId &&
        other.putnikIme == putnikIme &&
        other.iznos == iznos &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      vozacId,
      vozacIme,
      datum,
      tipAkcije,
      putnikId,
      putnikIme,
      iznos,
      createdAt,
      createdBy,
    );
  }

  @override
  String toString() {
    return 'V3VozacAkcija(id: $id, vozacId: $vozacId, datum: $datum, tipAkcije: $tipAkcije, putnikIme: $putnikIme, iznos: $iznos)';
  }
}
