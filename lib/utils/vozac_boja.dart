import 'package:flutter/material.dart';

class VozacBoja {
  static const Map<String, Color> boje = {
    'Bruda': Color(0xFF7C4DFF), // ljubičasta
    'Bilevski': Color(0xFFFF9800), // narandžasta
    'Bojan': Color(0xFF00E5FF), // svetla cyan plava - osvežavajuća i moderna
    'Svetlana': Color(0xFFFF1493), // drecava pink (DeepPink)
  };

  static Color get(String? ime) {
    // STRIKTNO: SAMO 4 vozača imaju boje - ostalo se ne prikazuje!
    if (ime != null && boje.containsKey(ime)) {
      return boje[ime]!;
    }

    // Za nevalidne vozače, vrati transparentnu boju (neće se videti)
    return Colors.transparent;
  }

  static bool isValidDriver(String? ime) {
    return ime != null && boje.containsKey(ime);
  }

  static List<String> get validDrivers => boje.keys.toList();

  /// Helper za striktnu validaciju vozača sa error handling
  static bool validateDriver(String? driver, {Function(String)? onError}) {
    final isValid = isValidDriver(driver);
    if (!isValid && onError != null) {
      onError('NEVALJAN VOZAČ! Dozvoljen je samo: ${validDrivers.join(", ")}');
    }
    return isValid;
  }
}
