class MesecniPutnik {
  final String id;
  final String putnikIme;
  final String tip;
  final String? tipSkole;
  final String? brojTelefona;
  final String? polazakBelaCrkva;
  final String? adresaBelaCrkva;
  final String? polazakVrsac;
  final String? adresaVrsac;
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

  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    required this.tip,
    this.tipSkole,
    this.brojTelefona,
    this.polazakBelaCrkva,
    this.adresaBelaCrkva,
    this.polazakVrsac,
    this.adresaVrsac,
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
      polazakBelaCrkva: map['polazak_bela_crkva'] as String?,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      polazakVrsac: map['polazak_vrsac'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
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
      'polazak_bela_crkva': polazakBelaCrkva,
      'adresa_bela_crkva': adresaBelaCrkva,
      'polazak_vrsac': polazakVrsac,
      'adresa_vrsac': adresaVrsac,
      'tip_prikazivanja': tipPrikazivanja,
      'radni_dani': radniDani,
      'aktivan': aktivan,
      'status': status,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      // 💰 MAPPING PLAĆANJA - koristi ukupnaCenaMeseca ako cena nije definisana
      'cena': cena ?? ukupnaCenaMeseca, // ✅ ZADRŽAVA PLAĆANJE
      // 📅 MESEČNA KARTA DO - izračunava na osnovu datuma kraja meseca  
      'mesecna_karta_do': datumKrajaMeseca.toIso8601String().split('T')[0],
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
    String? polazakBelaCrkva,
    String? adresaBelaCrkva,
    String? polazakVrsac,
    String? adresaVrsac,
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
      polazakBelaCrkva: polazakBelaCrkva ?? this.polazakBelaCrkva,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      polazakVrsac: polazakVrsac ?? this.polazakVrsac,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MesecniPutnik && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
