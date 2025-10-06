import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/vozac_mapping_service.dart';
import 'package:gavra_android/services/password_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test integracijska provjera za svakog vozača posebno
/// da odgovara stvarnim podacima iz welcome_screen.dart i password_service.dart
void main() {
  setUpAll(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
  });
  group('🔧 Integracija sa stvarnim aplikacijskim podacima', () {
    test('🔍 Provjera da svi vozači iz PasswordService postoje u VozacMapping',
        () {
      final passwordDrivers = PasswordService.getAllDrivers();
      print('🚗 Vozači iz PasswordService: $passwordDrivers');

      for (final driverName in passwordDrivers) {
        final uuid = VozacMappingService.getVozacUuid(driverName);
        print('   $driverName → UUID: $uuid');
        expect(
          uuid,
          isNotNull,
          reason: 'Vozač $driverName mora imati UUID u VozacMappingService',
        );
      }
    });

    test(
        '🔍 Provjera da svi vozači iz VozacMapping imaju šifre u PasswordService',
        () {
      final mappingDrivers = VozacMappingService.getAllVozacNames();
      final passwordDrivers = PasswordService.getAllDrivers();

      print('🚗 Vozači iz VozacMapping: $mappingDrivers');
      print('🔐 Vozači iz PasswordService: $passwordDrivers');

      for (final driverName in mappingDrivers) {
        expect(
          passwordDrivers,
          contains(driverName),
          reason:
              'Vozač $driverName iz VozacMapping mora imati šifru u PasswordService',
        );
      }
    });

    group('🔍 Test za svaki vozač posebno - STVARNI PODACI', () {
      test('BILEVSKI - potpuna provjera', () async {
        // 1. UUID mapiranje
        final uuid = VozacMappingService.getVozacUuid('Bilevski');
        expect(uuid, '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f');

        // 2. Obrnuto mapiranje
        final ime = VozacMappingService.getVozacIme(uuid!);
        expect(ime, 'Bilevski');

        // 3. Fallback funkcija
        final fallbackIme = VozacMappingService.getVozacImeWithFallback(uuid);
        expect(fallbackIme, 'Bilevski');

        // 4. Šifra iz PasswordService
        final password = await PasswordService.getPassword('Bilevski');
        expect(password, '2222');

        // 5. Validacija
        expect(VozacMappingService.isValidVozacIme('Bilevski'), true);
        expect(VozacMappingService.isValidVozacUuid(uuid), true);

        print('✅ BILEVSKI: UUID=$uuid, Šifra=$password');
      });

      test('BRUDA - potpuna provjera', () async {
        // 1. UUID mapiranje
        final uuid = VozacMappingService.getVozacUuid('Bruda');
        expect(uuid, '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f');

        // 2. Obrnuto mapiranje
        final ime = VozacMappingService.getVozacIme(uuid!);
        expect(ime, 'Bruda');

        // 3. Fallback funkcija
        final fallbackIme = VozacMappingService.getVozacImeWithFallback(uuid);
        expect(fallbackIme, 'Bruda');

        // 4. Šifra iz PasswordService
        final password = await PasswordService.getPassword('Bruda');
        expect(password, '1111');

        // 5. Validacija
        expect(VozacMappingService.isValidVozacIme('Bruda'), true);
        expect(VozacMappingService.isValidVozacUuid(uuid), true);

        print('✅ BRUDA: UUID=$uuid, Šifra=$password');
      });

      test('BOJAN - potpuna provjera', () async {
        // 1. UUID mapiranje
        final uuid = VozacMappingService.getVozacUuid('Bojan');
        expect(uuid, '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e');

        // 2. Obrnuto mapiranje
        final ime = VozacMappingService.getVozacIme(uuid!);
        expect(ime, 'Bojan');

        // 3. Fallback funkcija
        final fallbackIme = VozacMappingService.getVozacImeWithFallback(uuid);
        expect(fallbackIme, 'Bojan');

        // 4. Šifra iz PasswordService
        final password = await PasswordService.getPassword('Bojan');
        expect(password, '1919');

        // 5. Validacija
        expect(VozacMappingService.isValidVozacIme('Bojan'), true);
        expect(VozacMappingService.isValidVozacUuid(uuid), true);

        print('✅ BOJAN: UUID=$uuid, Šifra=$password');
      });

      test('SVETLANA - potpuna provjera', () async {
        // 1. UUID mapiranje
        final uuid = VozacMappingService.getVozacUuid('Svetlana');
        expect(uuid, '5b379394-084e-1c7d-76bf-fc193a5b6c7d');

        // 2. Obrnuto mapiranje
        final ime = VozacMappingService.getVozacIme(uuid!);
        expect(ime, 'Svetlana');

        // 3. Fallback funkcija
        final fallbackIme = VozacMappingService.getVozacImeWithFallback(uuid);
        expect(fallbackIme, 'Svetlana');

        // 4. Šifra iz PasswordService
        final password = await PasswordService.getPassword('Svetlana');
        expect(password, '0013');

        // 5. Validacija
        expect(VozacMappingService.isValidVozacIme('Svetlana'), true);
        expect(VozacMappingService.isValidVozacUuid(uuid), true);

        print('✅ SVETLANA: UUID=$uuid, Šifra=$password');
      });
    });

    test('📊 Sažetak svih vozača', () {
      print('\n📊 SAŽETAK SVIH VOZAČA:');
      print('=' * 50);

      final vozaci = VozacMappingService.getAllVozacNames();
      for (final vozac in vozaci) {
        final uuid = VozacMappingService.getVozacUuid(vozac);
        print('🚗 $vozac');
        print('   UUID: $uuid');
        print('   Validno ime: ${VozacMappingService.isValidVozacIme(vozac)}');
        print(
          '   Validno UUID: ${VozacMappingService.isValidVozacUuid(uuid!)}',
        );
        print(
          '   Fallback test: ${VozacMappingService.getVozacImeWithFallback(uuid)}',
        );
        print('');
      }
    });
  });
}
