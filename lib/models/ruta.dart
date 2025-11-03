import 'package:uuid/uuid.dart';

/// Model za rute - kompatibilan sa tabelem 'rute' u bazi
class Ruta {
  Ruta({
    String? id,
    required this.naziv,
    this.opis,
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
      opis: map['opis'] as String?,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String naziv;
  final String? opis;
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'naziv': naziv,
      'opis': opis,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

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

    return errors;
  }

  /// Brza validacija osnovnih polja
  bool get isValid {
    return naziv.trim().isNotEmpty;
  }

  /// Validacija za bazu podataka
  bool get isValidForDatabase {
    final errors = validateFull();
    return errors.isEmpty;
  }

  // 🎨 UI HELPER METODE
  /// Status rute za prikaz
  String get statusOpis => aktivan ? 'Aktivna' : 'Neaktivna';

  /// Boja za status rute
  String get statusBoja => aktivan ? '#4CAF50' : '#F44336';

  // 🔄 COPY WITH METODE
  /// Kreira kopiju rute sa izmenjenim vrednostima
  Ruta copyWith({
    String? id,
    String? naziv,
    String? opis,
    bool? aktivan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ruta(
      id: id ?? this.id,
      naziv: naziv ?? this.naziv,
      opis: opis ?? this.opis,
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
  /// Proverava da li ruta sadrži query u nazivu ili opisu
  bool containsQuery(String query) {
    final lowerQuery = query.toLowerCase().trim();
    return naziv.toLowerCase().contains(lowerQuery) || (opis?.toLowerCase().contains(lowerQuery) ?? false);
  }

  // 📋 COMPARISON METODE
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ruta && other.id == id && other.naziv == naziv;
  }

  @override
  int get hashCode {
    return id.hashCode ^ naziv.hashCode;
  }

  @override
  String toString() {
    return 'Ruta(id: $id, naziv: $naziv, aktivan: $aktivan)';
  }
}
