import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gavra_android/services/phone_auth_service.dart';
import 'package:gavra_android/services/vozac_registracija_service.dart';

void main() {
  group('SMS Registracija Tests', () {
    setUp(() {
      // Setup za testove
      SharedPreferences.setMockInitialValues({});
    });

    test('PhoneAuthService - Pronalazi vozača po broju telefona', () {
      // Test da li helper funkcija radi
      expect(PhoneAuthService.getDriverPhone('Bojan'), '+381641162560');
      expect(PhoneAuthService.getDriverPhone('Bruda'), '+381641202844');
      expect(PhoneAuthService.getDriverPhone('Svetlana'), '+381658464160');
      expect(PhoneAuthService.getDriverPhone('Bilevski'), '+381641234567');
      expect(PhoneAuthService.getDriverPhone('NepoznatVozač'), null);
    });

    test('PhoneAuthService - Validira format broja telefona', () {
      // Test validacije broja telefona
      expect(PhoneAuthService.isValidPhoneFormat('+381641162560'), true);
      expect(PhoneAuthService.isValidPhoneFormat('+381658464160'), true);
      expect(
          PhoneAuthService.isValidPhoneFormat('641162560'), false); // Nema +381
      expect(PhoneAuthService.isValidPhoneFormat('+3816411625'),
          false); // Prekratak (7 cifara)
      expect(PhoneAuthService.isValidPhoneFormat('+3816411625601'),
          false); // Predugačak
      expect(PhoneAuthService.isValidPhoneFormat('+38264162560'),
          false); // Pogrešan prefix
    });

    test('PhoneAuthService - Formatra broj telefona', () {
      // Test formatiranja broja
      expect(
          PhoneAuthService.formatPhoneNumber('+381641162560'), '+381641162560');
      expect(PhoneAuthService.formatPhoneNumber('641162560'), '+381641162560');
    });

    test('PhoneAuthService - Dohvata sve vozače za registraciju', () {
      // Test liste vozača
      final drivers = PhoneAuthService.getAllDriversForRegistration();
      expect(drivers, contains('Bojan'));
      expect(drivers, contains('Bruda'));
      expect(drivers, contains('Svetlana'));
      expect(drivers, contains('Bilevski'));
      expect(drivers.length, 4);
    });

    test('PhoneAuthService - Test OTP kodovi', () {
      // Test test kodova
      expect(PhoneAuthService.getTestOTPCode('+381641162560'), '123456');
      expect(PhoneAuthService.getTestOTPCode('+381641202844'), '123456');
      expect(PhoneAuthService.getTestOTPCode('+381658464160'), '123456');
      expect(PhoneAuthService.getTestOTPCode('+381641234567'), '123456');
      expect(PhoneAuthService.getTestOTPCode('+381999999999'),
          null); // Nepoznat broj
    });

    test('PhoneAuthService - Prepoznaje poznate test brojeve', () {
      // Test da li prepoznaje poznate brojeve
      expect(PhoneAuthService.isKnownTestNumber('+381641162560'), true);
      expect(PhoneAuthService.isKnownTestNumber('+381641202844'), true);
      expect(PhoneAuthService.isKnownTestNumber('+381658464160'), true);
      expect(PhoneAuthService.isKnownTestNumber('+381641234567'), true);
      expect(PhoneAuthService.isKnownTestNumber('+381999999999'), false);
    });

    test('PhoneAuthService - Generiše development poruku', () {
      // Test development poruke
      final message1 = PhoneAuthService.getTestCodeMessage('+381641162560');
      expect(message1, 'DEVELOPMENT: Test kod za Bojan je: 123456');

      final message2 = PhoneAuthService.getTestCodeMessage('+381641202844');
      expect(message2, 'DEVELOPMENT: Test kod za Bruda je: 123456');

      final message3 = PhoneAuthService.getTestCodeMessage('+381999999999');
      expect(message3, null); // Nepoznat broj
    });

    test('VozacRegistracijaService - Validira broj telefona za vozača', () {
      // Test validacije broja za vozača
      expect(
          VozacRegistracijaService.isBrojTelefonaValidanZaVozaca(
              'Bojan', '+381641162560'),
          true);
      expect(
          VozacRegistracijaService.isBrojTelefonaValidanZaVozaca(
              'Bojan', '+381641202844'),
          false); // Pogrešan broj
      expect(
          VozacRegistracijaService.isBrojTelefonaValidanZaVozaca(
              'NepoznatVozač', '+381641162560'),
          false); // Nepoznat vozač
    });

    test('VozacRegistracijaService - Proverava SMS registraciju status',
        () async {
      // Test inicijalno stanje - nijedan vozač nije registrovan
      expect(await VozacRegistracijaService.isVozacRegistrovan('Bojan'), false);
      expect(await VozacRegistracijaService.isVozacRegistrovan('Bruda'), false);

      // Test da li treba SMS registracija
      expect(
          await VozacRegistracijaService.trebaSMSRegistracija('Bojan'), true);
      expect(
          await VozacRegistracijaService.trebaSMSRegistracija('NepoznatVozač'),
          false); // Nema broj
    });

    test('VozacRegistracijaService - Označava vozača kao registrovanog',
        () async {
      // Test označavanja vozača kao registrovanog
      await VozacRegistracijaService.oznaciVozacaKaoRegistrovanog('Bojan');

      expect(await VozacRegistracijaService.isVozacRegistrovan('Bojan'), true);
      expect(
          await VozacRegistracijaService.trebaSMSRegistracija('Bojan'), false);

      // Proveri da li je sačuvan datum registracije
      final datum =
          await VozacRegistracijaService.getDatumSMSRegistracije('Bojan');
      expect(datum, isNotNull);
      expect(datum!.day, DateTime.now().day); // Trebalo bi biti danas
    });

    test('VozacRegistracijaService - Dohvata registrovane vozače', () async {
      // Označi nekoliko vozača kao registrovane
      await VozacRegistracijaService.oznaciVozacaKaoRegistrovanog('Bojan');
      await VozacRegistracijaService.oznaciVozacaKaoRegistrovanog('Svetlana');

      final registrovani =
          await VozacRegistracijaService.getRegistrovaneVozace();
      expect(registrovani, contains('Bojan'));
      expect(registrovani, contains('Svetlana'));
      expect(registrovani, isNot(contains('Bruda'))); // Nije registrovan
    });

    test('VozacRegistracijaService - Resetuje SMS registraciju', () async {
      // Prvo registruj vozača
      await VozacRegistracijaService.oznaciVozacaKaoRegistrovanog('Bojan');
      expect(await VozacRegistracijaService.isVozacRegistrovan('Bojan'), true);

      // Zatim resetuj
      await VozacRegistracijaService.resetSMSRegistraciju('Bojan');
      expect(await VozacRegistracijaService.isVozacRegistrovan('Bojan'), false);
      expect(await VozacRegistracijaService.getDatumSMSRegistracije('Bojan'),
          null);
    });
  });
}
