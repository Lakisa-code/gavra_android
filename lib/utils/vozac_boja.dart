import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/vozac.dart';
import '../services/vozac_service.dart';

/// VozacBoja - boje vozača iz baze podataka
///
/// Cache se inicijalizuje jednom pri startu (initialize()).
///
/// ## Korišćenje:
/// - `VozacBoja.getSync(ime)` — boja po imenu ili UUID, fallback = Colors.grey
/// - `VozacBoja.getSync(ime, fallback: Colors.red)` — custom fallback
class VozacBoja {
  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════════════════════════════════════

  /// ime → Color
  static Map<String, Color> _cachedBoje = {};

  /// uuid → Color
  static Map<String, Color> _cachedBojeUuid = {};

  /// Lista svih Vozac objekata
  static List<Vozac> _cachedVozaci = [];

  static bool _isInitialized = false;

  /// Inicijalizuj cache pri startu aplikacije (poziva se iz main.dart)
  static Future<void> initialize() async {
    try {
      final vozaci = await VozacService().getAllVozaci();

      final Map<String, Color> byIme = {};
      final Map<String, Color> byUuid = {};

      for (final vozac in vozaci) {
        final color = vozac.color;
        if (color != null) {
          byIme[vozac.ime] = color;
          byUuid[vozac.id] = color;
        }
      }

      _cachedBoje = Map.unmodifiable(byIme);
      _cachedBojeUuid = Map.unmodifiable(byUuid);
      _cachedVozaci = vozaci;
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ [VozacBoja] Cache initialized: ${vozaci.length} vozača');
      }
    } catch (e) {
      _cachedBoje = {};
      _cachedBojeUuid = {};
      _cachedVozaci = [];
      _isInitialized = false;
      if (kDebugMode) {
        debugPrint('❌ [VozacBoja] Cache initialization failed: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ASYNC API (direktno iz baze, za slučajeve kad cache nije dovoljan)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lista svih validnih vozača (async, direktno iz baze)
  static Future<List<String>> get validDrivers async {
    final vozaci = await VozacService().getAllVozaci();
    return vozaci.map((v) => v.ime).toList();
  }

  /// Provjera validnosti vozača (async)
  static Future<bool> isValidDriver(String? ime) async {
    if (ime == null) return false;
    final vozaci = await VozacService().getAllVozaci();
    return vozaci.any((v) => v.ime == ime);
  }

  /// Vraća Vozac objekat za dato ime (sa ID-om, emailom, itd.)
  static Future<Vozac?> getVozac(String? ime) async {
    if (ime == null) return null;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.firstWhere((v) => v.ime == ime);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC API (primarno korišćenje)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća boju vozača po imenu ili UUID-u.
  /// Nikada ne baca exception — vraća [fallback] ako vozač nije pronađen.
  static Color getSync(String? identifikator, {Color fallback = Colors.grey}) {
    if (identifikator == null || identifikator.isEmpty) return fallback;
    return _cachedBoje[identifikator] ?? _cachedBojeUuid[identifikator] ?? fallback;
  }

  /// Provjera da li je vozač registrovan (po imenu)
  static bool isValidDriverSync(String? ime) {
    if (ime == null || ime.isEmpty) return false;
    return _cachedBoje.containsKey(ime);
  }

  /// Lista svih validnih imena vozača (SYNC)
  static List<String> get validDriversSync => _cachedBoje.keys.toList();

  /// Mapa ime → Color (SYNC)
  static Map<String, Color> get bojeSync => _cachedBoje;

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METODE (email, telefon)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Vraća email vozača
  static Future<String?> getDozvoljenEmailForVozac(String? vozac) async {
    if (vozac == null) return null;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.firstWhere((v) => v.ime == vozac).email;
    } catch (_) {
      return null;
    }
  }

  /// Vraća ime vozača za dati email
  static Future<String?> getVozacForEmail(String? email) async {
    if (email == null) return null;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.firstWhere((v) => v.email?.toLowerCase() == email.toLowerCase()).ime;
    } catch (_) {
      return null;
    }
  }

  /// Provjera da li email pripada datom vozaču
  static Future<bool> isEmailDozvoljenForVozac(String? email, String? vozac) async {
    if (email == null || vozac == null) return false;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.firstWhere((v) => v.ime == vozac).email?.toLowerCase() == email.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Provjera da li je email registrovan kao bilo koji vozač
  static Future<bool> isDozvoljenEmail(String? email) async {
    if (email == null) return false;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.any((v) => v.email?.toLowerCase() == email.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Vraća sve dozvoljene email adrese
  static Future<List<String>> get sviDozvoljenEmails async {
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.where((v) => v.email != null).map((v) => v.email!).toList();
    } catch (_) {
      return [];
    }
  }

  /// Vraća telefon vozača
  static Future<String?> getTelefonForVozac(String? vozac) async {
    if (vozac == null) return null;
    try {
      final vozaci = await VozacService().getAllVozaci();
      return vozaci.firstWhere((v) => v.ime == vozac).brojTelefona;
    } catch (_) {
      return null;
    }
  }
}
