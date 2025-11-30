import 'package:uuid/uuid.dart';

/// Status dnevnih checkin-a - sinhronizovan sa database CHECK constraint
enum DailyCheckinStatus {
  otvoren,
  zavrsen,
  revidiran,
  zakljucan,
}

extension DailyCheckinStatusExtension on DailyCheckinStatus {
  String get value {
    switch (this) {
      case DailyCheckinStatus.otvoren:
        return 'otvoren';
      case DailyCheckinStatus.zavrsen:
        return 'završen';
      case DailyCheckinStatus.revidiran:
        return 'revidiran';
      case DailyCheckinStatus.zakljucan:
        return 'zaključan';
    }
  }

  static DailyCheckinStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'otvoren':
        return DailyCheckinStatus.otvoren;
      case 'završen':
        return DailyCheckinStatus.zavrsen;
      case 'revidiran':
        return DailyCheckinStatus.revidiran;
      case 'zaključan':
        return DailyCheckinStatus.zakljucan;
      default:
        return DailyCheckinStatus.otvoren; // default kao u bazi
    }
  }
}

/// Model za dnevne checkin-e vozača
class DailyCheckin {
  DailyCheckin({
    String? id,
    required this.vozac,
    required this.datum,
    this.sitanNovac = 0.0,
    this.dnevniPazari = 0.0,
    double? ukupno,
    DateTime? checkinVreme,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.obrisan = false,
    this.deletedAt,
    this.status = DailyCheckinStatus.otvoren,
  })  : id = id ?? const Uuid().v4(),
        ukupno = ukupno ?? (sitanNovac + dnevniPazari), // auto-calculate ukupno
        checkinVreme = checkinVreme ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DailyCheckin.fromMap(Map<String, dynamic> map) {
    return DailyCheckin(
      id: map['id'] as String,
      vozac: map['vozac'] as String,
      datum: DateTime.parse(map['datum'] as String),
      sitanNovac: (map['sitan_novac'] as num?)?.toDouble() ?? 0.0,
      dnevniPazari: (map['dnevni_pazari'] as num?)?.toDouble() ?? 0.0,
      ukupno: (map['ukupno'] as num?)?.toDouble() ?? 0.0,
      checkinVreme: map['checkin_vreme'] != null ? DateTime.parse(map['checkin_vreme'] as String) : DateTime.now(),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      obrisan: map['obrisan'] as bool? ?? false,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      status: DailyCheckinStatusExtension.fromString(
        map['status'] as String? ?? 'otvoren',
      ),
    );
  }

