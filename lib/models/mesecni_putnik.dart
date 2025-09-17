import '../utils/mesecni_helpers.dart';

class MesecniPutnik {
  final String id;
  final String putnikIme;
  final String tip;
  final String? tipSkole;
  final String? brojTelefona;

  /// Nova struktura: mapa dan -> lista polazaka (npr. {"pon": ["6 VS", "13 BC"]})
  final Map<String, List<String>> polasciPoDanu;
  final String? adresaBelaCrkva;
  final String? adresaVrsac;
  // Legacy single-time columns removed: use `polasciPoDanu` instead
  final String tipPrikazivanja;
  final String radniDani;
  final bool aktivan;
  final String status;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final double ukupnaCenaMeseca;
  final double? cena; // ✅ NOVA KOLONA - cena mesečne karte
  final int brojPutovanja;
  final int brojOtkazivanja;
  final DateTime? poslednjiPutovanje;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool obrisan; // Soft delete flag

  // 💰 NOVA POLJA ZA STATISTIKU PLAĆANJA
  final DateTime? vremePlacanja; // vreme kada je plaćen - NOVA KOLONA
  final int? placeniMesec; // mesec za koji je plaćeno (1-12)
  final int? placenaGodina; // godina za koju je plaćeno

  // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
  final String?
      vozac; // jedan vozač za sve akcije (dodao, pokupil, naplatio, otkazao)
  final bool pokupljen; // da li je pokupljen
  final DateTime? vremePokupljenja; // kada je pokupljen

