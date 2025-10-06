import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/putnik.dart';
import 'package:gavra_android/widgets/putnik_card.dart';

void main() {
  group('PutnikCard Payment Display Tests', () {
    testWidgets('should display payment information correctly',
        (WidgetTester tester) async {
      // Test putnik sa plaćanjem kao Ana Cortan
      final testPutnik = Putnik(
        id: 'test-id',
        ime: 'Ana Cortan',
        telefon: '061234567',
        adresaOd: 'Bela Crkva',
        adresaDo: 'Vršac',
        vremeDodavanja: DateTime.now(),
        status: null,
        iznosPlacanja: 13800.0,
        naplatioVozac: 'Svetlana',
        vremePlacanja: DateTime(2025, 10, 6, 15, 30),
        mesecnaKarta: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PutnikCard(
              putnik: testPutnik,
              currentDriver: 'Bojan',
            ),
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
        telefon: '061234567',
        adresaOd: 'Bela Crkva',
        adresaDo: 'Vršac',
        vremeDodavanja: DateTime.now(),
        status: null,
        iznosPlacanja: null,
        naplatioVozac: null,
        vremePlacanja: null,
        mesecnaKarta: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PutnikCard(
              putnik: testPutnik,
              currentDriver: 'Bojan',
            ),
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
        telefon: '061234567',
        adresaOd: 'Bela Crkva',
        adresaDo: 'Vršac',
        vremeDodavanja: DateTime.now(),
        status: null,
        iznosPlacanja: 800.0,
        naplatioVozac: null,
        vremePlacanja: DateTime.now(),
        mesecnaKarta: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PutnikCard(
              putnik: testPutnik,
              currentDriver: 'Bojan',
            ),
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
