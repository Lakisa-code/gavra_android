import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/vozac_boja.dart';

/// Test konzistentnosti boja vozača između welcome_screen.dart i admin_map_screen.dart
void main() {
  group('🔄 Konzistentnost boja između ekrana', () {

    // Boje iz welcome_screen.dart (_drivers lista)
    final Map<String, Color> welcomeScreenColors = {
      'Bilevski': const Color(0xFFFF9800), // narandžasta
      'Bruda': const Color(0xFF7C4DFF),    // ljubičasta
      'Bojan': const Color(0xFF00E5FF),    // svetla cyan plava
      // Svetlana nema boju u welcome_screen.dart!
    };

    // Boje iz admin_map_screen.dart (_getDriverColor funkcija)
    final Map<String, Color> adminMapColors = {
      'Bojan': const Color(0xFF00E5FF),    // svetla cyan plava
      'Svetlana': const Color(0xFFFF1493), // deep pink
      'Bruda': const Color(0xFF7C4DFF),    // ljubičasta
      'Bilevski': const Color(0xFFFF9800), // narandžasta
    };

    test('VozacBoja se slaže sa welcome_screen.dart', () {
      for (final entry in welcomeScreenColors.entries) {
        final vozac = entry.key;
        final expectedColor = entry.value;
        final actualColor = VozacBoja.get(vozac);

        expect(actualColor, expectedColor,
            reason: 'Boja za $vozac u VozacBoja ne odgovara welcome_screen.dart');
      }
    });

    test('VozacBoja se slaže sa admin_map_screen.dart', () {
      for (final entry in adminMapColors.entries) {
        final vozac = entry.key;
        final expectedColor = entry.value;
        final actualColor = VozacBoja.get(vozac);

        expect(actualColor, expectedColor,
            reason: 'Boja za $vozac u VozacBoja ne odgovara admin_map_screen.dart');
      }
    });

    test('Svetlana ima boju u admin_map_screen.dart ali ne u welcome_screen.dart', () {
      final svetlanaColor = VozacBoja.get('Svetlana');
      expect(svetlanaColor, const Color(0xFFFF1493)); // deep pink

      // Provjeri da je konzistentna sa admin_map_screen.dart
      expect(svetlanaColor, adminMapColors['Svetlana']);
    });

    test('Svi vozači iz VozacBoja postoje u barem jednom ekranu', () {
      final vozacBojaDrivers = VozacBoja.validDrivers;

      for (final driver in vozacBojaDrivers) {
        final inWelcome = welcomeScreenColors.containsKey(driver);
        final inAdminMap = adminMapColors.containsKey(driver);

        expect(inWelcome || inAdminMap, true,
            reason: 'Vozač $driver iz VozacBoja mora postojati u barem jednom ekranu');
      }
    });

    test('Provjera da li postoje boje koje se ne koriste', () {
      print('\n🔍 ANALIZA KONZISTENTNOSTI BOJA:');
      print('=' * 60);

      final vozacBojaDrivers = VozacBoja.validDrivers;

      for (final driver in vozacBojaDrivers) {
        final vozacBojaColor = VozacBoja.get(driver);
        final welcomeColor = welcomeScreenColors[driver];
        final adminColor = adminMapColors[driver];

        print('🚗 $driver:');
        print('   VozacBoja: ${vozacBojaColor.toString()}');
        print('   WelcomeScreen: ${welcomeColor?.toString() ?? "NEMA"}');
        print('   AdminMap: ${adminColor?.toString() ?? "NEMA"}');

        // Provjeri konzistentnost
        if (welcomeColor != null) {
          expect(vozacBojaColor, welcomeColor,
              reason: '$driver: VozacBoja != WelcomeScreen');
        }
        if (adminColor != null) {
          expect(vozacBojaColor, adminColor,
              reason: '$driver: VozacBoja != AdminMap');
        }

        print('   ✅ Konzistentno');
        print('');
      }
    });

    test('Svetlana - specijalni slučaj (nema boju u welcome_screen.dart)', () {
      final svetlanaColor = VozacBoja.get('Svetlana');
      final adminMapColor = adminMapColors['Svetlana'];

      expect(svetlanaColor, adminMapColor,
          reason: 'Svetlana mora imati konzistentnu boju sa admin_map_screen.dart');

      expect(welcomeScreenColors.containsKey('Svetlana'), false,
          reason: 'Svetlana ne smije imati boju u welcome_screen.dart (po dizajnu)');

      print('💖 SVETLANA: Ima boju samo u admin_map_screen.dart - to je OK!');
    });
  });
}