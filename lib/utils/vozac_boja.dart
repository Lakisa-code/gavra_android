import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/vozac.dart';
import '../services/vozac_service.dart';

/// VozacBoja - Centralizovana logika boja za vozače
///
/// Ova klasa sada učitava boje direktno iz baze podataka
/// sa cache mehanizmom koji se inicijalizuje asinkrono.
///
/// ## Korišćenje:
/// 1. Async metodi vraćaju sveže podatke iz baze
/// 2. Sync metodi koriste cache (inicijalizovan pri startu)
/// 3. Cache se ažurira automatski
class VozacBoja {
  // ═══════════════════════════════════════════════════════════════════════════
  // FALLBACK KONSTANTE (koriste se ako baza nije dostupna)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Hardkodovane boje - fallback ako baza nije dostupna
  /// ✅ Podudaraju se sa bazom (vozaci tabela)
  static const Map<String, Color> _fallbackBoje = {
    'Bruda': Color(0xFF7C4DFF), // ljubičasta (#7C4DFF iz baze)
    'Bilevski': Color(0xFFFF9800), // narandžasta (#FF9800 iz baze)
    'Bojan': Color(0xFF00E5FF), // svetla cyan plava (#00E5FF iz baze)
    'Voja': Color(0xFF4CAF50), // zelena (#4CAF50 iz baze)
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE MEHANIZAM - za sinkronu upotrebu nakon inicijalizacije
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache boja učitanih iz baze
  static Map<String, Color> _cachedBoje = _fallbackBoje;

  /// Cache vozača učitanih iz baze
  static List<Vozac> _cachedVozaci = [];

  /// Da li je cache inicijalizovan
  static bool _isInitialized = false;

  /// Inicijalizuj cache pri startu aplikacije
  static Future<void> initialize() async {
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();

      final Map<String, Color> result = {};

      for (var vozac in vozaci) {
        // Koristi boju iz baze ako postoji, inače fallback
        if (vozac.color != null) {
          result[vozac.ime] = vozac.color!;
        } else if (_fallbackBoje.containsKey(vozac.ime)) {
          result[vozac.ime] = _fallbackBoje[vozac.ime]!;
        }
      }

      // Dodaj fallback boje za vozače koji nisu u bazi
      for (var entry in _fallbackBoje.entries) {
        result.putIfAbsent(entry.key, () => entry.value);
      }

      _cachedBoje = Map.unmodifiable(result);
      _cachedVozaci = vozaci;
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ [VozacBoja] Cache initialized with ${vozaci.length} drivers from database');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [VozacBoja] Cache initialization failed: $e, using fallback');
      }
      _cachedBoje = _fallbackBoje;
      _isInitialized = true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JAVNI API - ASYNC (direktno iz baze)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća mapu svih boja (dinamičke + fallback) - uvek sveže iz baze
  static Future<Map<String, Color>> get boje async {
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();

      final Map<String, Color> result = {};

      for (var vozac in vozaci) {
        // Koristi boju iz baze ako postoji, inače fallback
        if (vozac.color != null) {
          result[vozac.ime] = vozac.color!;
        } else if (_fallbackBoje.containsKey(vozac.ime)) {
          result[vozac.ime] = _fallbackBoje[vozac.ime]!;
        }
      }

      // Dodaj fallback boje za vozače koji nisu u bazi
      for (var entry in _fallbackBoje.entries) {
        result.putIfAbsent(entry.key, () => entry.value);
      }

      return Map.unmodifiable(result);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [VozacBoja] Database load failed: $e, using fallback');
      return _fallbackBoje;
    }
  }

  /// Vraća boju za vozača - baca grešku ako vozač nije validan
  static Future<Color> get(String? ime) async {
    final currentBoje = await boje;
    if (ime != null && currentBoje.containsKey(ime)) {
      return currentBoje[ime]!;
    }
    throw ArgumentError('Vozač "$ime" nije registrovan. Validni vozači: ${currentBoje.keys.join(", ")}');
  }

  /// Proverava da li je vozač prepoznat/valjan
  static Future<bool> isValidDriver(String? ime) async {
    if (ime == null) return false;
    final currentBoje = await boje;
    return currentBoje.containsKey(ime);
  }

  /// Vraća Vozac objekat za dato ime (sa ID-om)
  static Future<Vozac?> getVozac(String? ime) async {
    if (ime == null) return null;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      return vozaci.firstWhere((v) => v.ime == ime);
    } catch (e) {
      return null;
    }
  }

  /// Lista svih validnih vozača
  static Future<List<String>> get validDrivers async {
    final currentBoje = await boje;
    return currentBoje.keys.toList();
  }

  /// Vraća boju vozača ili default boju ako vozač nije registrovan
  /// FIX: Case-insensitive poređenje za robusnost
  static Future<Color> getColorOrDefault(String? ime, Color defaultColor) async {
    if (ime == null || ime.isEmpty) return defaultColor;

    final currentBoje = await boje;
    // Prvo probaj exact match
    if (currentBoje.containsKey(ime)) {
      return currentBoje[ime]!;
    }

    // FIX: Case-insensitive fallback
    final imeLower = ime.toLowerCase();
    for (final entry in currentBoje.entries) {
      if (entry.key.toLowerCase() == imeLower) {
        return entry.value;
      }
    }

    return defaultColor;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JAVNI API - SYNC (koristi cache, inicijalizovan pri startu)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća boju za vozača - baca grešku ako vozač nije validan (SYNC verzija)
  static Color getSync(String? ime) {
    if (ime != null && _cachedBoje.containsKey(ime)) {
      return _cachedBoje[ime]!;
    }
    throw ArgumentError('Vozač "$ime" nije registrovan. Validni vozači: ${_cachedBoje.keys.join(", ")}');
  }

  /// Proverava da li je vozač prepoznat/valjan (SYNC verzija)
  static bool isValidDriverSync(String? ime) {
    if (ime == null) return false;
    return _cachedBoje.containsKey(ime);
  }

  /// Vraća boju vozača ili default boju ako vozač nije registrovan (SYNC verzija)
  static Color getColorOrDefaultSync(String? ime, Color defaultColor) {
    if (ime == null || ime.isEmpty) return defaultColor;
    return _cachedBoje[ime] ?? defaultColor;
  }

  /// Lista svih validnih vozača (SYNC verzija)
  static List<String> get validDriversSync => _cachedBoje.keys.toList();

  /// Vraća mapu boja (SYNC verzija - iz cache-a)
  static Map<String, Color> get bojeSync => _cachedBoje;

  // ═══════════════════════════════════════════════════════════════════════════
  // EMAIL I TELEFON VALIDACIJA (ostaje hardkodovano za sada)
  // ═══════════════════════════════════════════════════════════════════════════

  // DOZVOLJENI EMAIL ADRESE ZA VOZAČE - STRIKTNO!
  static const Map<String, String> dozvoljenEmails = {
    'Bojan': 'gavriconi19@gmail.com',
    'Bruda': 'igor.jovanovic.1984@icloud.com',
    'Bilevski': 'bilyboy1983@gmail.com',
    'Svetlana': 'risticsvetlana2911@yahoo.com',
    'Ivan': 'bradvarevicivan99@gmail.com',
    'Voja': 'voja@gmail.com',
  };

  // VALIDACIJA: email -> vozač mapiranje
  static const Map<String, String> emailToVozac = {
    'gavriconi19@gmail.com': 'Bojan',
    'igor.jovanovic.1984@icloud.com': 'Bruda',
    'bilyboy1983@gmail.com': 'Bilevski',
    'risticsvetlana2911@yahoo.com': 'Svetlana',
    'bradvarevicivan99@gmail.com': 'Ivan',
    'voja@gmail.com': 'Voja',
  };

  // BROJEVI TELEFONA VOZAČA
  static const Map<String, String> telefoni = {
    'Bojan': '0641162560',
    'Bruda': '0641202844',
    'Bilevski': '0638466418',
    'Svetlana': '0658464160',
    'Ivan': '0677662993',
    'Voja': '0600000000',
  };

  // HELPER FUNKCIJE ZA EMAIL VALIDACIJU
  static String? getDozvoljenEmailForVozac(String? vozac) {
    return vozac != null ? dozvoljenEmails[vozac] : null;
  }

  static String? getVozacForEmail(String? email) {
    return email != null ? emailToVozac[email] : null;
  }

  static bool isEmailDozvoljenForVozac(String? email, String? vozac) {
    if (email == null || vozac == null) return false;
    return dozvoljenEmails[vozac]?.toLowerCase() == email.toLowerCase();
  }

  static bool isDozvoljenEmail(String? email) {
    return email != null && emailToVozac.containsKey(email);
  }

  static List<String> get sviDozvoljenEmails => dozvoljenEmails.values.toList();

  // HELPER ZA TELEFON
  static String? getTelefonForVozac(String? vozac) {
    return vozac != null ? telefoni[vozac] : null;
  }
}
