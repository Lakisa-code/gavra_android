import 'package:flutter/material.dart';

import 'action_log.dart';

class PutovanjaIstorija {
  PutovanjaIstorija({
    required this.id,
    this.mesecniPutnikId,
    required this.tipPutnika,
    required this.datum,
    required this.vremePolaska,
    this.status = 'obavljeno',
    required this.putnikIme,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.obrisan = false,
    // Simplifikovana vozac_id struktura
    this.vozacId,
    this.createdBy,
    ActionLog? actionLog,
    this.napomene,
    this.rutaId,
    this.voziloId,
    this.adresaId,
    this.grad,
    this.brojMesta = 1, // 🆕 Broj rezervisanih mesta
  }) : actionLog = actionLog ?? ActionLog.empty();

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    return PutovanjaIstorija(
      id: map['id'] as String,
      mesecniPutnikId: map['mesecni_putnik_id'] as String?,
      tipPutnika: map['tip_putnika'] as String? ?? 'dnevni',
      datum: DateTime.parse(map['datum_putovanja'] as String),
      vremePolaska: map['vreme_polaska'] as String? ?? '',
      status: map['status'] as String? ?? 'obavljeno',
      putnikIme: map['putnik_ime'] as String? ?? '',
      cena: (map['cena'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      obrisan: map['obrisan'] as bool? ?? false,
      // Simplifikovana vozac_id struktura
      vozacId: map['vozac_id'] as String?,
      createdBy: map['created_by'] as String?,
      actionLog: ActionLog.fromString(map['action_log'] as String?),
      napomene: map['napomene'] as String?,
      rutaId: map['ruta_id'] as String?,
      voziloId: map['vozilo_id'] as String?,
      adresaId: map['adresa_id'] as String?,
      grad: map['grad'] as String?,
      brojMesta: (map['broj_mesta'] as int?) ?? 1, // 🆕 Broj rezervisanih mesta
    );
  }
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final String status;
  final String putnikIme;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool obrisan;

  // Simplifikovana vozac_id struktura
  final String? vozacId;
  final String? createdBy;
  final ActionLog actionLog;
  final String? napomene;
  final String? rutaId;
  final String? voziloId;
  final String? adresaId;
  final String? grad;
  final int brojMesta; // 🆕 Broj rezervisanih mesta (1, 2, 3...)

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum_putovanja': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'status': status,
      'putnik_ime': putnikIme,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      // Simplifikovana vozac_id struktura
      'vozac_id': vozacId,
      'created_by': createdBy,
      'action_log': actionLog.toJsonString(),
      'napomene': napomene,
      'ruta_id': rutaId,
      'vozilo_id': voziloId,
      'adresa_id': adresaId,
      'grad': grad,
      'broj_mesta': brojMesta, // 🆕 Broj rezervisanih mesta
    };
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  PutovanjaIstorija copyWith({
    String? id,
    String? mesecniPutnikId,
    String? tipPutnika,
    DateTime? datum,
    String? vremePolaska,
    String? status,
    String? putnikIme,
    double? cena,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? obrisan,
    // Nova polja iz baze
    String? vozacId,
    String? napomene,
    String? rutaId,
    String? voziloId,
    String? adresaId,
    String? grad,
  }) {
    return PutovanjaIstorija(
      id: id ?? this.id,
      mesecniPutnikId: mesecniPutnikId ?? this.mesecniPutnikId,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      datum: datum ?? this.datum,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      status: status ?? this.status,
      putnikIme: putnikIme ?? this.putnikIme,
      cena: cena ?? this.cena,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obrisan: obrisan ?? this.obrisan,
      // Nova polja iz baze
      vozacId: vozacId ?? this.vozacId,
      napomene: napomene ?? this.napomene,
      rutaId: rutaId ?? this.rutaId,
      voziloId: voziloId ?? this.voziloId,
      adresaId: adresaId ?? this.adresaId,
      grad: grad ?? this.grad,
    );
  }

  // Helper metodi za status - MODERNIZED status logic
  bool get jePokupljen => status == 'pokupljen';
  bool get jeOtkazao => status == 'otkazao_poziv' || status == 'otkazano';
  bool get jeNaCekanju => status == 'radi'; // Zamena za nije_se_pojavio
  bool get jePlacen => status == 'placeno';

  // Legacy compatibility getters (deprecated but kept for backward compatibility)
  @Deprecated('Use jePokupljen instead')
  bool get jePokupljenBelaCrkvaVrsac => jePokupljen;
  @Deprecated('Use jePokupljen instead')
  bool get jePokupljenVrsacBelaCrkva => jePokupljen;
  @Deprecated('Use jeOtkazao instead')
  bool get jeOtkazaoBelaCrkvaVrsac => jeOtkazao;
  @Deprecated('Use jeOtkazao instead')
  bool get jeOtkazaoVrsacBelaCrkva => jeOtkazao;
  @Deprecated('Use jeNaCekanju instead - nije_se_pojavio is removed')
  bool get nijeSePojavioBelaCrkvaVrsac => jeNaCekanju;
  @Deprecated('Use jeNaCekanju instead - nije_se_pojavio is removed')
  bool get nijeSePojavioVrsacBelaCrkva => jeNaCekanju;

