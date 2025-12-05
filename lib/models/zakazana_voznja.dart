/// ⚔️ BINARYBITCH: Model za zakazane vožnje
/// Self-booking sistem za mesečne putnike

class ZakazanaVoznja {
  final String id;
  final String putnikId;
  final DateTime datum;
  final String? smena; // 'prva', 'druga', 'treca', 'slobodan', 'custom'
  final String? vremeBc;
  final String? vremeVs;
  final String status; // 'zakazano', 'otkazano', 'zavrseno'
  final String? napomena;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields (from view)
  final String? putnikIme;
  final String? tip;
  final String? brojTelefona;

  ZakazanaVoznja({
    required this.id,
    required this.putnikId,
    required this.datum,
    this.smena,
    this.vremeBc,
    this.vremeVs,
    this.status = 'zakazano',
    this.napomena,
    required this.createdAt,
    required this.updatedAt,
    this.putnikIme,
    this.tip,
    this.brojTelefona,
  });

  factory ZakazanaVoznja.fromMap(Map<String, dynamic> map) {
    return ZakazanaVoznja(
      id: map['id'] as String? ?? '',
      putnikId: map['putnik_id'] as String? ?? '',
      datum: DateTime.parse(map['datum'] as String),
      smena: map['smena'] as String?,
      vremeBc: map['vreme_bc'] as String?,
      vremeVs: map['vreme_vs'] as String?,
      status: map['status'] as String? ?? 'zakazano',
      napomena: map['napomena'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      putnikIme: map['putnik_ime'] as String?,
      tip: map['tip'] as String?,
      brojTelefona: map['broj_telefona'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'putnik_id': putnikId,
      'datum': datum.toIso8601String().split('T')[0],
      'smena': smena,
      'vreme_bc': vremeBc,
      'vreme_vs': vremeVs,
      'status': status,
      'napomena': napomena,
    };
  }

  ZakazanaVoznja copyWith({
    String? id,
    String? putnikId,
    DateTime? datum,
    String? smena,
    String? vremeBc,
    String? vremeVs,
    String? status,
    String? napomena,
  }) {
    return ZakazanaVoznja(
      id: id ?? this.id,
      putnikId: putnikId ?? this.putnikId,
      datum: datum ?? this.datum,
      smena: smena ?? this.smena,
      vremeBc: vremeBc ?? this.vremeBc,
      vremeVs: vremeVs ?? this.vremeVs,
      status: status ?? this.status,
      napomena: napomena ?? this.napomena,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Vremenski opsezi za smene
  static Map<String, Map<String, String>> smeneVremena = {
    'prva': {'bc': '06:00', 'vs': '14:00'},
    'druga': {'bc': '14:00', 'vs': '22:00'},
    'treca': {'bc': '22:00', 'vs': '06:00'},
    'slobodan': {'bc': '', 'vs': ''},
  };

  /// Da li je slobodan dan
  bool get jeSlobodan => smena == 'slobodan' || (vremeBc == null && vremeVs == null);

  /// Formatiran prikaz smene
  String get smenaPrikaz {
    switch (smena) {
      case 'prva':
        return '1. smena (06-14h)';
      case 'druga':
        return '2. smena (14-22h)';
      case 'treca':
        return '3. smena (22-06h)';
      case 'slobodan':
        return 'Slobodan';
      case 'custom':
        return 'Po izboru';
      default:
        return smena ?? 'Nepoznato';
    }
  }

  @override
  String toString() {
    return 'ZakazanaVoznja(datum: $datum, smena: $smena, status: $status)';
  }
}
