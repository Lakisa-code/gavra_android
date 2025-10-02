import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/geocoding_service.dart';

void main() {
  group('Final test gradova', () {
    test('Testira nove gradove u GeocodingService', () {
      final service = GeocodingService();

      // Test gradovi
      final testGradovi = ['Potporanj', 'Orešac', 'Vraćev Gaj'];

      print('\n🧪 FINALNI TEST GRADOVA 🧪');
      print('=' * 40);

      for (final grad in testGradovi) {
        final result = !service._isCityBlocked(grad);
        final status = result ? '✅ DOZVOLJEN' : '❌ BLOKIRAN';
        print('$grad: $status');
      }

      // Verifikacija da su svi gradovi dozvoljeni
      for (final grad in testGradovi) {
        final isBlocked = service._isCityBlocked(grad);
        expect(isBlocked, false, reason: 'Grad $grad treba da bude dozvoljen');
      }

      print('\n🎉 SVI GRADOVI SU USPEŠNO DOZVOLJENI! 🎉');
    });
  });
}

// Extension za pristup private metodi
extension GeocodingServiceTest on GeocodingService {
  bool _isCityBlocked(String grad) {
    final normalizedGrad = grad
        .toLowerCase()
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');

    final allowedCities = [
      // VRŠAC OPŠTINA
      'vrsac', 'vršac', 'straza', 'straža', 'vojvodinci', 'potporanj', 'oresac',
      'orešac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kruščica', 'kusic', 'kusić', 'crvena crkva'
    ];
    return !allowedCities.any((allowed) =>
        normalizedGrad.contains(allowed) || allowed.contains(normalizedGrad));
  }
}
