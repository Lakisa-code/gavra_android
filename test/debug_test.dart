import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debug test', () {
    test('Debug normalizacija', () async {
      // Test funkcija da vidim šta se dešava
      final testGradovi = ['Potporanj', 'Orešac', 'Vraćev Gaj'];

      for (final grad in testGradovi) {
        final normalizedGrad = grad.toLowerCase().trim();
        // Debug output removed

        final allowedCities = [
          'vrsac',
          'vršac',
          'straza',
          'straža',
          'vojvodinci',
          'potporanj',
          'oresac',
          'orešac',
          'bela crkva',
          'vracev gaj',
          'dupljaja',
          'jasenovo',
          'kruscica',
          'kruščica',
          'kusic',
          'kusić',
          'crvena crkva'
        ];

        bool found = false;
        for (final allowed in allowedCities) {
          if (normalizedGrad.contains(allowed) ||
              allowed.contains(normalizedGrad)) {
            // Debug output removed
            found = true;
            break;
          }
        }

        if (!found) {
          // Debug output removed
          // Pokušaj da nađem najsličniju
          for (final allowed in allowedCities) {
            if (allowed.contains(normalizedGrad.substring(0, 3))) {
              // Debug output removed
            }
          }
        }
      }
    });
  });
}
