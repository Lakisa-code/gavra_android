import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/password_service.dart';
import '../lib/utils/vozac_boja.dart';
import '../lib/services/vozac_mapping_service.dart';

/// Test demonstracija kako se vozači loguju u aplikaciju
void main() {
  group('🔐 Demonstracija login procesa za vozače', () {

    test('📋 Lista svih vozača i njihovih podataka za login', () {
      print('\n🚗 VOZAČI U APLIKACIJI - LOGIN PODACI:');
      print('=' * 60);

      final vozaci = VozacMappingService.getAllVozacNames();

      for (final vozac in vozaci) {
        final uuid = VozacMappingService.getVozacUuid(vozac);
        final boja = VozacBoja.get(vozac);
        final hexBoja = '#${boja.value.toRadixString(16).toUpperCase().padLeft(8, '0')}';

        print('🚗 $vozac');
        print('   UUID: $uuid');
        print('   Boja: $hexBoja');
        print('   Validacija: ${VozacBoja.isValidDriver(vozac)}');
        print('');
      }
    });

    test('🔑 Šifre vozača iz PasswordService', () async {
      print('\n🔐 ŠIFRE VOZAČA (iz PasswordService):');
      print('=' * 50);

      final vozaci = VozacMappingService.getAllVozacNames();

      for (final vozac in vozaci) {
        final sifra = await PasswordService.getPassword(vozac);
        print('🚗 $vozac: Šifra = "$sifra"');
      }

      print('\n💡 NAPOMENA: Ove su default šifre. Vozači mogu promijeniti šifre.');
    });

    group('🎯 KAKO SE VOZAČI LOGUJU - KORAK PO KORAK', () {

      test('1️⃣ Bilevski login proces', () async {
        const vozac = 'Bilevski';
        final sifra = await PasswordService.getPassword(vozac);
        final uuid = VozacMappingService.getVozacUuid(vozac);
        final boja = VozacBoja.get(vozac);

        print('\n🎯 BILEVSKI LOGIN PROCES:');
        print('1. Klikne na dugme "Bilevski" (narandžasto)');
        print('2. Otvori se password dialog sa narandžastim border-om');
        print('3. Unese šifru: "$sifra"');
        print('4. Ako je tačna → login uspješan');
        print('5. Čuva se u SharedPreferences: "current_driver" = "$vozac"');
        print('6. UUID za backend: $uuid');
        print('7. Boja za UI: ${boja.toString()}');
        print('8. Pušta se specijalna pjesma: "bilevski.mp3"');
        print('9. Provjerava se daily check-in');
        print('10. Preusmjerava na HomeScreen');

        expect(sifra, '2222');
        expect(uuid, '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f');
        expect(boja, Color(0xFFFF9800));
      });

      test('2️⃣ Bruda login proces', () async {
        const vozac = 'Bruda';
        final sifra = await PasswordService.getPassword(vozac);
        final uuid = VozacMappingService.getVozacUuid(vozac);
        final boja = VozacBoja.get(vozac);

        print('\n🎯 BRUDA LOGIN PROCES:');
        print('1. Klikne na dugme "Bruda" (ljubičasto)');
        print('2. Otvori se password dialog sa ljubičastim border-om');
        print('3. Unese šifru: "$sifra"');
        print('4. Ako je tačna → login uspješan');
        print('5. Čuva se u SharedPreferences: "current_driver" = "$vozac"');
        print('6. UUID za backend: $uuid');
        print('7. Boja za UI: ${boja.toString()}');
        print('8. Pušta se specijalna pjesma: "bruda.mp3"');
        print('9. Provjerava se daily check-in');
        print('10. Preusmjerava na HomeScreen');

        expect(sifra, '1111');
        expect(uuid, '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f');
        expect(boja, Color(0xFF7C4DFF));
      });

      test('3️⃣ Bojan login proces', () async {
        const vozac = 'Bojan';
        final sifra = await PasswordService.getPassword(vozac);
        final uuid = VozacMappingService.getVozacUuid(vozac);
        final boja = VozacBoja.get(vozac);

        print('\n🎯 BOJAN LOGIN PROCES:');
        print('1. Klikne na dugme "Bojan" (svetla cyan plava)');
        print('2. Otvori se password dialog sa cyan border-om');
        print('3. Unese šifru: "$sifra"');
        print('4. Ako je tačna → login uspješan');
        print('5. Čuva se u SharedPreferences: "current_driver" = "$vozac"');
        print('6. UUID za backend: $uuid');
        print('7. Boja za UI: ${boja.toString()}');
        print('8. Pušta se specijalna pjesma: "gavra.mp3"');
        print('9. Provjerava se daily check-in');
        print('10. Preusmjerava na HomeScreen');

        expect(sifra, '1919');
        expect(uuid, '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e');
        expect(boja, Color(0xFF00E5FF));
      });

      test('4️⃣ Svetlana login proces (specijalni)', () async {
        const vozac = 'Svetlana';
        final sifra = await PasswordService.getPassword(vozac);
        final uuid = VozacMappingService.getVozacUuid(vozac);
        final boja = VozacBoja.get(vozac);

        print('\n💖 SVETLANA LOGIN PROCES (SPECIJALNI):');
        print('1. Klikne na ROZE DIJAMANT dugme sa "S" slovom');
        print('2. Otvori se password dialog sa pastel pink border-om');
        print('3. Unese šifru: "$sifra"');
        print('4. Ako je tačna → login uspješan');
        print('5. Čuva se u SharedPreferences: "current_driver" = "$vozac"');
        print('6. UUID za backend: $uuid');
        print('7. Boja za UI: ${boja.toString()}');
        print('8. Pušta se specijalna pjesma: "svetlana.mp3" ("Hiljson Mandela & Miach - Anđeo")');
        print('9. Provjerava se daily check-in');
        print('10. Preusmjerava na HomeScreen');
        print('');
        print('💎 SVETLANA IMA SPECIJALNI DIJAMANT DUGME - najljepše od svih! ✨');

        expect(sifra, '0013');
        expect(uuid, '5b379394-084e-1c7d-76bf-fc193a5b6c7d');
        expect(boja, Color(0xFFFF1493));
      });
    });

    group('🔄 DODATNE LOGIN OPCIJE', () {

      test('Auto-login funkcionalnost', () {
        print('\n🔄 AUTO-LOGIN FUNKCIONALNOST:');
        print('1. Ako je vozač već logovan (SharedPreferences ima "current_driver")');
        print('2. Automatski se uloguje bez unosa šifre');
        print('3. NE pušta se pjesma pri auto-login-u');
        print('4. Direktno ide na HomeScreen (ili DailyCheckIn ako treba)');
        print('5. Radi samo radnim danima (pon-pet), vikendom preskače check-in');
      });

      test('Daily check-in sistem', () {
        print('\n🌅 DAILY CHECK-IN SISTEM:');
        print('1. Nakon uspješnog login-a, provjerava se da li je vozač uradio check-in danas');
        print('2. Ako NIJE → šalje na DailyCheckInScreen');
        print('3. Ako JESTE → direktno na HomeScreen');
        print('4. Vikendom (subota/nedelja) se preskače check-in');
        print('5. Check-in se radi samo jednom dnevno po vozaču');
      });

      test('SMS Authentication (dodatna opcija)', () {
        print('\n📱 SMS AUTHENTICATION:');
        print('1. Alternativni način prijave');
        print('2. Koristi broj telefona umjesto šifre');
        print('3. Otvara PhoneLoginScreen');
        print('4. Za sada dodatna opcija, ne zamjenjuje password login');
      });

      test('Promjena šifre', () {
        print('\n🔑 PROMJENA ŠIFRE:');
        print('1. U password dialog-u postoji dugme "Promeni šifru"');
        print('2. Otvara ChangePasswordScreen');
        print('3. Vozač može postaviti custom šifru');
        print('4. Custom šifre se čuvaju u SharedPreferences');
        print('5. Ako nema custom šifre, koristi se default');
      });
    });

    group('🛡️ SIGURNOSNE MJERE', () {

      test('Validacija vozača', () {
        print('\n🛡️ VALIDACIJA VOZAČA:');
        print('1. Striktna validacija - samo 4 vozača dozvoljeno');
        print('2. VozacBoja.isValidDriver() provjerava da li je vozač validan');
        print('3. Nevalidni vozači dobijaju error dialog');
        print('4. Spriječava pristup neautorizovanim korisnicima');

        final validni = VozacBoja.validDrivers;
        print('   Validni vozači: $validni');

        final nevalidni = ['Marko', 'Nikola', 'Petar', 'Gavra'];
        for (final vozac in nevalidni) {
          expect(VozacBoja.isValidDriver(vozac), false);
          print('   ❌ $vozac - NEVALIDAN');
        }
      });

      test('Pogrešna šifra handling', () {
        print('\n❌ POGREŠNA ŠIFRA HANDLING:');
        print('1. Ako se unese pogrešna šifra → prikazuje error dialog');
        print('2. "Pogrešna šifra! Molimo pokušajte ponovo."');
        print('3. Vozač ostaje na WelcomeScreen-u');
        print('4. Može pokušati ponovo ili otkazati');
      });
    });

    test('📊 SAŽETAK LOGIN PROCESA', () {
      print('\n📊 SAŽETAK - KAKO SE VOZAČI LOGUJU:');
      print('=' * 60);
      print('🎯 GLAVNI NAČIN: Password dugmad na WelcomeScreen-u');
      print('🔄 AUTO-LOGIN: Automatski za već logovane vozače');
      print('💖 SVETLANA: Specijalno dijamant dugme');
      print('📱 SMS: Alternativna opcija (PhoneLoginScreen)');
      print('');
      print('🚗 VOZAČI: Bilevski, Bruda, Bojan, Svetlana');
      print('🔑 ŠIFRE: Iz PasswordService (mogu se mijenjati)');
      print('🎵 PESME: Svaki vozač ima svoju welcome pjesmu');
      print('🌅 CHECK-IN: Dnevni check-in radnim danima');
      print('🛡️ SIGURNOST: Striktna validacija vozača');
      print('🎨 UI: Svaki vozač ima svoju boju i temu');
    });
  });
}