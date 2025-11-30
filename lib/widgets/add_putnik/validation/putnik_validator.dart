import '../models/add_putnik_form_data.dart';

/// 📊 Rezultat validacije forme
class ValidationResult {
  final Map<String, String> errors;
  final bool isValid;

  ValidationResult(this.errors) : isValid = errors.isEmpty;

  /// Vraća grešku za određeno polje
  String? getError(String field) => errors[field];

  /// Proverava da li polje ima grešku
  bool hasError(String field) => errors.containsKey(field);

  /// Prva greška iz liste (za prikaz)
  String? get firstError => errors.isNotEmpty ? errors.values.first : null;

  @override
  String toString() => 'ValidationResult{errors: ${errors.length}, isValid: $isValid}';
}

/// 🔍 Napredni validator za podatke putnika
class PutnikValidator {
  // Regex za srpske brojeve telefona
  static final RegExp _serbianPhoneRegex = RegExp(
    r'^(06[0-9]|0[1-9][0-9])/[0-9]{3}-[0-9]{3,4}$|^(06[0-9]|0[1-9][0-9]) [0-9]{3} [0-9]{3,4}$|^(\+381|00381)[0-9]{8,9}$',
  );

  // Regex za vreme (HH:MM format)
  static final RegExp _timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');

  /// 🔍 Glavna validacija celog formulara
  static ValidationResult validateForm(AddPutnikFormData data) {
    final Map<String, String> errors = {};

    // Validacija imena
    final imeError = _validateIme(data.ime);
    if (imeError != null) errors['ime'] = imeError;

    // Validacija telefona
    final telefonError = _validatePhone(data.brojTelefona);
    if (telefonError != null) errors['telefon'] = telefonError;

    final telefonOcaError = _validatePhone(data.brojTelefonaOca);
    if (telefonOcaError != null) errors['telefonOca'] = telefonOcaError;

    final telefonMajkeError = _validatePhone(data.brojTelefonaMajke);
    if (telefonMajkeError != null) errors['telefonMajke'] = telefonMajkeError;

    // Validacija radnih dana
    if (!data.hasWorkingDays) {
      errors['radniDani'] = 'Morate označiti barem jedan radni dan';
    }

    // Validacija vremena polaska
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      if (data.radniDani[dan] == true) {
        final bcTime = data.vremenaBelaCrkva[dan];
        final vsTime = data.vremenaVrsac[dan];

        // Validacija BC vremena
        if (bcTime != null && bcTime.isNotEmpty) {
          final bcError = _validateTime(bcTime);
          if (bcError != null) {
            errors['vreme_bc_$dan'] = 'BC ${_getDayName(dan)}: $bcError';
          }
        }

        // Validacija VS vremena
        if (vsTime != null && vsTime.isNotEmpty) {
          final vsError = _validateTime(vsTime);
          if (vsError != null) {
            errors['vreme_vs_$dan'] = 'VS ${_getDayName(dan)}: $vsError';
          }
        }
      }
    }

    return ValidationResult(errors);
  }

  /// 📝 Validacija imena
  static String? _validateIme(String ime) {
    final trimmedIme = ime.trim();

    if (trimmedIme.isEmpty) {
      return 'Ime putnika je obavezno';
    }

    if (trimmedIme.length < 2) {
      return 'Ime mora imati najmanje 2 karaktera';
    }

    if (trimmedIme.length > 50) {
      return 'Ime ne može biti duže od 50 karaktera';
    }

    // Provera da li sadrži samo slova i dozvoljene karaktere
    if (!RegExp(r'^[a-zA-ZšđčćžŠĐČĆŽ\s\-\.]+$').hasMatch(trimmedIme)) {
      return 'Ime može sadržavati samo slova, crtice i tačke';
    }

    return null;
  }

  /// 📱 Validacija broja telefona
  static String? _validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null; // Opciono polje
    }

    final trimmedPhone = phone.trim();

    if (!_serbianPhoneRegex.hasMatch(trimmedPhone)) {
      return 'Neispravan format telefona (npr. 064/123-456)';
    }

    return null;
  }

  /// 🕐 Validacija vremena polaska
  static String? _validateTime(String? time) {
    if (time == null || time.trim().isEmpty) {
      return null; // Opciono polje
    }

    final trimmedTime = time.trim();

    if (!_timeRegex.hasMatch(trimmedTime)) {
      return 'Neispravan format vremena (HH:MM)';
    }

    // Dodatna provala validnosti sati i minuta
    final parts = trimmedTime.split(':');
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);

    if (hours == null || minutes == null) {
      return 'Neispravan format vremena';
    }

    if (hours < 0 || hours > 23) {
      return 'Sati moraju biti između 00 i 23';
    }

    if (minutes < 0 || minutes > 59) {
      return 'Minuti moraju biti između 00 i 59';
    }

    return null;
  }

  /// 🗓️ Helper metoda za nazivе dana
  static String _getDayName(String danKod) {
    switch (danKod) {
      case 'pon':
        return 'Ponedeljak';
      case 'uto':
        return 'Utorak';
      case 'sre':
        return 'Sreda';
      case 'cet':
        return 'Četvrtak';
      case 'pet':
        return 'Petak';
      default:
        return danKod;
    }
  }

  /// ✅ Quick validation metode za real-time feedback
  static bool isValidPhoneQuick(String? phone) {
    return _validatePhone(phone) == null;
  }

  static bool isValidTimeQuick(String? time) {
    return _validateTime(time) == null;
  }

  static bool isValidNameQuick(String name) {
    return _validateIme(name) == null;
  }
}
