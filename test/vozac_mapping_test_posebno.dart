import 'package:flutter_test/flutter_test.dart';
import '../lib/services/vozac_mapping_service.dart';

/// Test implementacije logike i funkcija za svakog vozača posebno
void main() {
  group('🚗 Implementacija za svakog vozača posebno', () {
    
    // Test podataka za svakog vozača
    final Map<String, String> expectedMapping = {
      'Bilevski': '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
      'Bruda': '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f', 
      'Bojan': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
      'Svetlana': '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
    };

    group('🔍 Test za BILEVSKOG', () {
      test('Bilevski - mapiranje ime → UUID', () {
        final uuid = VozacMappingService.getVozacUuid('Bilevski');
        expect(uuid, expectedMapping['Bilevski']);
        expect(uuid, '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f');
      });

      test('Bilevski - mapiranje UUID → ime', () {
        final ime = VozacMappingService.getVozacIme('8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f');
        expect(ime, 'Bilevski');
      });

      test('Bilevski - fallback funkcija', () {
        final ime = VozacMappingService.getVozacImeWithFallback('8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f');
        expect(ime, 'Bilevski');
      });

      test('Bilevski - validacija imena', () {
        expect(VozacMappingService.isValidVozacIme('Bilevski'), true);
        expect(VozacMappingService.isValidVozacIme('bilevski'), false); // case sensitive
      });

      test('Bilevski - validacija UUID-a', () {
        expect(VozacMappingService.isValidVozacUuid('8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f'), true);
      });
    });

    group('🔍 Test za BRUDU', () {
      test('Bruda - mapiranje ime → UUID', () {
        final uuid = VozacMappingService.getVozacUuid('Bruda');
        expect(uuid, expectedMapping['Bruda']);
        expect(uuid, '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f');
      });

      test('Bruda - mapiranje UUID → ime', () {
        final ime = VozacMappingService.getVozacIme('7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f');
        expect(ime, 'Bruda');
      });

      test('Bruda - fallback funkcija', () {
        final ime = VozacMappingService.getVozacImeWithFallback('7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f');
        expect(ime, 'Bruda');
      });

      test('Bruda - validacija imena', () {
        expect(VozacMappingService.isValidVozacIme('Bruda'), true);
        expect(VozacMappingService.isValidVozacIme('bruda'), false); // case sensitive
      });

      test('Bruda - validacija UUID-a', () {
        expect(VozacMappingService.isValidVozacUuid('7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f'), true);
      });
    });

    group('🔍 Test za BOJANA', () {
      test('Bojan - mapiranje ime → UUID', () {
        final uuid = VozacMappingService.getVozacUuid('Bojan');
        expect(uuid, expectedMapping['Bojan']);
        expect(uuid, '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e');
      });

      test('Bojan - mapiranje UUID → ime', () {
        final ime = VozacMappingService.getVozacIme('6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e');
        expect(ime, 'Bojan');
      });

      test('Bojan - fallback funkcija', () {
        final ime = VozacMappingService.getVozacImeWithFallback('6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e');
        expect(ime, 'Bojan');
      });

      test('Bojan - validacija imena', () {
        expect(VozacMappingService.isValidVozacIme('Bojan'), true);
        expect(VozacMappingService.isValidVozacIme('bojan'), false); // case sensitive
      });

      test('Bojan - validacija UUID-a', () {
        expect(VozacMappingService.isValidVozacUuid('6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e'), true);
      });
    });

    group('🔍 Test za SVETLANU', () {
      test('Svetlana - mapiranje ime → UUID', () {
        final uuid = VozacMappingService.getVozacUuid('Svetlana');
        expect(uuid, expectedMapping['Svetlana']);
        expect(uuid, '5b379394-084e-1c7d-76bf-fc193a5b6c7d');
      });

      test('Svetlana - mapiranje UUID → ime', () {
        final ime = VozacMappingService.getVozacIme('5b379394-084e-1c7d-76bf-fc193a5b6c7d');
        expect(ime, 'Svetlana');
      });

      test('Svetlana - fallback funkcija', () {
        final ime = VozacMappingService.getVozacImeWithFallback('5b379394-084e-1c7d-76bf-fc193a5b6c7d');
        expect(ime, 'Svetlana');
      });

      test('Svetlana - validacija imena', () {
        expect(VozacMappingService.isValidVozacIme('Svetlana'), true);
        expect(VozacMappingService.isValidVozacIme('svetlana'), false); // case sensitive
      });

      test('Svetlana - validacija UUID-a', () {
        expect(VozacMappingService.isValidVozacUuid('5b379394-084e-1c7d-76bf-fc193a5b6c7d'), true);
      });
    });

    group('❌ Test nevalidnih podataka', () {
      test('Nepoznato ime vozača', () {
        final uuid = VozacMappingService.getVozacUuid('Marko');
        expect(uuid, null);
      });

      test('Nepoznat UUID', () {
        final ime = VozacMappingService.getVozacIme('11111111-1111-1111-1111-111111111111');
        expect(ime, null);
      });

      test('Fallback za null UUID', () {
        final ime = VozacMappingService.getVozacImeWithFallback(null);
        expect(ime, 'Nepoznat');
      });

      test('Fallback za prazan UUID', () {
        final ime = VozacMappingService.getVozacImeWithFallback('');
        expect(ime, 'Nepoznat');
      });

      test('Fallback za nepoznat UUID', () {
        final ime = VozacMappingService.getVozacImeWithFallback('99999999-9999-9999-9999-999999999999');
        expect(ime, 'Nepoznat');
      });
    });

    group('📋 Test listova i općenite funkcionalnosti', () {
      test('Lista svih imena vozača', () {
        final imena = VozacMappingService.getAllVozacNames();
        expect(imena.length, 4);
        expect(imena, containsAll(['Bilevski', 'Bruda', 'Bojan', 'Svetlana']));
      });

      test('Lista svih UUID-ova', () {
        final uuids = VozacMappingService.getAllVozacUuids();
        expect(uuids.length, 4);
        expect(uuids, containsAll([
          '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
          '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f',
          '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
          '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
        ]));
      });

      test('Provjera da svi UUID-ovi u listi postoje u mapiranju', () {
        final imena = VozacMappingService.getAllVozacNames();
        final uuids = VozacMappingService.getAllVozacUuids();
        
        for (final ime in imena) {
          final uuid = VozacMappingService.getVozacUuid(ime);
          expect(uuid, isNotNull);
          expect(uuids, contains(uuid));
        }
      });

      test('Obrnut test - svi UUID-ovi vraćaju validna imena', () {
        final uuids = VozacMappingService.getAllVozacUuids();
        final imena = VozacMappingService.getAllVozacNames();
        
        for (final uuid in uuids) {
          final ime = VozacMappingService.getVozacIme(uuid);
          expect(ime, isNotNull);
          expect(imena, contains(ime));
        }
      });
    });

    group('🔄 Test bi-direkcionalne konzistentnosti', () {
      test('Bilevski - ime → UUID → ime', () {
        final originalIme = 'Bilevski';
        final uuid = VozacMappingService.getVozacUuid(originalIme);
        final finalIme = VozacMappingService.getVozacIme(uuid!);
        expect(finalIme, originalIme);
      });

      test('Bruda - ime → UUID → ime', () {
        final originalIme = 'Bruda';
        final uuid = VozacMappingService.getVozacUuid(originalIme);
        final finalIme = VozacMappingService.getVozacIme(uuid!);
        expect(finalIme, originalIme);
      });

      test('Bojan - ime → UUID → ime', () {
        final originalIme = 'Bojan';
        final uuid = VozacMappingService.getVozacUuid(originalIme);
        final finalIme = VozacMappingService.getVozacIme(uuid!);
        expect(finalIme, originalIme);
      });

      test('Svetlana - ime → UUID → ime', () {
        final originalIme = 'Svetlana';
        final uuid = VozacMappingService.getVozacUuid(originalIme);
        final finalIme = VozacMappingService.getVozacIme(uuid!);
        expect(finalIme, originalIme);
      });
    });
  });
}