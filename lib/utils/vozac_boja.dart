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
  // CACHE MEHANIZAM - za sinkronu upotrebu nakon inicijalizacije
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache boja učitanih iz baze
  static Map<String, Color> _cachedBoje = {};

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
        // Koristi samo boju iz baze - nema fallback-a
        if (vozac.color != null) {
          result[vozac.ime] = vozac.color!;
        }
      }

      _cachedBoje = Map.unmodifiable(result);
      _cachedVozaci = vozaci;
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ [VozacBoja] Cache initialized with ${vozaci.length} drivers from database');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [VozacBoja] Cache initialization failed: $e - cache will remain empty');
      }
      _cachedBoje = {};
      _cachedVozaci = [];
      _isInitialized = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JAVNI API - ASYNC (direktno iz baze)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća mapu svih boja - direktno iz baze (bez fallback-a)
  static Future<Map<String, Color>> get boje async {
    final vozacService = VozacService();
    final vozaci = await vozacService.getAllVozaci();

    final Map<String, Color> result = {};

    for (var vozac in vozaci) {
      // Koristi samo boju iz baze - nema fallback-a
      if (vozac.color != null) {
        result[vozac.ime] = vozac.color!;
      }
    }

    return Map.unmodifiable(result);
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
  // HELPER FUNKCIJE - koriste podatke iz baze
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća dozvoljen email za vozača (iz baze)
  static Future<String?> getDozvoljenEmailForVozac(String? vozac) async {
    if (vozac == null) return null;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      final vozacObj = vozaci.firstWhere((v) => v.ime == vozac);
      return vozacObj.email;
    } catch (e) {
      return null;
    }
  }

  /// Vraća vozača za dati email (iz baze)
  static Future<String?> getVozacForEmail(String? email) async {
    if (email == null) return null;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      final vozacObj = vozaci.firstWhere((v) => v.email?.toLowerCase() == email.toLowerCase());
      return vozacObj.ime;
    } catch (e) {
      return null;
    }
  }

  /// Proverava da li je email dozvoljen za vozača (iz baze)
  static Future<bool> isEmailDozvoljenForVozac(String? email, String? vozac) async {
    if (email == null || vozac == null) return false;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      final vozacObj = vozaci.firstWhere((v) => v.ime == vozac);
      return vozacObj.email?.toLowerCase() == email.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  /// Proverava da li je email dozvoljen (registrovan u bazi)
  static Future<bool> isDozvoljenEmail(String? email) async {
    if (email == null) return false;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      return vozaci.any((v) => v.email?.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Vraća sve dozvoljene email adrese (iz baze)
  static Future<List<String>> get sviDozvoljenEmails async {
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      return vozaci.where((v) => v.email != null).map((v) => v.email!).toList();
    } catch (e) {
      return [];
    }
  }

  /// Vraća telefon za vozača (iz baze)
  static Future<String?> getTelefonForVozac(String? vozac) async {
    if (vozac == null) return null;
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      final vozacObj = vozaci.firstWhere((v) => v.ime == vozac);
      return vozacObj.brojTelefona;
    } catch (e) {
      return null;
    }
  }
}
