/// 📋 Model podataka za dodavanje novog putnika
/// Centralizuje sve podatke iz forme u jednoj klasi
class AddPutnikFormData {
  // Osnovne informacije
  String ime;
  String tip;
  String? tipSkole;

  // Kontakt informacije
  String? brojTelefona;
  String? brojTelefonaOca;
  String? brojTelefonaMajke;

  // Adrese
  String? adresaBelaCrkva;
  String? adresaVrsac;

  // Radni dani (pon-pet)
  Map<String, bool> radniDani;

  // Vremena polaska po danima
  Map<String, String> vremenaBelaCrkva;
  Map<String, String> vremenaVrsac;

  AddPutnikFormData({
    this.ime = '',
    this.tip = 'radnik',
    this.tipSkole,
    this.brojTelefona,
    this.brojTelefonaOca,
    this.brojTelefonaMajke,
    this.adresaBelaCrkva,
    this.adresaVrsac,
    Map<String, bool>? radniDani,
    Map<String, String>? vremenaBelaCrkva,
    Map<String, String>? vremenaVrsac,
  })  : radniDani = radniDani ??
            {
              'pon': true,
              'uto': true,
              'sre': true,
              'cet': true,
              'pet': true,
            },
        vremenaBelaCrkva = vremenaBelaCrkva ??
            {
              'pon': '',
              'uto': '',
              'sre': '',
              'cet': '',
              'pet': '',
            },
        vremenaVrsac = vremenaVrsac ??
            {
              'pon': '',
              'uto': '',
              'sre': '',
              'cet': '',
              'pet': '',
            };

  /// 🔄 Kreira kopiju sa izmenjenim vrednostima
  AddPutnikFormData copyWith({
    String? ime,
    String? tip,
    String? tipSkole,
    String? brojTelefona,
    String? brojTelefonaOca,
    String? brojTelefonaMajke,
    String? adresaBelaCrkva,
    String? adresaVrsac,
    Map<String, bool>? radniDani,
    Map<String, String>? vremenaBelaCrkva,
    Map<String, String>? vremenaVrsac,
  }) {
    return AddPutnikFormData(
      ime: ime ?? this.ime,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      brojTelefonaOca: brojTelefonaOca ?? this.brojTelefonaOca,
      brojTelefonaMajke: brojTelefonaMajke ?? this.brojTelefonaMajke,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
      radniDani: radniDani ?? Map.from(this.radniDani),
      vremenaBelaCrkva: vremenaBelaCrkva ?? Map.from(this.vremenaBelaCrkva),
      vremenaVrsac: vremenaVrsac ?? Map.from(this.vremenaVrsac),
    );
  }

  /// 🧹 Resetuje sve podatke na default vrednosti
  void reset() {
    ime = '';
    tip = 'radnik';
    tipSkole = null;
    brojTelefona = null;
    brojTelefonaOca = null;
    brojTelefonaMajke = null;
    adresaBelaCrkva = null;
    adresaVrsac = null;

    radniDani = {
      'pon': true,
      'uto': true,
      'sre': true,
      'cet': true,
      'pet': true,
    };

    vremenaBelaCrkva = {
      'pon': '',
      'uto': '',
      'sre': '',
      'cet': '',
      'pet': '',
    };

    vremenaVrsac = {
      'pon': '',
      'uto': '',
      'sre': '',
      'cet': '',
      'pet': '',
    };
  }

  /// ✅ Proverava da li su uneseni osnovni podaci
  bool get hasBasicData => ime.trim().isNotEmpty;

  /// ✅ Proverava da li je barem jedan radni dan označen
  bool get hasWorkingDays => radniDani.values.any((selected) => selected);

  /// 📊 Broj označenih radnih dana
  int get workingDaysCount => radniDani.values.where((selected) => selected).length;

  /// 🕒 Lista radnih dana sa vremenima (BC + VS)
  Map<String, List<String>> get polasciPoDanu {
    final Map<String, List<String>> polasci = {};

    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      if (radniDani[dan] == true) {
        final List<String> vremenaZaDan = [];

        final bcTime = vremenaBelaCrkva[dan]?.trim();
        final vsTime = vremenaVrsac[dan]?.trim();

        if (bcTime != null && bcTime.isNotEmpty) {
          vremenaZaDan.add('$bcTime BC');
        }

        if (vsTime != null && vsTime.isNotEmpty) {
          vremenaZaDan.add('$vsTime VS');
        }

        if (vremenaZaDan.isNotEmpty) {
          polasci[dan] = vremenaZaDan;
        }
      }
    }

    return polasci;
  }

  /// 📄 String reprezentacija radnih dana
  String get radniDaniString {
    final List<String> odabraniDani = [];
    radniDani.forEach((dan, selected) {
      if (selected) {
        odabraniDani.add(dan);
      }
    });
    return odabraniDani.join(',');
  }

  @override
  String toString() {
    return 'AddPutnikFormData{ime: $ime, tip: $tip, radniDani: $workingDaysCount dana}';
  }
}
