import 'package:flutter/material.dart';

class PutovanjaIstorija {
  PutovanjaIstorija({
    required this.id,
    this.mesecniPutnikId,
    required this.tipPutnika,
    required this.datum,
    required this.vremePolaska,
    this.vremeAkcije, // OPCIONO
    required this.adresaPolaska,
    this.status = 'nije_se_pojavio', // DEFAULT vrednost
    required this.putnikIme,
    this.brojTelefona,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
    // NOVA POLJA
    this.dan,
    this.grad,
    this.obrisan = false,
    this.pokupljen = false,
    this.vozac,
    this.vremePlacanja,
    this.vremePokupljenja,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    return PutovanjaIstorija(
      id: map['id'] as String,
      mesecniPutnikId: map['mesecni_putnik_id'] as String?,
      tipPutnika: map['tip_putnika'] as String,
      datum: DateTime.parse(map['datum_putovanja'] as String),
      vremePolaska: map['vreme_polaska'] as String,
      vremeAkcije: map['vreme_akcije'] != null
          ? DateTime.parse(map['vreme_akcije'] as String)
          : null, // FIXED: Consistent mapping to vreme_akcije
      adresaPolaska: map['adresa_polaska'] as String,
      status: map['status'] as String? ??
          'nije_se_pojavio', // KORISTI status kolonu
      putnikIme: map['putnik_ime'] as String,
      brojTelefona: map['broj_telefona'] as String?,
      cena: (map['cena'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      // NOVA POLJA
      dan: map['dan'] as String?,
      grad: map['grad'] as String?,
      obrisan: map['obrisan'] as bool? ?? false,
      pokupljen: map['pokupljen'] as bool? ?? false,
      vozac: map['vozac'] as String?,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null,
    );
  }
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final DateTime? vremeAkcije; // OPCIONO - možda se mapira na vreme_pokupljenja
  final String adresaPolaska;
  final String status; // UNIFIED status column - replaces deprecated columns
  final String putnikIme;
  final String? brojTelefona;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;

  // NOVA POLJA koja postoje u bazi
  final String? dan;
  final String? grad;
  final bool obrisan;
  final bool pokupljen;
  final String? vozac;
  final DateTime? vremePlacanja;
  final DateTime? vremePokupljenja;

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum_putovanja': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'vreme_akcije':
          vremeAkcije?.toIso8601String(), // FIXED: Added missing mapping
      'adresa_polaska': adresaPolaska,
      'status':
          status, // KORISTI status umesto status_bela_crkva_vrsac/status_vrsac_bela_crkva
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // NOVA POLJA
      'dan': dan,
      'grad': grad,
      'obrisan': obrisan,
      'pokupljen': pokupljen,
      'vozac': vozac,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
    };
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  PutovanjaIstorija copyWith({
    String? id,
    String? mesecniPutnikId,
    String? tipPutnika,
    DateTime? datum,
    String? vremePolaska,
    DateTime? vremeAkcije,
    String? adresaPolaska,
    String? status,
    String? putnikIme,
    String? brojTelefona,
    double? cena,
    DateTime? createdAt,
    DateTime? updatedAt,
    // NOVA POLJA
    String? dan,
    String? grad,
    bool? obrisan,
    bool? pokupljen,
    String? vozac,
    DateTime? vremePlacanja,
    DateTime? vremePokupljenja,
  }) {
    return PutovanjaIstorija(
      id: id ?? this.id,
      mesecniPutnikId: mesecniPutnikId ?? this.mesecniPutnikId,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      datum: datum ?? this.datum,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      vremeAkcije: vremeAkcije ?? this.vremeAkcije,
      adresaPolaska: adresaPolaska ?? this.adresaPolaska,
      status: status ?? this.status,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      cena: cena ?? this.cena,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // NOVA POLJA
      dan: dan ?? this.dan,
      grad: grad ?? this.grad,
      obrisan: obrisan ?? this.obrisan,
      pokupljen: pokupljen ?? this.pokupljen,
      vozac: vozac ?? this.vozac,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
    );
  }

  // Helper metodi za status - MODERNIZED status logic
  bool get jePokupljen => status == 'pokupljen' || pokupljen;
  bool get jeOtkazao => status == 'otkazao_poziv' || status == 'otkazano';
  bool get nijeSePojaveo => status == 'nije_se_pojavio';
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
  @Deprecated('Use nijeSePojaveo instead')
  bool get nijeSePojavioBelaCrkvaVrsac => nijeSePojaveo;
  @Deprecated('Use nijeSePojaveo instead')
  bool get nijeSePojavioVrsacBelaCrkva => nijeSePojaveo;

  bool get jeMesecni => tipPutnika == 'mesecni';
  bool get jeDnevni => tipPutnika == 'dnevni';

  // ==================== VALIDATION METHODS ====================

  /// Validni tipovi putnika
  static const List<String> validTipovi = ['mesecni', 'dnevni'];

  /// Validni statusi putovanja
  static const List<String> validStatusi = [
    'nije_se_pojavio',
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
        adresaPolaska.isNotEmpty &&
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
    if (jeMesecni) {
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

    if (adresaPolaska.trim().isEmpty) {
      errors['adresaPolaska'] = 'Adresa polaska je obavezna';
    }

    if (!hasValidMesecniPutnikLink()) {
      errors['mesecniPutnikId'] =
          'Mesečni putnici moraju imati ID mesečnog putnika';
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
      case 'nije_se_pojavio':
        return Colors.orange;
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
    final tipIcon = jeMesecni ? '📅' : '🎫';
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





