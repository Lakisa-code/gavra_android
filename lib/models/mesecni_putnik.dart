class MesecniPutnik {
  final String id;
  final String putnikIme;
  final String tip;
  final String? tipSkole;
  final String? brojTelefona;
  // Vremena polaska iz Bele Crkve po danima
  final String? polazakBcPon;
  final String? polazakBcUto;
  final String? polazakBcSre;
  final String? polazakBcCet;
  final String? polazakBcPet;
  final String? adresaBelaCrkva;
  // Vremena polaska iz Vršca po danima
  final String? polazakVsPon;
  final String? polazakVsUto;
  final String? polazakVsSre;
  final String? polazakVsCet;
  final String? polazakVsPet;
  final String? adresaVrsac;
  // Stare kolone - zadržavamo za kompatibilnost
  final Map<String, String>? polazakBelaCrkva;
  final Map<String, String>? polazakVrsac;
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

  // Helper funkcije za JSON konverziju
  static Map<String, String>? _parsePolazakVreme(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Ako je string, verovatno je stari format - konvertuj u novi
      if (value.isEmpty || value == '00:00:00') return null;
      // Za sada, postavi isto vreme za sve dane
      return {
        'pon': value,
        'uto': value,
        'sre': value,
        'cet': value,
        'pet': value,
      };
    }
    if (value is Map) {
      // Ako je već mapa, konvertuj u Map<String, String>
      return Map<String, String>.from(value);
    }
    return null;
  }

  static String? _polazakVremeToTime(Map<String, String>? polazakVreme) {
    if (polazakVreme == null || polazakVreme.isEmpty) return null;

    // Pronađi prvo definirano vreme iz mape
    for (final entry in polazakVreme.entries) {
      if (entry.value.isNotEmpty && entry.value != '00:00') {
        // Konvertuj u TIME format HH:MM:SS
        String timeValue = entry.value;
        if (timeValue.length == 5) {
          // Ako je HH:MM, dodaj :00
          timeValue = '$timeValue:00';
        }
        return timeValue;
      }
    }
    return null;
  }

  // Helper metoda za formatiranje vremena iz string-a (za nove kolone)
  static String? _formatTimeString(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return null;
    }

    // Ukloni sekunde ako postoje (12:00:00 -> 12:00)
    if (timeString.length == 8 && timeString.contains(':')) {
      return timeString.substring(0, 5); // Uzmi samo HH:MM deo
    }

    return timeString;
  }

  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    required this.tip,
    this.tipSkole,
    this.brojTelefona,
    // Vremena polaska iz Bele Crkve po danima
    this.polazakBcPon,
    this.polazakBcUto,
    this.polazakBcSre,
    this.polazakBcCet,
    this.polazakBcPet,
    this.adresaBelaCrkva,
    // Vremena polaska iz Vršca po danima
    this.polazakVsPon,
    this.polazakVsUto,
    this.polazakVsSre,
    this.polazakVsCet,
    this.polazakVsPet,
    this.adresaVrsac,
    // Stare kolone za kompatibilnost
    this.polazakBelaCrkva,
    this.polazakVrsac,
    this.tipPrikazivanja = 'fiksan',
    this.radniDani = 'pon,uto,sre,cet,pet',
    this.aktivan = true,
    this.status = 'radi',
    required this.datumPocetkaMeseca,
    required this.datumKrajaMeseca,
    this.ukupnaCenaMeseca = 0.0,
    this.cena, // ✅ NOVA KOLONA - cena mesečne karte
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.poslednjiPutovanje,
    required this.createdAt,
    required this.updatedAt,
    this.obrisan = false,
    // 💰 NOVA POLJA ZA STATISTIKU - ISPRAVNO MAPIRANJE
    this.vremePlacanja,
    this.placeniMesec,
    this.placenaGodina,
    // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
    this.vozac,
    this.pokupljen = false,
    this.vremePokupljenja,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    return MesecniPutnik(
      id: map['id'] as String,
      putnikIme: map['putnik_ime'] as String,
      tip: map['tip'] as String,
      tipSkole: map['tip_skole'] as String?,
      brojTelefona: map['broj_telefona'] as String?,
      // Nove kolone za vremena po danima
      polazakBcPon: map['polazak_bc_pon'] as String?,
      polazakBcUto: map['polazak_bc_uto'] as String?,
      polazakBcSre: map['polazak_bc_sre'] as String?,
      polazakBcCet: map['polazak_bc_cet'] as String?,
      polazakBcPet: map['polazak_bc_pet'] as String?,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      polazakVsPon: map['polazak_vs_pon'] as String?,
      polazakVsUto: map['polazak_vs_uto'] as String?,
      polazakVsSre: map['polazak_vs_sre'] as String?,
      polazakVsCet: map['polazak_vs_cet'] as String?,
      polazakVsPet: map['polazak_vs_pet'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
      // Stare kolone za kompatibilnost
      polazakBelaCrkva: _parsePolazakVreme(map['polazak_bela_crkva']),
      polazakVrsac: _parsePolazakVreme(map['polazak_vrsac']),
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'fiksan',
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      aktivan: map['aktivan'] as bool? ?? true,
      status: map['status'] as String? ?? 'radi',
      datumPocetkaMeseca: DateTime.parse(map['datum_pocetka_meseca'] as String),
      datumKrajaMeseca: DateTime.parse(map['datum_kraja_meseca'] as String),
      ukupnaCenaMeseca: (map['cena'] as num?)?.toDouble() ??
          0.0, // ✅ FALLBACK - koristi cena kolonu za ukupnaCenaMeseca
      cena: (map['cena'] as num?)?.toDouble(), // ✅ NOVA KOLONA - mapiranje
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      poslednjiPutovanje: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      obrisan: map['obrisan'] as bool? ?? false,
      // 💰 NOVA POLJA ZA STATISTIKU PLAĆANJA - ISPRAVNO MAPIRANJE
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
      vozac: map['naplata_vozac'] as String?, // Vozač koji je naplatio plaćanje
      pokupljen: false, // ❌ FIKSNA VREDNOST - kolona možda ne postoji u bazi
      vremePokupljenja: null, // ❌ FIKSNA VREDNOST - kolona ne postoji u bazi
    );
  }

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'putnik_ime': putnikIme,
      'tip': tip,
      'tip_skole': tipSkole,
      'broj_telefona': brojTelefona,
      // Nove kolone za vremena po danima
      'polazak_bc_pon': polazakBcPon,
      'polazak_bc_uto': polazakBcUto,
      'polazak_bc_sre': polazakBcSre,
      'polazak_bc_cet': polazakBcCet,
      'polazak_bc_pet': polazakBcPet,
      'polazak_vs_pon': polazakVsPon,
      'polazak_vs_uto': polazakVsUto,
      'polazak_vs_sre': polazakVsSre,
      'polazak_vs_cet': polazakVsCet,
      'polazak_vs_pet': polazakVsPet,
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
      // Stare kolone - postavi na null ako koristimo nova vremena po danima
      'polazak_bela_crkva':
          _hasNewTimeColumns() ? null : _polazakVremeToTime(polazakBelaCrkva),
      'polazak_vrsac':
          _hasNewTimeColumns() ? null : _polazakVremeToTime(polazakVrsac),
      'tip_prikazivanja': tipPrikazivanja,
      'radni_dani': radniDani,
      'aktivan': aktivan,
      'status': status,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      // 💰 MAPPING PLAĆANJA - koristi ukupnaCenaMeseca ako cena nije definisana
      'cena': cena ?? ukupnaCenaMeseca, // ✅ ZADRŽAVA PLAĆANJE
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'poslednje_putovanje':
          poslednjiPutovanje?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      // 💰 NOVA POLJA ZA STATISTIKU PLAĆANJA - ISPRAVNO MAPIRANJE
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
      'vozac': vozac,
      // 'pokupljen': pokupljen, // ❌ MOŽDA NE POSTOJI - treba proveriti
      // 'vreme_pokupljanja': vremePokupljenja?.toIso8601String(), // ❌ UKLONJENO - kolona ne postoji u bazi
    };

    // Dodaj ID samo ako nije prazan (za ažuriranje postojećih putnika)
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
    // Nove kolone za vremena po danima
    String? polazakBcPon,
    String? polazakBcUto,
    String? polazakBcSre,
    String? polazakBcCet,
    String? polazakBcPet,
    String? polazakVsPon,
    String? polazakVsUto,
    String? polazakVsSre,
    String? polazakVsCet,
    String? polazakVsPet,
    String? adresaBelaCrkva,
    String? adresaVrsac,
    // Stare kolone za kompatibilnost
    Map<String, String>? polazakBelaCrkva,
    Map<String, String>? polazakVrsac,
    String? tipPrikazivanja,
    String? radniDani,
    bool? aktivan,
    String? status,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    double? ukupnaCenaMeseca,
    double? cena, // ✅ NOVA KOLONA - copyWith parametar
    int? brojPutovanja,
    int? brojOtkazivanja,
    DateTime? poslednjiPutovanje,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? obrisan,
    // 💰 NOVA POLJA ZA STATISTIKU - ISPRAVNO MAPIRANJE
    DateTime? vremePlacanja,
    // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
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
      // Nove kolone za vremena po danima
      polazakBcPon: polazakBcPon ?? this.polazakBcPon,
      polazakBcUto: polazakBcUto ?? this.polazakBcUto,
      polazakBcSre: polazakBcSre ?? this.polazakBcSre,
      polazakBcCet: polazakBcCet ?? this.polazakBcCet,
      polazakBcPet: polazakBcPet ?? this.polazakBcPet,
      polazakVsPon: polazakVsPon ?? this.polazakVsPon,
      polazakVsUto: polazakVsUto ?? this.polazakVsUto,
      polazakVsSre: polazakVsSre ?? this.polazakVsSre,
      polazakVsCet: polazakVsCet ?? this.polazakVsCet,
      polazakVsPet: polazakVsPet ?? this.polazakVsPet,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
      // Stare kolone za kompatibilnost
      polazakBelaCrkva: polazakBelaCrkva ?? this.polazakBelaCrkva,
      polazakVrsac: polazakVrsac ?? this.polazakVrsac,
      tipPrikazivanja: tipPrikazivanja ?? this.tipPrikazivanja,
      radniDani: radniDani ?? this.radniDani,
      aktivan: aktivan ?? this.aktivan,
      status: status ?? this.status,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      cena: cena ?? this.cena, // ✅ NOVA KOLONA - copyWith kopija
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      poslednjiPutovanje: poslednjiPutovanje ?? this.poslednjiPutovanje,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obrisan: obrisan ?? this.obrisan,
      // 💰 NOVA POLJA ZA STATISTIKU - ISPRAVNO MAPIRANJE
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
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
    switch (dan) {
      case 'pon':
        return _formatTimeString(polazakBcPon) ?? polazakBelaCrkva?[dan];
      case 'uto':
        return _formatTimeString(polazakBcUto) ?? polazakBelaCrkva?[dan];
      case 'sre':
        return _formatTimeString(polazakBcSre) ?? polazakBelaCrkva?[dan];
      case 'cet':
        return _formatTimeString(polazakBcCet) ?? polazakBelaCrkva?[dan];
      case 'pet':
        return _formatTimeString(polazakBcPet) ?? polazakBelaCrkva?[dan];
      default:
        return polazakBelaCrkva?[dan];
    }
  }

  /// Vraća vreme polaska iz Vršca za specifičan dan
  /// [dan] može biti: 'pon', 'uto', 'sre', 'cet', 'pet'
  String? getPolazakVrsacZaDan(String dan) {
    switch (dan) {
      case 'pon':
        return _formatTimeString(polazakVsPon) ?? polazakVrsac?[dan];
      case 'uto':
        return _formatTimeString(polazakVsUto) ?? polazakVrsac?[dan];
      case 'sre':
        return _formatTimeString(polazakVsSre) ?? polazakVrsac?[dan];
      case 'cet':
        return _formatTimeString(polazakVsCet) ?? polazakVrsac?[dan];
      case 'pet':
        return _formatTimeString(polazakVsPet) ?? polazakVrsac?[dan];
      default:
        return polazakVrsac?[dan];
    }
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

  /// Proverava da li putnik koristi nova vremena po danima
  bool _hasNewTimeColumns() {
    return polazakBcPon != null ||
        polazakBcUto != null ||
        polazakBcSre != null ||
        polazakBcCet != null ||
        polazakBcPet != null ||
        polazakVsPon != null ||
        polazakVsUto != null ||
        polazakVsSre != null ||
        polazakVsCet != null ||
        polazakVsPet != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MesecniPutnik && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