  final String id;
  final String vozac;
  final DateTime datum;
  final double sitanNovac;
  final double dnevniPazari;
  final double ukupno;
  final DateTime checkinVreme;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool obrisan;
  final DateTime? deletedAt;
  final DailyCheckinStatus status;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vozac': vozac,
      'datum': datum.toIso8601String().split('T')[0], // only date part
      'sitan_novac': sitanNovac,
      'dnevni_pazari': dnevniPazari,
      'ukupno': ukupno,
      'checkin_vreme': checkinVreme.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      'deleted_at': deletedAt?.toIso8601String(),
      'status': status.value,
    };
  }

  // ✅ VALIDATION METHODS

  /// Validira da li su sva obavezna polja popunjena
  bool get isValid {
    return vozac.trim().isNotEmpty &&
        sitanNovac >= 0 &&
        dnevniPazari >= 0 &&
        ukupno == (sitanNovac + dnevniPazari); // ukupno mora biti zbir
  }

  /// Proverava da li je checkin aktivan (nije obrisan)
  bool get isActive => !obrisan;

  /// Proverava da li je checkin obrisan
  bool get isDeleted => obrisan;

  /// Proverava da li je checkin otvoren za izmene
  bool get isEditable => status == DailyCheckinStatus.otvoren && !obrisan;

  /// Proverava da li je checkin završen
  bool get isCompleted => status == DailyCheckinStatus.zavrsen;

  /// Proverava da li je checkin zaključan (ne može se menjati)
  bool get isLocked => status == DailyCheckinStatus.zakljucan;

  /// Proverava da li je checkin revidiran
  bool get isReviewed => status == DailyCheckinStatus.revidiran;

  /// Vraća ljudski čitljiv status
  String get statusLabel {
    switch (status) {
      case DailyCheckinStatus.otvoren:
        return 'Otvoren';
      case DailyCheckinStatus.zavrsen:
        return 'Završen';
      case DailyCheckinStatus.revidiran:
        return 'Revidiran';
      case DailyCheckinStatus.zakljucan:
        return 'Zaključan';
    }
  }

  /// Formatira ukupan iznos za prikaz
  String get formattedUkupno {
    return '${ukupno.toStringAsFixed(2)} RSD';
  }

  /// Formatira sitan novac za prikaz
  String get formattedSitanNovac {
    return '${sitanNovac.toStringAsFixed(2)} RSD';
  }

  /// Formatira dnevne pazare za prikaz
  String get formattedDnevniPazari {
    return '${dnevniPazari.toStringAsFixed(2)} RSD';
  }

  /// Formatira datum za prikaz
  String get formattedDatum {
    return '${datum.day}.${datum.month}.${datum.year}.';
  }

  /// Da li je checkin iz danas
  bool get isToday {
    final today = DateTime.now();
    return datum.year == today.year && datum.month == today.month && datum.day == today.day;
  }

  /// Da li je checkin iz tekuće nedelje
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return datum.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        datum.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Da li je checkin iz tekućeg meseca
  bool get isThisMonth {
    final now = DateTime.now();
    return datum.year == now.year && datum.month == now.month;
  }

  // ✅ COPY AND MODIFICATION METHODS

  /// Kopira objekat sa izmenjenim vrednostima
  DailyCheckin copyWith({
    String? id,
    String? vozac,
    DateTime? datum,
    double? sitanNovac,
    double? dnevniPazari,
    double? ukupno,
    DateTime? checkinVreme,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? obrisan,
    DateTime? deletedAt,
    DailyCheckinStatus? status,
  }) {
    final newSitanNovac = sitanNovac ?? this.sitanNovac;
    final newDnevniPazari = dnevniPazari ?? this.dnevniPazari;

    return DailyCheckin(
      id: id ?? this.id,
      vozac: vozac ?? this.vozac,
      datum: datum ?? this.datum,
      sitanNovac: newSitanNovac,
      dnevniPazari: newDnevniPazari,
      ukupno: ukupno ?? (newSitanNovac + newDnevniPazari), // auto-recalculate
      checkinVreme: checkinVreme ?? this.checkinVreme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // always update timestamp
      obrisan: obrisan ?? this.obrisan,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
    );
  }

  /// Soft delete checkin-a
  DailyCheckin markAsDeleted() {
    return copyWith(
      obrisan: true,
      deletedAt: DateTime.now(),
    );
  }

  /// Restore obrisanog checkin-a
  DailyCheckin restore() {
    return copyWith(
      obrisan: false,
    );
  }

  /// Završava checkin (status = završen)
  DailyCheckin complete() {
    return copyWith(status: DailyCheckinStatus.zavrsen);
  }

  /// Zaključava checkin (status = zaključan)
  DailyCheckin lock() {
    return copyWith(status: DailyCheckinStatus.zakljucan);
  }

  /// Označava kao revidiran (status = revidiran)
  DailyCheckin markAsReviewed() {
    return copyWith(status: DailyCheckinStatus.revidiran);
  }

  /// Vraća u otvoren status
  DailyCheckin reopen() {
    return copyWith(status: DailyCheckinStatus.otvoren);
  }

  /// Ažurira novčane iznose
  DailyCheckin updateAmounts({
    double? sitanNovac,
    double? dnevniPazari,
  }) {
    return copyWith(
      sitanNovac: sitanNovac,
      dnevniPazari: dnevniPazari,
      // ukupno će biti auto-kalkulisan u copyWith
    );
  }

  /// toString za debugging
  @override
  String toString() {
    return 'DailyCheckin(id: $id, vozac: $vozac, datum: ${formattedDatum}, '
        'ukupno: ${formattedUkupno}, status: ${status.value})';
  }

  /// Jednakost dva objekta
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyCheckin && other.id == id && other.vozac == vozac && other.datum == datum;
  }

  @override
  int get hashCode {
    return id.hashCode ^ vozac.hashCode ^ datum.hashCode;
  }

  // ✅ STATIC HELPER METHODS

  /// Kreira novi checkin za danas
  static DailyCheckin forToday({
    required String vozac,
    double sitanNovac = 0.0,
    double dnevniPazari = 0.0,
  }) {
    return DailyCheckin(
      vozac: vozac,
      datum: DateTime.now(),
      sitanNovac: sitanNovac,
      dnevniPazari: dnevniPazari,
    );
  }

  /// Kreira novi checkin za određeni datum
  static DailyCheckin forDate({
    required String vozac,
    required DateTime datum,
    double sitanNovac = 0.0,
    double dnevniPazari = 0.0,
  }) {
    return DailyCheckin(
      vozac: vozac,
      datum: datum,
      sitanNovac: sitanNovac,
      dnevniPazari: dnevniPazari,
    );
  }
}
