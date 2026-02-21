import 'package:flutter/material.dart';

import '../models/vozac.dart';
import 'vozac_cache.dart';

/// VozacBoja — backwards-compat wrapper oko VozacCache.
///
/// Novi kod treba koristiti VozacCache direktno.
@Deprecated('Koristiti VozacCache')
class VozacBoja {
  /// @deprecated Koristiti VozacCache.initialize()
  static Future<void> initialize() => VozacCache.initialize();

  /// Vraća boju po imenu ili UUID-u. Nikad ne baca exception.
  static Color getSync(String? identifikator, {Color fallback = Colors.grey}) =>
      VozacCache.getColor(identifikator, fallback: fallback);

  /// Provjera da li je ime registrovan vozač.
  static bool isValidDriverSync(String? ime) => VozacCache.isValidIme(ime);

  /// Lista svih validnih vozača (SYNC).
  static List<String> get validDriversSync => VozacCache.imenaVozaca;

  /// Mapa ime → Color (SYNC).
  static Map<String, Color> get bojeSync => VozacCache.bojeSync;

  /// Vraća Vozac objekat za dato ime.
  static Future<Vozac?> getVozac(String? ime) async => VozacCache.getVozacByIme(ime);

  /// Vraća email vozača.
  static Future<String?> getDozvoljenEmailForVozac(String? vozac) async =>
      VozacCache.getEmailByIme(vozac);

  /// Vraća ime vozača za dati email.
  static Future<String?> getVozacForEmail(String? email) async =>
      VozacCache.getImeByEmail(email);

  /// Provjera da li email pripada datom vozaču.
  static Future<bool> isEmailDozvoljenForVozac(String? email, String? vozac) async =>
      VozacCache.isEmailForVozac(email, vozac);

  /// Provjera da li je email registrovan kao bilo koji vozač.
  static Future<bool> isDozvoljenEmail(String? email) async =>
      VozacCache.isRegistrovanEmail(email);

  /// Vraća sve dozvoljene email adrese.
  static Future<List<String>> get sviDozvoljenEmails async => VozacCache.sviEmails;

  /// Vraća telefon vozača.
  static Future<String?> getTelefonForVozac(String? vozac) async =>
      VozacCache.getTelefonByIme(vozac);

  /// Provjera validnosti vozača (async — koristi sync cache).
  static Future<bool> isValidDriver(String? ime) async => VozacCache.isValidIme(ime);

  /// Lista svih validnih vozača (async — koristi sync cache).
  static Future<List<String>> get validDrivers async => VozacCache.imenaVozaca;
}
