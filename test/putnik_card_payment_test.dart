import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/putnik.dart';
import 'package:gavra_android/widgets/putnik_card.dart';
import 'test_helpers.dart';

void main() {
  group('PutnikCard Payment Display Tests', () {
    testWidgets('should display payment information correctly',
        (WidgetTester tester) async {
      // Test putnik sa plaćanjem kao Ana Cortan
      final testPutnik = Putnik(
        id: 'test-id',
        ime: 'Ana Cortan',
        polazak: GavraTestConstants.testAddressFrom,
        grad: GavraTestConstants.testAddressTo,
        dan: DateTime.now().toIso8601String().split('T')[0],
        vremeDodavanja: DateTime.now(),
        iznosPlacanja: GavraTestConstants.testAmount,
        naplatioVozac: GavraTestConstants.testDriverSvetlana,
        vremePlacanja: DateTime(2025, 10, 6, 15, 30),
        mesecnaKarta: false,
        brojTelefona: GavraTestConstants.testPhoneNumber,
      );

      await tester.pumpWidget(
        GavraTestHelpers.createTestApp(
          PutnikCard(
            putnik: testPutnik,
            currentDriver: GavraTestConstants.testDriver,
          ),
        ),
      );

      // Proveri da li se prikazuje iznos plaćanja
      expect(find.text('Plaćeno 13800'), findsOneWidget);

      // Proveri da li se prikazuje ko je naplatio sa vremenom
      expect(find.textContaining('Naplatio: Svetlana'), findsOneWidget);
      expect(find.textContaining('15:30'), findsOneWidget);
    });

    testWidgets('should not display payment info when not paid',
        (WidgetTester tester) async {
      // Test putnik bez plaćanja
      final testPutnik = Putnik(
        id: 'test-id-2',
        ime: 'Marko Petrović',
        polazak: 'Bela Crkva',
        grad: 'Vršac',
        dan: DateTime.now().toIso8601String().split('T')[0],
        vremeDodavanja: DateTime.now(),
        mesecnaKarta: false,
        brojTelefona: '061234567',
      );

      await tester.pumpWidget(
        GavraTestHelpers.createTestApp(
          PutnikCard(
            putnik: testPutnik,
            currentDriver: 'Bojan',
          ),
        ),
      );

      // Proveri da se ne prikazuje info o plaćanju
      expect(find.textContaining('Plaćeno'), findsNothing);
      expect(find.textContaining('Naplatio'), findsNothing);
    });

    testWidgets('should display only amount when driver is not specified',
        (WidgetTester tester) async {
      // Test putnik sa plaćanjem ali bez vozača
      final testPutnik = Putnik(
        id: 'test-id-3',
        ime: 'Milica Nikolić',
        polazak: 'Bela Crkva',
        grad: 'Vršac',
        dan: DateTime.now().toIso8601String().split('T')[0],
        vremeDodavanja: DateTime.now(),
        iznosPlacanja: 800.0,
        vremePlacanja: DateTime.now(),
        mesecnaKarta: false,
        brojTelefona: '061234567',
      );

      await tester.pumpWidget(
        GavraTestHelpers.createTestApp(
          PutnikCard(
            putnik: testPutnik,
            currentDriver: 'Bojan',
          ),
        ),
      );

      // Proveri da se prikazuje samo iznos
      expect(find.text('Plaćeno 800'), findsOneWidget);

      // Proveri da se ne prikazuje vozač info
      expect(find.textContaining('Naplatio'), findsNothing);
    });
  });
}
