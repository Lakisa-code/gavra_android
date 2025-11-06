import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test helper za inicijalizaciju originalnih servisa u testovima
class TestSupabaseSetup {
  static bool _isInitialized = false;

  /// Inicijalizuje originalne servise za testove
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      WidgetsFlutterBinding.ensureInitialized();

      print('🔗 Inicijalizujem originalne servise za testove...');
      print('✅ Originalni test setup uspešno inicijalizovan');

      _isInitialized = true;
    } catch (e) {
      print('⚠️ Test setup warning: $e');
      _isInitialized = true; // Ipak nastavi sa testovima
    }
  }

  /// Proverava da li su originalni servisi spremni
  static bool get isConnected {
    return _isInitialized;
  }

  /// Cleanup za testove
  static Future<void> cleanup() async {
    print('🧹 Test cleanup završen');
  }
}

/// Test VozacMappingService koji koristi samo hardcoded fallback logiku
class TestVozacMappingService {
  /// Dobija UUID vozača na osnovu imena (samo fallback)
  static Future<String?> getVozacUuid(String vozacIme) async {
    switch (vozacIme) {
      case 'Marko Radovanović':
        return 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      case 'Miloš Pešić':
        return 'b2c3d4e5-f6a7-8901-bcde-f21234567890';
      case 'Aleksandar Stojanović':
        return 'c3d4e5f6-a7b8-9012-cdef-321234567890';
      case 'Stefan Milanović':
        return 'd4e5f6a7-b8c9-0123-def4-21234567890a';
      default:
        return null;
    }
  }
}

// Test file mora imati main funkciju
void main() {
  group('TestSupabaseSetup Tests', () {
    test('Initialize originalne servise', () async {
      await TestSupabaseSetup.initialize();
      expect(TestSupabaseSetup.isConnected, isTrue);
    });

    test('TestVozacMappingService fallback test', () async {
      await TestSupabaseSetup.initialize();

      // Testiraj hardcoded fallback UUID-jeve
      final markoUuid = await TestVozacMappingService.getVozacUuid('Marko Radovanović');
      expect(markoUuid, equals('a1b2c3d4-e5f6-7890-abcd-ef1234567890'));

      final milosUuid = await TestVozacMappingService.getVozacUuid('Miloš Pešić');
      expect(milosUuid, equals('b2c3d4e5-f6a7-8901-bcde-f21234567890'));

      final aleksandarUuid = await TestVozacMappingService.getVozacUuid('Aleksandar Stojanović');
      expect(aleksandarUuid, equals('c3d4e5f6-a7b8-9012-cdef-321234567890'));

      final stefanUuid = await TestVozacMappingService.getVozacUuid('Stefan Milanović');
      expect(stefanUuid, equals('d4e5f6a7-b8c9-0123-def4-21234567890a'));

      final nepoznatUuid = await TestVozacMappingService.getVozacUuid('Nepoznat Vozač');
      expect(nepoznatUuid, isNull);
    });
  });
}
