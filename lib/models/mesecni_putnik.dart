import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/vozac_mapping_service.dart';
import '../utils/mesecni_helpers.dart';

/// Model za mesečne putnike - ažurirana verzija
class MesecniPutnik {
  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    this.brojTelefona,
    this.brojTelefonaOca,
    this.brojTelefonaMajke,
    required this.tip,
    this.tipSkole,
    required this.polasciPoDanu,
    this.adresaBelaCrkva,
    this.adresaVrsac,
    this.radniDani = 'pon,uto,sre,cet,pet',
    required this.datumPocetkaMeseca,
    required this.datumKrajaMeseca,
    required this.createdAt,
    required this.updatedAt,
    this.aktivan = true,
    this.status = 'aktivan',
    this.ukupnaCenaMeseca = 0.0,
    this.cena,
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.poslednjePutovanje,
    this.obrisan = false,
    this.vremePlacanja,
    this.placeniMesec,
    this.placenaGodina,
    this.vozac,
    this.statistics = const {},
  });

  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    // Parse polasciPoDanu using helper
    Map<String, List<String>> polasciPoDanu = {};
    final parsed = MesecniHelpers.parsePolasciPoDanu(map['polasci_po_danu']);
    parsed.forEach((day, inner) {
      final List<String> list = [];
      final bc = inner['bc'];
      final vs = inner['vs'];
      if (bc != null && bc.isNotEmpty) list.add('$bc BC');
      if (vs != null && vs.isNotEmpty) list.add('$vs VS');
      if (list.isNotEmpty) polasciPoDanu[day] = list;
    });

    return MesecniPutnik(
      id: map['id'] as String? ?? '',
      putnikIme: map['putnik_ime'] as String? ?? map['ime'] as String? ?? '',
      brojTelefona: map['broj_telefona'] as String?,
      brojTelefonaOca: map['broj_telefona_oca'] as String?,
      brojTelefonaMajke: map['broj_telefona_majke'] as String?,
      tip: map['tip'] as String? ?? 'radnik',
      tipSkole: map['tip_skole'] as String?,
      polasciPoDanu: polasciPoDanu,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      datumPocetkaMeseca: map['datum_pocetka_meseca'] != null
          ? DateTime.parse(map['datum_pocetka_meseca'] as String)
          : DateTime(DateTime.now().year, DateTime.now().month),
      datumKrajaMeseca: map['datum_kraja_meseca'] != null
          ? DateTime.parse(map['datum_kraja_meseca'] as String)
          : DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      aktivan: map['aktivan'] as bool? ?? true,
      status: map['status'] as String? ?? 'aktivan',
      ukupnaCenaMeseca: (map['ukupna_cena_meseca'] as num?)?.toDouble() ?? 0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      poslednjePutovanje: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje'] as String)
          : null,
      obrisan: map['obrisan'] as bool? ?? false,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      vozac: map['vozac_id'] as String?,
      statistics: Map<String, dynamic>.from(map['statistics'] as Map? ?? {}),
    );
  }
  final String id;
  final String putnikIme; // kombinovano ime i prezime
  final String? brojTelefona;
  final String? brojTelefonaOca; // dodatni telefon oca
  final String? brojTelefonaMajke; // dodatni telefon majke
  final String tip; // direktno string umesto enum-a
  final String? tipSkole;
  final Map<String, List<String>> polasciPoDanu; // dan -> lista vremena polaska
  final String? adresaBelaCrkva; // adresa u Beloj Crkvi
  final String? adresaVrsac; // adresa u Vršcu
  final String radniDani;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool aktivan;
  final String status;
  // Ostali fields za kompatibilnost
  final double ukupnaCenaMeseca;
  final double? cena;
  final int brojPutovanja;
  final int brojOtkazivanja;
  final DateTime? poslednjePutovanje;
  final bool obrisan;
  final DateTime? vremePlacanja;
  final int? placeniMesec;
  final int? placenaGodina;
  final String? vozac;
  final Map<String, dynamic> statistics;

  /// Dobij ime vozača iz UUID-a sa fallback na 'Nepoznat'
  String get vozacIme {
    return VozacMappingService.getVozacImeWithFallbackSync(vozac);
  }

  Map<String, dynamic> toMap() {
    // Build normalized polasci_po_danu structure
    final Map<String, Map<String, String?>> normalizedPolasci = {};
    polasciPoDanu.forEach((day, times) {
      String? bc;
      String? vs;
      for (final time in times) {
        final normalized = MesecniHelpers.normalizeTime(time.split(' ')[0]);
        if (time.contains('BC')) {
          bc = normalized;
        } else if (time.contains('VS')) {
          vs = normalized;
        }
      }
      normalizedPolasci[day] = {'bc': bc, 'vs': vs};
    });

    // Build statistics
    Map<String, dynamic> stats = Map.from(statistics);
    stats.addAll({
      'trips_total': brojPutovanja,
      'cancellations_total': brojOtkazivanja,
      'last_trip': poslednjePutovanje?.toIso8601String(),
    });

    Map<String, dynamic> result = {
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'broj_telefona_oca': brojTelefonaOca,
      'broj_telefona_majke': brojTelefonaMajke,
      'tip': tip,
      'tip_skole': tipSkole,
      'polasci_po_danu': normalizedPolasci,
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
      'radni_dani': radniDani,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'aktivan': aktivan,
      'status': status,
      'ukupna_cena_meseca': ukupnaCenaMeseca,
      'cena': cena,
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'poslednje_putovanje': poslednjePutovanje?.toIso8601String(),
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'placeni_mesec': placeniMesec,
      'placena_godina': placenaGodina,
      'vozac_id': (vozac?.isEmpty ?? true) ? null : vozac,
      'statistics': stats,
    };

    // ✅ Dodaj id samo ako nije prazan (za UPDATE operacije)
    // Za INSERT operacije, ostavi id da baza generiše UUID
    if (id.isNotEmpty) {
      result['id'] = id;
    }

    return result;
  }

  String get punoIme => putnikIme;

  bool get jePlacen => vremePlacanja != null;

  /// Iznos plaćanja - kompatibilnost sa statistika_service
  double? get iznosPlacanja => cena ?? ukupnaCenaMeseca;

  /// Polazak za Belu Crkvu za dati dan
  String? getPolazakBelaCrkvaZaDan(String dan) {
    final polasci = polasciPoDanu[dan] ?? [];
    for (final polazak in polasci) {
      if (polazak.toUpperCase().contains('BC')) {
        return polazak.replaceAll(' BC', '').trim();
      }
    }
    return null;
  }

  /// Polazak za Vršac za dati dan
  String? getPolazakVrsacZaDan(String dan) {
    final polasci = polasciPoDanu[dan] ?? [];
    for (final polazak in polasci) {
      if (polazak.toUpperCase().contains('VS')) {
        return polazak.replaceAll(' VS', '').trim();
      }
    }
    return null;
  }

  /// copyWith metoda za kreiranje kopije sa izmenjenim poljima
  MesecniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? brojTelefona,
    String? tip,
    String? tipSkole,
    Map<String, List<String>>? polasciPoDanu,
    String? radniDani,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    bool? aktivan,
    String? status,
    double? ukupnaCenaMeseca,
    double? cena,
    DateTime? vremePlacanja,
    int? placeniMesec,
    int? placenaGodina,
    String? vozac,
    int? brojPutovanja,
    int? brojOtkazivanja,
    DateTime? poslednjePutovanje,
    bool? obrisan,
    Map<String, dynamic>? statistics,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      polasciPoDanu: polasciPoDanu ?? this.polasciPoDanu,
      radniDani: radniDani ?? this.radniDani,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      aktivan: aktivan ?? this.aktivan,
      status: status ?? this.status,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      cena: cena ?? this.cena,
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      poslednjePutovanje: poslednjePutovanje ?? this.poslednjePutovanje,
      obrisan: obrisan ?? this.obrisan,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      placeniMesec: placeniMesec ?? this.placeniMesec,
      placenaGodina: placenaGodina ?? this.placenaGodina,
      vozac: vozac ?? this.vozac,
      statistics: statistics ?? this.statistics,
    );
  }

  /// Lista svih vremena polaska za dati dan
  List<String> getPolasciZaDan(String dan) {
    return polasciPoDanu[dan] ?? [];
  }

  /// Dodaje vreme polaska za dati dan
  void dodajPolazak(String dan, String vreme) {
    if (!polasciPoDanu.containsKey(dan)) {
      polasciPoDanu[dan] = [];
    }
    if (!polasciPoDanu[dan]!.contains(vreme)) {
      polasciPoDanu[dan]!.add(vreme);
    }
  }

  /// Uklanja vreme polaska za dati dan
  void ukloniPolazak(String dan, String vreme) {
    polasciPoDanu[dan]?.remove(vreme);
    if (polasciPoDanu[dan]?.isEmpty ?? false) {
      polasciPoDanu.remove(dan);
    }
  }

  @override
  String toString() {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan)';
  }

  // ==================== VALIDATION METHODS ====================

  /// Validira da li su osnovna polja popunjena
  bool isValid() {
    return putnikIme.isNotEmpty &&
        tip.isNotEmpty &&
        polasciPoDanu.isNotEmpty &&
        id.isNotEmpty;
  }

  /// Validira format telefona (srpski brojevi)
  bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return true; // Optional field
    final phoneRegex = RegExp(r'^(\+381|0)[6-9]\d{7,8}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  /// Validira da li su svi kontakt brojevi u ispravnom formatu
  bool hasValidPhoneNumbers() {
    return isValidPhoneNumber(brojTelefona) &&
        isValidPhoneNumber(brojTelefonaOca) &&
        isValidPhoneNumber(brojTelefonaMajke);
  }

  /// Validira da li putnik ima validnu adresu
  bool hasValidAddress() {
    return (adresaBelaCrkva != null && adresaBelaCrkva!.isNotEmpty) ||
        (adresaVrsac != null && adresaVrsac!.isNotEmpty);
  }

  /// Validira da li je period važenja valjan
  bool hasValidPeriod() {
    return datumKrajaMeseca.isAfter(datumPocetkaMeseca);
  }

  /// Kompletna validacija sa detaljnim rezultatom
  Map<String, String> validateFull() {
    final errors = <String, String>{};

    if (putnikIme.trim().isEmpty) {
      errors['putnikIme'] = 'Ime putnika je obavezno';
    }

    if (tip.isEmpty || !['radnik', 'ucenik'].contains(tip)) {
      errors['tip'] = 'Tip mora biti "radnik" ili "ucenik"';
    }

    if (tip == 'ucenik' && (tipSkole == null || tipSkole!.isEmpty)) {
      errors['tipSkole'] = 'Tip škole je obavezan za učenike';
    }

    if (!hasValidPhoneNumbers()) {
      errors['telefoni'] =
          'Jedan ili više brojeva telefona nije u ispravnom formatu';
    }

    if (polasciPoDanu.isEmpty) {
      errors['polasciPoDanu'] = 'Mora biti definisan bar jedan polazak';
    }

    if (!hasValidPeriod()) {
      errors['period'] = 'Datum kraja mora biti posle datuma početka';
    }

    if (cena != null && cena! < 0) {
      errors['cena'] = 'Cena ne može biti negativna';
    }

    return errors;
  }

  // ==================== RELATIONSHIP HELPERS ====================

  /// Da li putnik ima mesečnu kartu (uvek true za MesecniPutnik)
  bool get hasMesecnaKarta => true;

  /// Da li je putnik učenik
  bool get isUcenik => tip == 'ucenik';

  /// Da li je putnik radnik
  bool get isRadnik => tip == 'radnik';

  /// Da li putnik radi danas
  bool radiDanas() {
    final today = DateTime.now();
    final days = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final todayKey = days[today.weekday - 1];
    return radniDani.toLowerCase().contains(todayKey);
  }

  /// Dobija polazna vremena za danas
  List<String> getPolasciZaDanas() {
    final today = DateTime.now();
    final days = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final todayKey = days[today.weekday - 1];
    return polasciPoDanu[todayKey] ?? [];
  }

  /// Da li putnik treba da bude pokupljen u određeno vreme
  bool trebaPokupiti(String vreme) {
    final polasciDanas = getPolasciZaDanas();
    return polasciDanas.any((polazak) => polazak.contains(vreme));
  }

  /// Broj aktivnih dana u nedelji
  int get brojAktivnihDana {
    return radniDani.split(',').where((dan) => dan.isNotEmpty).length;
  }

  /// Da li je plaćen za trenutni mesec
  bool get isPlacenZaTrenutniMesec {
    if (vremePlacanja == null) return false;
    final now = DateTime.now();
    return placeniMesec == now.month && placenaGodina == now.year;
  }

  /// Kalkuliše mesečnu cenu na osnovu broja aktivnih dana
  double kalkulirajMesecnuCenu(double dnevnaCena) {
    return dnevnaCena * brojAktivnihDana * 4; // 4 nedelje u mesecu
  }

  // ==================== UI HELPERS ====================

  /// Dobija boju na osnovu statusa
  Color getStatusColor() {
    if (!aktivan) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'aktivan':
      case 'radi':
        return Colors.green;
      case 'neaktivan':
      case 'pauza':
        return Colors.orange;
      case 'obrisan':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Formatiran prikaz perioda važenja
  String get formatiraniPeriod {
    final formatter = DateFormat('dd.MM.yyyy');
    return '${formatter.format(datumPocetkaMeseca)} - ${formatter.format(datumKrajaMeseca)}';
  }

  /// Kratki opis putnika za UI
  String get shortDescription {
    final tipText = isUcenik ? '👨‍🎓' : '👨‍💼';
    final statusText = aktivan ? '✅' : '❌';
    return '$tipText $putnikIme $statusText';
  }

  /// Detaljni opis za debug
  String get detailDescription {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan, status: $status, polasci: ${polasciPoDanu.length}, period: $formatiraniPeriod)';
  }
}




