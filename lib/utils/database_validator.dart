// 🔍 DATABASE VALIDATION UTILITY
// Alat za validaciju konzistentnosti mapiranja vozača

import '../services/vozac_mapping_service.dart';
import '../utils/vozac_boja.dart';

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

  /// Validuj VozacBoja hardcoded vozače
  static Map<String, dynamic> _validateVozacBoja() {
    final hardcodedDrivers = VozacBoja.validDrivers;
    final dozvoljenEmails = VozacBoja.sviDozvoljenEmails;

    return {
      'hardcodedDrivers': hardcodedDrivers,
      'emailCount': dozvoljenEmails.length,
      'isEmailMappingComplete': hardcodedDrivers.length == dozvoljenEmails.length,
      'validDrivers': hardcodedDrivers,
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

  /// 📊 QUICK STATUS CHECK
  static Map<String, dynamic> quickCheck() {
    final hardcodedCount = VozacBoja.validDrivers.length;
    final emailMappingOk = VozacBoja.validDrivers.length == VozacBoja.sviDozvoljenEmails.length;

    return {
      'hardcodedDriverCount': hardcodedCount,
      'emailMappingComplete': emailMappingOk,
      'expectedDrivers': VozacBoja.validDrivers,
      'status': emailMappingOk ? 'OK' : 'NEEDS_REVIEW',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