  // No legacy single-time helpers; canonical data is in `polasciPoDanu` (map day -> list)

  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    required this.tip,
    this.tipSkole,
    this.brojTelefona,
    required this.polasciPoDanu,
    this.adresaBelaCrkva,
    this.adresaVrsac,
    // Stare kolone za kompatibilnost
    // legacy single-time columns removed
    this.tipPrikazivanja = 'fiksan',
    this.radniDani = 'pon,uto,sre,cet,pet',
    this.aktivan = true,
    this.status = 'radi',
    required this.datumPocetkaMeseca,
    required this.datumKrajaMeseca,
    this.ukupnaCenaMeseca = 0.0,
    this.cena,
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.poslednjiPutovanje,
    required this.createdAt,
    required this.updatedAt,
    this.obrisan = false,
    this.vremePlacanja,
    this.placeniMesec,
    this.placenaGodina,
    this.vozac,
    this.pokupljen = false,
    this.vremePokupljenja,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    // Backward kompatibilnost: koristi helpers da parsira polasci_po_danu ili per-day kolone
    Map<String, List<String>> polasciPoDanu = {};
    // Try to use unified parser which normalizes times
    final parsed = MesecniHelpers.parsePolasciPoDanu(map['polasci_po_danu']);
    if (parsed.isNotEmpty) {
      parsed.forEach((day, inner) {
        final List<String> list = [];
        final bc = inner['bc'];
        final vs = inner['vs'];
        if (bc != null && bc.isNotEmpty) list.add('$bc BC');
        if (vs != null && vs.isNotEmpty) list.add('$vs VS');
        if (list.isNotEmpty) polasciPoDanu[day] = list;
      });
    } else {
      // Fallback: check per-day columns via helper getPolazakForDay
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        final List<String> polasci = [];
        final bc = MesecniHelpers.getPolazakForDay(map, dan, 'bc');
        final vs = MesecniHelpers.getPolazakForDay(map, dan, 'vs');
        if (bc != null && bc.isNotEmpty) polasci.add('$bc BC');
        if (vs != null && vs.isNotEmpty) polasci.add('$vs VS');
        if (polasci.isNotEmpty) polasciPoDanu[dan] = polasci;
      }
    }
    return MesecniPutnik(
      id: map['id'] as String,
      putnikIme: map['putnik_ime'] as String,
      tip: map['tip'] as String,
      tipSkole: map['tip_skole'] as String?,
      brojTelefona: map['broj_telefona'] as String?,
      polasciPoDanu: polasciPoDanu,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
      // legacy columns removed; rely on polasci_po_danu and helpers
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'fiksan',
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      aktivan: MesecniHelpers.isActiveFromMap(map),
      status: map['status'] as String? ?? 'radi',
      datumPocetkaMeseca: DateTime.parse(map['datum_pocetka_meseca'] as String),
      datumKrajaMeseca: DateTime.parse(map['datum_kraja_meseca'] as String),
      ukupnaCenaMeseca: (map['cena'] as num?)?.toDouble() ?? 0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      poslednjiPutovanje: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      obrisan: !(MesecniHelpers.isActiveFromMap(map)),
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      vozac: map['naplata_vozac'] as String?,
      pokupljen: false,
      vremePokupljenja: null,
    );
  }

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'putnik_ime': putnikIme,
      'tip': tip,
      'tip_skole': tipSkole,
      'broj_telefona': brojTelefona,
      'polasci_po_danu': polasciPoDanu,
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
      // legacy fields removed - keep canonical `polasci_po_danu`
      'tip_prikazivanja': tipPrikazivanja,
      'radni_dani': radniDani,
      'aktivan': aktivan,
      'status': status,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'cena': cena ?? ukupnaCenaMeseca,
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'poslednje_putovanje':
          poslednjiPutovanje?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vozac': vozac,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  MesecniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? tip,
    String? tipSkole,
    String? brojTelefona,
    Map<String, List<String>>? polasciPoDanu,
    String? adresaBelaCrkva,
    String? adresaVrsac,
    // legacy polazak fields removed
    String? tipPrikazivanja,
    String? radniDani,
    bool? aktivan,
    String? status,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    double? ukupnaCenaMeseca,
    double? cena,
    int? brojPutovanja,
    int? brojOtkazivanja,
    DateTime? poslednjiPutovanje,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? obrisan,
    DateTime? vremePlacanja,
    String? vozac,
    bool? pokupljen,
    DateTime? vremePokupljenja,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      polasciPoDanu: polasciPoDanu ?? this.polasciPoDanu,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
      // legacy fields removed
      tipPrikazivanja: tipPrikazivanja ?? this.tipPrikazivanja,
      radniDani: radniDani ?? this.radniDani,
      aktivan: aktivan ?? this.aktivan,
      status: status ?? this.status,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      cena: cena ?? this.cena,
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      poslednjiPutovanje: poslednjiPutovanje ?? this.poslednjiPutovanje,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obrisan: obrisan ?? this.obrisan,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      vozac: vozac ?? this.vozac,
      pokupljen: pokupljen ?? this.pokupljen,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
    );
  }

  @override
  String toString() {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan)';
  }

  // 💰 HELPER METODE ZA PLAĆANJE
  bool get jePlacen =>
      vremePlacanja != null &&
      (cena ?? 0) > 0; // ✅ NOVA KOLONA - koristi cena umesto ukupnaCenaMeseca

  String get statusPlacanja {
    if (jePlacen) {
      return 'Plaćeno: ${(cena ?? 0).toStringAsFixed(0)} RSD (${vremePlacanja!.toString().split('T')[0]})';
    }
    return 'Nije plaćeno';
  }

  // 🔄 KOMPATIBILNOST SA PUTNIK MODELOM
  double? get iznosPlacanja => (cena ?? 0) > 0
      ? cena
      : ukupnaCenaMeseca > 0
          ? ukupnaCenaMeseca
          : null; // Mapiranje za kompatibilnost - prioritet ima cena kolona

  // 🚗 HELPER METODE ZA DRIVER TRACKING
  String? get naplatioVozac =>
      jePlacen ? vozac : null; // Ko je naplatio (ako je plaćeno)
  String? get pokupioVozac =>
      pokupljen ? vozac : null; // Ko je pokupil (ako je pokupljen)
  String? get dodaoVozac => vozac; // Ko je dodao mesečnog putnika
  String? get otkazaoVozac => (!aktivan && vozac != null)
      ? vozac
      : null; // Ko je otkazao (ako je neaktivan)

  // 📅 HELPER METODE ZA VREMENA POLASKA PO DANIMA
  /// Vraća vreme polaska iz Bele Crkve za specifičan dan
  /// [dan] može biti: 'pon', 'uto', 'sre', 'cet', 'pet'
  String? getPolazakBelaCrkvaZaDan(String dan) {
    // Prefer explicit polasciPoDanu parsed during fromMap
    final list = polasciPoDanu[dan];
    if (list != null && list.isNotEmpty) {
      for (final entry in list) {
        if (entry.endsWith(' BC')) return entry.replaceFirst(' BC', '');
      }
      return list.first.replaceAll(RegExp(r'\s+(BC|VS)\$'), '');
    }
    return null;
  }

  /// Vraća vreme polaska iz Vršca za specifičan dan
  /// [dan] može biti: 'pon', 'uto', 'sre', 'cet', 'pet'
  String? getPolazakVrsacZaDan(String dan) {
    final list = polasciPoDanu[dan];
    if (list != null && list.isNotEmpty) {
      for (final entry in list) {
        if (entry.endsWith(' VS')) return entry.replaceFirst(' VS', '');
      }
      return list.first.replaceAll(RegExp(r'\s+(BC|VS)\$'), '');
    }
    return null;
  }

  /// Vraća vreme polaska za trenutni dan nedelje
  String? getPolazakZaDanasnjiDan(String grad) {
    final danasnjiDan = _getDanNedelje();
    if (grad.toLowerCase().contains('bela') ||
        grad.toLowerCase().contains('crkva')) {
      return getPolazakBelaCrkvaZaDan(danasnjiDan);
    } else if (grad.toLowerCase().contains('vršac') ||
        grad.toLowerCase().contains('vrsac')) {
      return getPolazakVrsacZaDan(danasnjiDan);
    }
    return null;
  }

  /// Helper metod za dobijanje naziva dana nedelje
  String _getDanNedelje() {
    final sada = DateTime.now();
    final danNedelje = sada.weekday; // 1=Monday, 7=Sunday

    switch (danNedelje) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub'; // Subota (ako dodamo)
      case 7:
        return 'ned'; // Nedelja (ako dodamo)
      default:
        return 'pon';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MesecniPutnik && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
