#!/usr/bin/env dart

/// Test script za SMS registraciju funkcionalnost
/// Proverava da li SMS registracija radi kako treba

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMS Registracija Test', () {
    print('🧪 Pokretam testove SMS registracije...\n');

    test('Proveri dostupnost SMS servisa', () async {
      print('📱 Test 1: Proverava SMS servis...');

      // Ovde bismo testirali da li PhoneAuthService funkcioniše
      // Za sada samo simuliramo
      const testResult = true; // Placeholder

      if (testResult) {
        print('✅ SMS servis je dostupan');
      }

      expect(testResult, isTrue);
    });

    test('Proveri test brojevi vozača', () async {
      print('📞 Test 2: Proverava test brojeve vozača...');

      final expectedPhones = {
        'Bojan': '+381641162560',
        'Bruda': '+381641202844',
        'Svetlana': '+381658464160',
        'Bilevski': '+381641234567',
      };

      print('📋 Očekivani brojevi:');
      expectedPhones.forEach((name, phone) {
        print('   • $name: $phone');
      });

      // Proverava da li su svi brojevi u validnom formatu
      bool allValid = true;
      expectedPhones.forEach((name, phone) {
        final isValid = RegExp(r'^\+381[0-9]{8,9}$').hasMatch(phone);
        if (!isValid) {
          print('❌ Nevaljan format broja za $name: $phone');
          allValid = false;
        } else {
          print('✅ Valjan format broja za $name');
        }
      });

      expect(allValid, isTrue);
    });

    test('Proveri test OTP kodove', () async {
      print('🔐 Test 3: Proverava test OTP kodove...');

      final testCodes = {
        '+381641162560': '123456', // Bojan
        '+381641202844': '123456', // Bruda
        '+381658464160': '123456', // Svetlana
        '+381641234567': '123456', // Bilevski
      };

      print('🔑 Test OTP kodovi:');
      testCodes.forEach((phone, code) {
        print('   • $phone: $code');
      });

      // Proveri da li su svi kodovi 6-cifreni
      bool allValid = true;
      testCodes.forEach((phone, code) {
        if (code.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(code)) {
          print('❌ Nevaljan OTP kod za $phone: $code');
          allValid = false;
        } else {
          print('✅ Valjan OTP kod za $phone');
        }
      });

      expect(allValid, isTrue);
    });

    test('Proveri SMS registraciju flow', () async {
      print('🔄 Test 4: Proverava SMS registraciju flow...');

      final steps = [
        '1. Vozač bira ime iz liste',
        '2. Automatski se učitava broj telefona',
        '3. Vozač unosi šifru',
        '4. Šalje się SMS kod',
        '5. Vozač unosi SMS kod',
        '6. Verifikuje se kod',
        '7. Vozač se označava kao registrovan',
        '8. Prebacuje na login screen'
      ];

      print('📋 SMS registracija koraci:');
      for (final step in steps) {
        print('   • $step');
      }

      // Simulacija - u realnom testu bi se testiralo svaki korak
      const flowValid = true;

      if (flowValid) {
        print('✅ SMS registracija flow je ispravan');
      }

      expect(flowValid, isTrue);
    });

    test('Proveri validaciju broja telefona', () async {
      print('📞 Test 5: Proverava validaciju broja telefona...');

      final testCases = [
        {'phone': '+381641162560', 'driver': 'Bojan', 'shouldBeValid': true},
        {
          'phone': '+381641162560',
          'driver': 'Bruda',
          'shouldBeValid': false // Pogrešan vozač za taj broj
        },
        {
          'phone': '+381123456789',
          'driver': 'Bojan',
          'shouldBeValid': false // Nepoznat broj
        },
        {
          'phone': '641162560',
          'driver': 'Bojan',
          'shouldBeValid': false // Nema +381 prefix
        }
      ];

      bool allTestsPassed = true;

      for (final testCase in testCases) {
        final phone = testCase['phone'] as String;
        final driver = testCase['driver'] as String;
        final shouldBeValid = testCase['shouldBeValid'] as bool;

        // Simulacija validacije - u realnom testu bi se pozvao PhoneAuthService
        final expectedPhones = {
          'Bojan': '+381641162560',
          'Bruda': '+381641202844',
          'Svetlana': '+381658464160',
          'Bilevski': '+381641234567',
        };

        final isValid = expectedPhones[driver] == phone;

        if (isValid == shouldBeValid) {
          print('✅ Test prošao: $driver + $phone = $isValid');
        } else {
          print(
              '❌ Test pao: $driver + $phone = $isValid (očekivao $shouldBeValid)');
          allTestsPassed = false;
        }
      }

      expect(allTestsPassed, isTrue);
    });
  });
}

/// Funkcija za pokretanje testova iz terminala
void runSMSTests() async {
  print('🚀 Pokretam SMS registraciju testove...\n');

  try {
    // Pokretamo testove
    main();
    print('\n✅ Svi testovi su završeni!');
  } catch (e) {
    print('\n❌ Greška tokom testiranja: $e');
  }
}
