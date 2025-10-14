import 'package:uuid/uuid.dart';

/// Model za rute
class Ruta {
  Ruta({
    String? id,
    required this.naziv,
    required this.polazak,
    required this.dolazak,
    this.opis,
    this.udaljenostKm,
    this.prosecnoVreme,
    this.aktivan = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Ruta.fromMap(Map<String, dynamic> map) {
    return Ruta(
      id: map['id'] as String,
      naziv: map['naziv'] as String,
      polazak: map['polazak'] as String,
      dolazak: map['dolazak'] as String,
      opis: map['opis'] as String?,
      udaljenostKm: (map['udaljenost_km'] as num?)?.toDouble(),
      prosecnoVreme: map['prosecno_vreme'] != null
          ? Duration(seconds: map['prosecno_vreme'] as int)
          : null,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  final String id;
  final String naziv;
  final String polazak;
  final String dolazak;
  final String? opis;
  final double? udaljenostKm;
  final Duration? prosecnoVreme;
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'naziv': naziv,
      'polazak': polazak,
      'dolazak': dolazak,
      'opis': opis,
      'udaljenost_km': udaljenostKm,
      'prosecno_vreme': prosecnoVreme?.inSeconds,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get rutaOpis => '$polazak → $dolazak';

  // 🔍 VALIDACIJA
  /// Kompletna validacija rute
  Map<String, String> validateFull() {
    final errors = <String, String>{};

    // Validacija naziva
    if (naziv.trim().isEmpty) {
      errors['naziv'] = 'Naziv rute je obavezan';
    } else if (naziv.trim().length < 3) {
      errors['naziv'] = 'Naziv rute mora imati najmanje 3 karaktera';
    } else if (naziv.trim().length > 100) {
      errors['naziv'] = 'Naziv rute ne može biti duži od 100 karaktera';
    }

    // Validacija polaska
    if (polazak.trim().isEmpty) {
      errors['polazak'] = 'Polazište je obavezno';
    } else if (polazak.trim().length < 2) {
      errors['polazak'] = 'Polazište mora imati najmanje 2 karaktera';
    }

    // Validacija dolaska
    if (dolazak.trim().isEmpty) {
      errors['dolazak'] = 'Odredište je obavezno';
    } else if (dolazak.trim().length < 2) {
      errors['dolazak'] = 'Odredište mora imati najmanje 2 karaktera';
    }

    // Validacija logike
    if (polazak.trim().toLowerCase() == dolazak.trim().toLowerCase()) {
      errors['destinacija'] = 'Polazište i odredište ne mogu biti isti';
    }

    // Validacija udaljenosti
    if (udaljenostKm != null) {
      if (udaljenostKm! < 0) {
        errors['udaljenost'] = 'Udaljenost ne može biti negativna';
      } else if (udaljenostKm! > 1000) {
        errors['udaljenost'] = 'Udaljenost ne može biti veća od 1000km';
      }
    }

    // Validacija vremena
    if (prosecnoVreme != null) {
      if (prosecnoVreme!.inMinutes < 1) {
        errors['vreme'] = 'Prosečno vreme mora biti najmanje 1 minut';
      } else if (prosecnoVreme!.inHours > 24) {
        errors['vreme'] = 'Prosečno vreme ne može biti veće od 24 sata';
      }
    }

    return errors;
  }

  /// Brza validacija osnovnih polja
  bool get isValid {
    return naziv.trim().isNotEmpty &&
        polazak.trim().isNotEmpty &&
        dolazak.trim().isNotEmpty &&
        polazak.trim().toLowerCase() != dolazak.trim().toLowerCase();
  }

  /// Validacija za bazu podataka
  bool get isValidForDatabase {
    final errors = validateFull();
    return errors.isEmpty;
  }

  // 🎨 UI HELPER METODE
  /// Kratak opis rute za UI
  String get kratakOpis {
    if (udaljenostKm != null && prosecnoVreme != null) {
      return '$polazak → $dolazak (${udaljenostKm!.toStringAsFixed(1)}km, ${prosecnoVreme!.inMinutes}min)';
    } else if (udaljenostKm != null) {
      return '$polazak → $dolazak (${udaljenostKm!.toStringAsFixed(1)}km)';
    }
    return rutaOpis;
  }

  /// Status rute za prikaz
  String get statusOpis => aktivan ? 'Aktivna' : 'Neaktivna';

  /// Boja za status rute
  String get statusBoja => aktivan ? '#4CAF50' : '#F44336';

  /// Formatovano vreme putovanja
  String get formatiranVreme {
    if (prosecnoVreme == null) return 'Nepoznato';

    final sati = prosecnoVreme!.inHours;
    final minuti = prosecnoVreme!.inMinutes % 60;

    if (sati > 0) {
      return '${sati}h ${minuti}min';
    }
    return '${minuti}min';
  }

  /// Formatovana udaljenost
  String get formatiranaUdaljenost {
    if (udaljenostKm == null) return 'Nepoznato';
    return '${udaljenostKm!.toStringAsFixed(1)} km';
  }

  // 📊 HELPER METODE ZA BUSINESS LOGIKU
  /// Proverava da li je ruta kratka (manje od 20km)
  bool get jeKratkaRuta => udaljenostKm != null && udaljenostKm! < 20;

  /// Proverava da li je ruta dugačka (više od 100km)
  bool get jeDugackaRuta => udaljenostKm != null && udaljenostKm! > 100;

  /// Proverava da li je ruta brza (manje od 30min)
  bool get jeBrzaRuta => prosecnoVreme != null && prosecnoVreme!.inMinutes < 30;

  /// Proverava da li je ruta spora (više od 2h)
  bool get jeSporaRuta => prosecnoVreme != null && prosecnoVreme!.inHours > 2;

  /// Kalkuliše prosečnu brzinu (km/h)
  double? get prosecnaBrzina {
    if (udaljenostKm == null ||
        prosecnoVreme == null ||
        prosecnoVreme!.inMinutes == 0) {
      return null;
    }
    return udaljenostKm! / (prosecnoVreme!.inMinutes / 60.0);
  }

  /// Formatovana prosečna brzina
  String get formatiranaProescnaBrzina {
    final brzina = prosecnaBrzina;
    if (brzina == null) return 'Nepoznato';
    return '${brzina.toStringAsFixed(1)} km/h';
  }

  // 🔄 COPY WITH METODE
  /// Kreira kopiju rute sa izmenjenim vrednostima
  Ruta copyWith({
    String? id,
    String? naziv,
    String? polazak,
    String? dolazak,
    String? opis,
    double? udaljenostKm,
    Duration? prosecnoVreme,
    bool? aktivan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ruta(
      id: id ?? this.id,
      naziv: naziv ?? this.naziv,
      polazak: polazak ?? this.polazak,
      dolazak: dolazak ?? this.dolazak,
      opis: opis ?? this.opis,
      udaljenostKm: udaljenostKm ?? this.udaljenostKm,
      prosecnoVreme: prosecnoVreme ?? this.prosecnoVreme,
      aktivan: aktivan ?? this.aktivan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Kreira kopiju sa ažuriranim vremenom
  Ruta withUpdatedTime() {
    return copyWith(updatedAt: DateTime.now());
  }

  /// Aktivira rutu
  Ruta activate() {
    return copyWith(aktivan: true, updatedAt: DateTime.now());
  }

  /// Deaktivira rutu
  Ruta deactivate() {
    return copyWith(aktivan: false, updatedAt: DateTime.now());
  }

  // 🔍 SEARCH HELPER METODE
  /// Proverava da li ruta sadrži query u nazivu, polasku ili dolasku
  bool containsQuery(String query) {
    final lowerQuery = query.toLowerCase().trim();
    return naziv.toLowerCase().contains(lowerQuery) ||
        polazak.toLowerCase().contains(lowerQuery) ||
        dolazak.toLowerCase().contains(lowerQuery) ||
        (opis?.toLowerCase().contains(lowerQuery) ?? false);
  }

  /// Proverava da li ruta povezuje određena mesta
  bool connectsCities(String grad1, String grad2) {
    final city1 = grad1.toLowerCase().trim();
    final city2 = grad2.toLowerCase().trim();
    final startCity = polazak.toLowerCase().trim();
    final endCity = dolazak.toLowerCase().trim();

    return (startCity == city1 && endCity == city2) ||
        (startCity == city2 && endCity == city1);
  }

  // 📋 COMPARISON METODE
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ruta &&
        other.id == id &&
        other.naziv == naziv &&
        other.polazak == polazak &&
        other.dolazak == dolazak;
  }

  @override
  int get hashCode {
    return id.hashCode ^ naziv.hashCode ^ polazak.hashCode ^ dolazak.hashCode;
  }

  @override
  String toString() {
    return 'Ruta(id: $id, naziv: $naziv, polazak: $polazak, dolazak: $dolazak, aktivan: $aktivan)';
  }
}



