/// Model za podatke o računu klijenta (v2_racuni tabela)
class V2Racun {
  final String id;
  final String putnikId;
  final String putnikTabela;
  final String? firmaNaziv;
  final String? firmaPib;
  final String? firmaMb;
  final String? firmaZiro;
  final String? firmaAdresa;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2Racun({
    required this.id,
    required this.putnikId,
    required this.putnikTabela,
    this.firmaNaziv,
    this.firmaPib,
    this.firmaMb,
    this.firmaZiro,
    this.firmaAdresa,
    this.createdAt,
    this.updatedAt,
  });

  factory V2Racun.fromJson(Map<String, dynamic> json) {
    return V2Racun(
      id: json['id'] as String? ?? '',
      putnikId: json['putnik_id'] as String? ?? '',
      putnikTabela: json['putnik_tabela'] as String? ?? '',
      firmaNaziv: json['firma_naziv'] as String?,
      firmaPib: json['firma_pib'] as String?,
      firmaMb: json['firma_mb'] as String?,
      firmaZiro: json['firma_ziro'] as String?,
      firmaAdresa: json['firma_adresa'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'putnik_id': putnikId,
      'putnik_tabela': putnikTabela,
      'firma_naziv': firmaNaziv,
      'firma_pib': firmaPib,
      'firma_mb': firmaMb,
      'firma_ziro': firmaZiro,
      'firma_adresa': firmaAdresa,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
