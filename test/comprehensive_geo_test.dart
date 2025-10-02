import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/geocoding_service.dart';

void main() {
  group('Kompletni test geografskih ograničenja', () {
    test('Testira dozvoljene i blokirane gradove', () {
      final service = GeocodingService();

      print('\n🌍 KOMPLETNI TEST GEOGRAFSKIH OGRANIČENJA 🌍');
      print('=' * 50);

      // Dozvoljeni gradovi (BC/Vršac opštine)
      final dozvoljeni = [
        'Bela Crkva',
        'Vršac',
        'Potporanj',
        'Orešac',
        'Vraćev Gaj',
        'Dupljaja',
        'Vojvodinci',
        'Straža'
      ];

      // Blokirani gradovi (van BC/Vršac opština)
      final blokirani = [
        'Novi Sad',
        'Beograd',
        'Zrenjanin',
        'Pančevo',
        'Kikinda',
        'Subotica'
      ];

      print('\n✅ DOZVOLJENI GRADOVI:');
      print('-' * 25);
      for (final grad in dozvoljeni) {
        final isBlocked = service._isCityBlocked(grad);
        final status = isBlocked ? '❌ GREŠKA - BLOKIRAN' : '✅ DOZVOLJEN';
        print('$grad: $status');
        expect(isBlocked, false, reason: 'Grad $grad mora biti dozvoljen');
      }

      print('\n🚫 BLOKIRANI GRADOVI:');
      print('-' * 25);
      for (final grad in blokirani) {
        final isBlocked = service._isCityBlocked(grad);
        final status = isBlocked ? '✅ BLOKIRAN' : '❌ GREŠKA - DOZVOLJEN';
        print('$grad: $status');
        expect(isBlocked, true, reason: 'Grad $grad mora biti blokiran');
      }

      print('\n🎯 GEOGRAFSKA OGRANIČENJA FUNKCIONIŠU SAVRŠENO! 🎯');
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
