import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test utilities za Gavra aplikaciju
class GavraTestHelpers {
  /// Kreira test MaterialApp wrapper
  static Widget createTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Kreira mock Putnik za testiranje
  static Map<String, dynamic> createMockPutnik({
    String? id,
    String? ime,
    double? iznosPlacanja,
    String? naplatioVozac,
    DateTime? vremePlacanja,
    bool mesecnaKarta = false,
  }) {
    return {
      'id': id ?? 'test-id',
      'ime': ime ?? 'Test Putnik',
      'telefon': '061234567',
      'adresa_od': 'Bela Crkva',
      'adresa_do': 'Vršac',
      'vreme_dodavanja': DateTime.now().toIso8601String(),
      'iznos_placanja': iznosPlacanja,
      'naplatio_vozac': naplatioVozac,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'mesecna_karta': mesecnaKarta,
      'status': null,
    };
  }

  /// Kreira mock MesecniPutnik za testiranje
  static Map<String, dynamic> createMockMesecniPutnik({
    String? id,
    String? putnikIme,
    double? cena,
    String? vozac,
    DateTime? vremePlacanja,
  }) {
    return {
      'id': id ?? 'test-mesecni-id',
      'putnik_ime': putnikIme ?? 'Test Mesecni',
      'tip': 'srednjoskolac',
      'polasci_po_danu': {
        'pon': {'bc': '07:00', 'vs': '14:00'},
        'uto': {'bc': '07:00', 'vs': '14:00'},
      },
      'cena': cena,
      'vozac': vozac,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'aktivan': true,
      'radni_dani': 'pon,uto,sre,cet,pet',
      'datum_pocetka_meseca': DateTime.now().toIso8601String(),
      'datum_kraja_meseca':
          DateTime.now().add(Duration(days: 30)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Asinkrono čeka da se widget build završi
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Pronalazi widget po tekstu
  static Finder findTextWidget(String text) {
    return find.text(text);
  }

  /// Pronalazi widget koji sadrži tekst
  static Finder findTextContaining(String text) {
    return find.textContaining(text);
  }

  /// Debug helper - prikazuje sav tekst u widget tree-u
  static void printAllText(WidgetTester tester) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    print('=== TEXT WIDGETS ===');
    for (final text in textWidgets) {
      print('Text: "${text.data}"');
    }
    print('===================');
  }

  /// Proveri da li se amount prikazuje u formatu "Plaćeno {amount}"
  static void expectPaymentDisplayed(double amount) {
    expect(find.text('Plaćeno ${amount.toStringAsFixed(0)}'), findsOneWidget);
  }

  /// Proveri da li se vozač prikazuje u formatu "Naplatio: {vozac}"
  static void expectDriverDisplayed(String vozac) {
    expect(find.textContaining('Naplatio: $vozac'), findsOneWidget);
  }

  /// Mock Timer za testiranje real-time funkcionalnosti
  static void mockTimer(Duration duration, VoidCallback callback) {
    Future.delayed(duration, callback);
  }
}

/// Konstante za testiranje
class GavraTestConstants {
  static const String testDriver = 'Bojan';
  static const String testDriverSvetlana = 'Svetlana';
  static const double testAmount = 13800.0;
  static const String testPhoneNumber = '061234567';
  static const String testAddressFrom = 'Bela Crkva';
  static const String testAddressTo = 'Vršac';
}
