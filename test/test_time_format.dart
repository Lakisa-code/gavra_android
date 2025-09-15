import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  group('Time formatting tests', () {
    test('_formatTimeString should remove seconds', () {
      // Simuliramo da imamo putnika sa vremenima iz baze
      final putnik = MesecniPutnik(
        id: 'test',
        putnikIme: 'Test Putnik',
        tip: 'test',
        polazakBcPon: '12:00:00', // Kao što dolazi iz baze
        polazakBcCet: '11:00:00', // Kao što dolazi iz baze
        datumPocetkaMeseca: DateTime.now(),
        datumKrajaMeseca: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Proveri da li se vremena formatiraju bez sekundi
      expect(putnik.getPolazakBelaCrkvaZaDan('pon'), equals('12:00'));
      expect(putnik.getPolazakBelaCrkvaZaDan('cet'), equals('11:00'));

      // Proveri da li null vrednosti rade
      expect(putnik.getPolazakBelaCrkvaZaDan('uto'), isNull);
    });

    test('_formatTimeString should handle different formats', () {
      final putnik = MesecniPutnik(
        id: 'test',
        putnikIme: 'Test Putnik',
        tip: 'test',
        polazakBcPon: '12:00', // Već formatiran
        polazakBcUto: '09:30:00', // Sa sekundama
        polazakBcSre: '', // Prazan string
        datumPocetkaMeseca: DateTime.now(),
        datumKrajaMeseca: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(putnik.getPolazakBelaCrkvaZaDan('pon'), equals('12:00'));
      expect(putnik.getPolazakBelaCrkvaZaDan('uto'), equals('09:30'));
      expect(putnik.getPolazakBelaCrkvaZaDan('sre'), isNull);
    });
  });
}
