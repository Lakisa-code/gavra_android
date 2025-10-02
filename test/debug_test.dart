import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debug test', () {
    test('Debug normalizacija', () async {
      // Test funkcija da vidim šta se dešava
      final testGradovi = ['Potporanj', 'Orešac', 'Vraćev Gaj'];

      for (final grad in testGradovi) {
        final normalizedGrad = grad.toLowerCase().trim();
        print('$grad -> normalized: "$normalizedGrad"');

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
            print('  ✅ Match found with: "$allowed"');
            found = true;
            break;
          }
        }

        if (!found) {
          print('  ❌ No match found');
          // Pokušaj da nađem najsličniju
          for (final allowed in allowedCities) {
            if (allowed.contains(normalizedGrad.substring(0, 3))) {
              print('    Similar: "$allowed"');
            }
          }
        }
      }
    });
  });
}