  bool get jeRegistrovani => tipPutnika != 'dnevni'; // ✅ FIX: radnik/ucenik su registrovani
  bool get jeDnevni => tipPutnika == 'dnevni';

  // ==================== VALIDATION METHODS ====================

  /// Validni tipovi putnika
  static const List<String> validTipovi = ['radnik', 'ucenik', 'dnevni']; // ✅ FIX: stvarni tipovi

  /// Validni statusi putovanja
  static const List<String> validStatusi = [
    'obavljeno',
    'pokupljen',
    'otkazao_poziv',
    'otkazano',
    'placeno',
    'u_toku',
  ];

  /// Validira da li su osnovna polja popunjena
  bool isValid() {
    return id.isNotEmpty &&
        putnikIme.isNotEmpty &&
        vremePolaska.isNotEmpty &&
        validTipovi.contains(tipPutnika) &&
        validStatusi.contains(status);
  }

  /// Validira format vremena polaska (HH:MM)
  bool hasValidVremePolaska() {
    final timeRegex = RegExp(r'^\d{1,2}:\d{2}$');
    return timeRegex.hasMatch(vremePolaska);
  }

  /// Validira da li je datum u prošlosti ili budućnosti
  bool isDatumValid({bool allowFuture = true, bool allowPast = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final putovanjeDatum = DateTime(datum.year, datum.month, datum.day);

    if (!allowPast && putovanjeDatum.isBefore(today)) {
      return false;
    }
    if (!allowFuture && putovanjeDatum.isAfter(today)) {
      return false;
    }
    return true;
  }

  /// Validira vezu sa mesečnim putnikom
  bool hasValidMesecniPutnikLink() {
    if (jeRegistrovani) {
      return mesecniPutnikId != null && mesecniPutnikId!.isNotEmpty;
    }
    return true; // Dnevni putnici ne moraju imati mesecni_putnik_id
  }

  /// Kompletna validacija sa detaljnim rezultatom
  Map<String, String> validateFull() {
    final errors = <String, String>{};

    if (putnikIme.trim().isEmpty) {
      errors['putnikIme'] = 'Ime putnika je obavezno';
    }

    if (!validTipovi.contains(tipPutnika)) {
      errors['tipPutnika'] = 'Tip putnika mora biti: ${validTipovi.join(", ")}';
    }

    if (!validStatusi.contains(status)) {
      errors['status'] = 'Status mora biti: ${validStatusi.join(", ")}';
    }

    if (vremePolaska.isEmpty) {
      errors['vremePolaska'] = 'Vreme polaska je obavezno';
    } else if (!hasValidVremePolaska()) {
      errors['vremePolaska'] = 'Vreme polaska mora biti u formatu HH:MM';
    }

    if (!hasValidMesecniPutnikLink()) {
      errors['mesecniPutnikId'] = 'Mesečni putnici moraju imati ID mesečnog putnika';
    }

    if (!isDatumValid()) {
      errors['datum'] = 'Datum putovanja nije valjan';
    }

    if (cena < 0) {
      errors['cena'] = 'Cena ne može biti negativna';
    }

    return errors;
  }

  // ==================== UI HELPERS ====================

  /// Dobija boju na osnovu statusa
  Color getStatusColor() {
    switch (status) {
      case 'pokupljen':
        return Colors.green;
      case 'otkazao_poziv':
      case 'otkazano':
        return Colors.red;
      case 'radi':
        return Colors.blue; // Na čekanju
      case 'placeno':
        return Colors.blue;
      case 'u_toku':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Formatiran prikaz datuma
  String get formatiraniDatum {
    return '${datum.day.toString().padLeft(2, '0')}.${datum.month.toString().padLeft(2, '0')}.${datum.year}';
  }

  /// Kratki opis putovanja za UI
  String get shortDescription {
    final tipIcon = jeRegistrovani ? '📅' : '🎫';
    final statusIcon = jePokupljen
        ? '✅'
        : jeOtkazao
            ? '❌'
            : '⏳';
    return '$tipIcon $putnikIme ($vremePolaska) $statusIcon';
  }

  /// Detaljni opis za debug
  String get detailDescription {
    return 'PutovanjaIstorija(id: $id, ime: $putnikIme, datum: $formatiraniDatum, vreme: $vremePolaska, tip: $tipPutnika, status: $status, cena: $cena)';
  }

  @override
  String toString() {
    return 'PutovanjaIstorija(id: $id, ime: $putnikIme, datum: $datum, tip: $tipPutnika)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PutovanjaIstorija && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
