import 'package:flutter/material.dart';

class VozacBoja {
  static const Map<String, Color> boje = {
    'Bruda': Color(0xFF7C4DFF), // ljubičasta
    'Bilevski': Color(0xFFFF9800), // narandžasta
    'Bojan': Color(0xFF00E5FF), // svetla cyan plava - osvežavajuća i moderna
    'Svetlana': Color(0xFFFF1493), // drecava pink (DeepPink)
    'Vlajic': Color(0xFF8B4513), // braon (SaddleBrown)
  };

  // 🔒 DOZVOLJENI EMAIL ADRESE ZA VOZAČE - STRIKTNO!
  static const Map<String, String> dozvoljenEmails = {
    'Bojan': 'gavriconi19@gmail.com',
    'Bruda': 'igor.jovanovic.1984@icloud.com',
    'Bilevski': 'bilyboy1983@gmail.com',
    'Svetlana': 'risticsvetlana2911@yahoo.com',
    'Vlajic': 'kadpitamkurac@gmail.com',
  };

  // 🔒 VALIDACIJA: email -> vozač mapiranje
  static const Map<String, String> emailToVozac = {
    'gavriconi19@gmail.com': 'Bojan',
    'igor.jovanovic.1984@icloud.com': 'Bruda',
    'bilyboy1983@gmail.com': 'Bilevski',
    'risticsvetlana2911@yahoo.com': 'Svetlana',
    'kadpitamkurac@gmail.com': 'Vlajic',
  };

  // 📞 BROJEVI TELEFONA VOZAČA
  static const Map<String, String> telefoni = {
    'Bojan': '0641162560',
    'Bruda': '0641202844',
    'Bilevski': '0638466418',
    'Svetlana': '0658464160',
    'Vlajic': '0605073073',
  };

  static Color get(String? ime) {
    if (ime != null && boje.containsKey(ime)) {
      return boje[ime]!;
    }

    // Trebalo bi da se poziva samo za validne vozače
    throw ArgumentError('Nepoznat vozač: $ime. Validni vozači: ${boje.keys.join(", ")}');
  }

  /// Proverava da li je vozač prepoznat/valjan
  static bool isValidDriver(String? ime) {
    return ime != null && boje.containsKey(ime);
  }

  /// Lista svih validnih vozača
  static List<String> get validDrivers => boje.keys.toList();

  /// Vraća boju vozača ili default boju za nepoznate vozače
  static Color getColorOrDefault(String? ime, Color defaultColor) {
    if (ime != null && boje.containsKey(ime)) {
      return boje[ime]!;
    }
    return defaultColor;
  }

  /// Alias za get() metodu - za kompatibilnost
  static Color getColor(String? ime) => get(ime);

  // 🔒 HELPER FUNKCIJE ZA EMAIL VALIDACIJU
  static String? getDozvoljenEmailForVozac(String? vozac) {
    return vozac != null ? dozvoljenEmails[vozac] : null;
  }

  static String? getVozacForEmail(String? email) {
    return email != null ? emailToVozac[email] : null;
  }

  static bool isEmailDozvoljenForVozac(String? email, String? vozac) {
    if (email == null || vozac == null) return false;
    return dozvoljenEmails[vozac]?.toLowerCase() == email.toLowerCase();
  }

  static bool isDozvoljenEmail(String? email) {
    return email != null && emailToVozac.containsKey(email);
  }

  static List<String> get sviDozvoljenEmails => dozvoljenEmails.values.toList();

  // 📞 HELPER ZA TELEFON
  static String? getTelefonForVozac(String? vozac) {
    return vozac != null ? telefoni[vozac] : null;
  }
}
