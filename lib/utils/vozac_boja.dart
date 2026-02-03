import 'package:flutter/material.dart';

import '../models/vozac.dart';
import '../services/vozac_service.dart';

/// VozacBoja - Centralizovana logika boja za vozače
///
/// Ova klasa sada podržava dinamičko učitavanje boja iz baze podataka
/// sa fallback-om na hardkodovane vrednosti za backward kompatibilnost.
///
/// ## Inicijalizacija:
/// Pozovite `VozacBoja.initialize()` na startupu aplikacije (npr. u main.dart)
/// da bi se boje učitale iz baze pre korišćenja.
///
/// ## Cache:
/// Boje se keširaju na 30 minuta. Možete pozvati `refreshCache()` za ručno osvežavanje.
class VozacBoja {
  // ═══════════════════════════════════════════════════════════════════════════
  // FALLBACK KONSTANTE (koriste se ako baza nije dostupna)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Hardkodovane boje - fallback ako baza nije dostupna
  static const Map<String, Color> _fallbackBoje = {
    'Bruda': Color(0xFF7C4DFF), // ljubičasta
    'Bilevski': Color(0xFFFF9800), // narandžasta
    'Bojan': Color(0xFF00E5FF), // svetla cyan plava - osvežavajuća i moderna
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE ZA DINAMIČKO UČITAVANJE
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, Color>? _bojeCache;
  static Map<String, Vozac>? _vozaciCache;
  static DateTime? _lastCacheUpdate;
  static bool _isInitialized = false;
  static const Duration _cacheValidityPeriod = Duration(minutes: 30);

  /// INICIJALIZACIJA - Pozovite na startupu aplikacije
  static Future<void> initialize() async {
    if (_isInitialized && _isCacheValid()) return;

    try {
      await _loadFromDatabase();
      _isInitialized = true;
      debugPrint('✅ [VozacBoja] Initialized with ${_bojeCache?.length ?? 0} drivers');
    } catch (e) {
      debugPrint('❌ [VozacBoja] Database load failed: $e, using fallback');
      // Ako baza nije dostupna, koristi fallback
      _bojeCache = Map.from(_fallbackBoje);
      _isInitialized = true;
    }
  }

  /// Učitava boje iz baze podataka
  static Future<void> _loadFromDatabase() async {
    debugPrint('🔍 [VozacBoja] Loading drivers from database...');
    final vozacService = VozacService();
    final vozaci = await vozacService.getAllVozaci();
    debugPrint('✅ [VozacBoja] Loaded ${vozaci.length} drivers from database');

    _bojeCache = {};
    _vozaciCache = {};

    for (var vozac in vozaci) {
      _vozaciCache![vozac.ime] = vozac;

      // Koristi boju iz baze ako postoji, inače fallback
      if (vozac.color != null) {
        _bojeCache![vozac.ime] = vozac.color!;
      } else if (_fallbackBoje.containsKey(vozac.ime)) {
        _bojeCache![vozac.ime] = _fallbackBoje[vozac.ime]!;
      }
    }

    // Dodaj fallback boje za vozače koji nisu u bazi
    for (var entry in _fallbackBoje.entries) {
      _bojeCache!.putIfAbsent(entry.key, () => entry.value);
    }

    _lastCacheUpdate = DateTime.now();
  }

  /// Proverava da li je cache validan
  static bool _isCacheValid() {
    if (_bojeCache == null || _lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidityPeriod;
  }

  /// Osvežava cache (pozovite nakon izmena u bazi)
  static Future<void> refreshCache() async {
    _isInitialized = false;
    await initialize();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JAVNI API (backward kompatibilan)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća mapu svih boja (dinamičke + fallback)
  static Map<String, Color> get boje {
    if (_bojeCache != null && _isCacheValid()) {
      return Map.unmodifiable(_bojeCache!);
    }
    return _fallbackBoje;
  }

  /// Vraća boju za vozača - baca grešku ako vozač nije validan
  static Color get(String? ime) {
    final currentBoje = boje;
    if (ime != null && currentBoje.containsKey(ime)) {
      return currentBoje[ime]!;
    }
    throw ArgumentError('Vozač "$ime" nije registrovan. Validni vozači: ${currentBoje.keys.join(", ")}');
  }

  /// Proverava da li je vozač prepoznat/valjan
  static bool isValidDriver(String? ime) {
    return ime != null && boje.containsKey(ime);
  }

  /// Vraća Vozac objekat za dato ime (sa ID-om)
  static Vozac? getVozac(String? ime) {
    if (ime == null || _vozaciCache == null) return null;
    return _vozaciCache![ime];
  }

  /// Lista svih validnih vozača
  static List<String> get validDrivers => boje.keys.toList();

  /// Vraća boju vozača ili default boju ako vozač nije registrovan
  /// FIX: Case-insensitive poređenje za robusnost
  static Color getColorOrDefault(String? ime, Color defaultColor) {
    if (ime == null || ime.isEmpty) return defaultColor;

    final currentBoje = boje;
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

  /// Alias za get() metodu - za kompatibilnost
  static Color getColor(String? ime) => get(ime);

  // ═══════════════════════════════════════════════════════════════════════════
  // EMAIL I TELEFON VALIDACIJA (ostaje hardkodovano za sada)
  // ═══════════════════════════════════════════════════════════════════════

  // DOZVOLJENI EMAIL ADRESE ZA VOZAČE - STRIKTNO!
  static const Map<String, String> dozvoljenEmails = {
    'Bojan': 'gavriconi19@gmail.com',
    'Bruda': 'igor.jovanovic.1984@icloud.com',
    'Bilevski': 'bilyboy1983@gmail.com',
    'Svetlana': 'risticsvetlana2911@yahoo.com',
    'Ivan': 'bradvarevicivan99@gmail.com',
  };

  // VALIDACIJA: email -> vozač mapiranje
  static const Map<String, String> emailToVozac = {
    'gavriconi19@gmail.com': 'Bojan',
    'igor.jovanovic.1984@icloud.com': 'Bruda',
    'bilyboy1983@gmail.com': 'Bilevski',
    'risticsvetlana2911@yahoo.com': 'Svetlana',
    'bradvarevicivan99@gmail.com': 'Ivan',
  };

  // BROJEVI TELEFONA VOZAČA
  static const Map<String, String> telefoni = {
    'Bojan': '0641162560',
    'Bruda': '0641202844',
    'Bilevski': '0638466418',
    'Svetlana': '0658464160',
    'Ivan': '0677662993',
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
