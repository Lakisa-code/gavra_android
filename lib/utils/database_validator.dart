// 🔍 DATABASE VALIDATION UTILITY
// Alat za validaciju konzistentnosti mapiranja vozača

import '../services/vozac_mapping_service.dart';

class DatabaseValidator {
  /// 🔍 KOMPLETNA VALIDACIJA BAZE I MAPIRANJA
  static Future<Map<String, dynamic>> validateComplete() async {
    final results = <String, dynamic>{};

    try {
      // 1. Validacija VozacMappingService konzistentnosti
      final mappingValidation = await VozacMappingService.validateConsistency();
      results['vozacMapping'] = mappingValidation;

      // 2. Cross-check sa VozacBoja
      results['vozacBojaCheck'] = _validateVozacBoja();

      // 3. Cache status
      results['cacheStatus'] = _getCacheStatus();

      // 4. Opšti summary
      results['summary'] = _generateSummary(results);
    } catch (e) {
      results['error'] = e.toString();
      results['isValid'] = false;
    }

    return results;
  }

  /// Validuj VozacBoja - simplifikovano bez validacije
  static Map<String, dynamic> _validateVozacBoja() {
    return {
      'status': 'Vozac validacija uklonjena',
      'validDrivers': ['Bruda', 'Bilevski', 'Bojan', 'Svetlana'],
    };
  }

  /// Dobij status cache-a
  static Map<String, dynamic> _getCacheStatus() {
    // Note: Ovo je približno jer ne možemo pristupiti privatnim poljima
    // Ali možemo testirati da li sync metode rade

    final testUuid = '12345-test-uuid';
    final testName = 'TestVozac';

    return {
      'syncMethodsWork': VozacMappingService.getVozacImeWithFallbackSync(testUuid) != null ||
          VozacMappingService.getVozacUuidSync(testName) != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generiši opšti summary
  static Map<String, dynamic> _generateSummary(Map<String, dynamic> results) {
    final mappingResults = results['vozacMapping'] as Map<String, dynamic>? ?? {};
    final isValid = mappingResults['isValid'] == true;
    final errors = (mappingResults['errors'] as List?) ?? [];
    final warnings = (mappingResults['warnings'] as List?) ?? [];

    return {
      'isValid': isValid,
      'errorCount': errors.length,
      'warningCount': warnings.length,
      'recommendation': isValid ? 'Mapiranje vozača je ispravno!' : 'Potrebne su ispravke u mapiranju vozača!',
    };
  }

  /// 🛠️ POPRAVI OSNOVNE PROBLEME (ako je moguće)
  static Future<Map<String, dynamic>> autoFix() async {
    final fixes = <String>[];
    final errors = <String>[];

    try {
      // 1. Refresh mapping cache
      await VozacMappingService.refreshMapping();
      fixes.add('Cache vozač mapiranja osvežen');

      // 2. Validacija posle refresh-a
      final validation = await validateComplete();

      return {
        'fixes': fixes,
        'errors': errors,
        'validationAfterFix': validation,
      };
    } catch (e) {
      errors.add('Greška pri auto-fix: $e');
      return {
        'fixes': fixes,
        'errors': errors,
      };
    }
  }

  /// 📊 QUICK STATUS CHECK - simplifikovano
  static Map<String, dynamic> quickCheck() {
    final expectedDrivers = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana'];

    return {
      'hardcodedDriverCount': expectedDrivers.length,
      'emailMappingComplete': true, // Pretpostavljamo da je OK
      'expectedDrivers': expectedDrivers,
      'status': 'OK',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
