import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logging.dart';

class DriverRegistrationService {
  static const String _registeredDriversKey = 'registered_drivers';
  static const String _driverEmailKey = 'driver_email_';

  // Lista dostupnih vozača (možda kasnije iz config-a)
  static const List<String> availableDrivers = [
    'Bilevski',
    'Bruda',
    'Bojan',
    'Svetlana',
  ];

  /// Proveri da li je vozač već registrovan sa email-om
  static Future<bool> isDriverRegistered(String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registeredDrivers = prefs.getStringList(_registeredDriversKey) ?? [];
      return registeredDrivers.contains(driverName);
    } catch (e) {
      dlog('❌ Greška pri proveri registracije vozača: $e');
      return false;
    }
  }

  /// Registruj vozača lokalno (nakon uspešne email registracije)
  static Future<bool> markDriverAsRegistered(String driverName, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Dodaj vozača u listu registrovanih
      final registeredDrivers = prefs.getStringList(_registeredDriversKey) ?? [];
      if (!registeredDrivers.contains(driverName)) {
        registeredDrivers.add(driverName);
        await prefs.setStringList(_registeredDriversKey, registeredDrivers);
      }

      // Sačuvaj email za vozača
      await prefs.setString('$_driverEmailKey$driverName', email);

      dlog('✅ Vozač $driverName označen kao registrovan sa email-om: $email');
      return true;
    } catch (e) {
      dlog('❌ Greška pri označavanju vozača kao registrovan: $e');
      return false;
    }
  }

  /// Dohvati email vozača
  static Future<String?> getDriverEmail(String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_driverEmailKey$driverName');
    } catch (e) {
      dlog('❌ Greška pri dohvatanju email-a vozača: $e');
      return null;
    }
  }

  /// Reset registracije vozača (za testing/debugging)
  static Future<bool> resetDriverRegistration(String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ukloni iz liste registrovanih
      final registeredDrivers = prefs.getStringList(_registeredDriversKey) ?? [];
      registeredDrivers.remove(driverName);
      await prefs.setStringList(_registeredDriversKey, registeredDrivers);

      // Ukloni email
      await prefs.remove('$_driverEmailKey$driverName');

      dlog('🔄 Reset registracije za vozača: $driverName');
      return true;
    } catch (e) {
      dlog('❌ Greška pri reset-u registracije vozača: $e');
      return false;
    }
  }

  /// Dohvati listu svih registrovanih vozača
  static Future<List<String>> getRegisteredDrivers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_registeredDriversKey) ?? [];
    } catch (e) {
      dlog('❌ Greška pri dohvatanju registrovanih vozača: $e');
      return [];
    }
  }

  /// Proveri da li je vozač trenutno ulogovan u Supabase
  static Future<String?> getCurrentLoggedInDriver() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final driverName = user.userMetadata?['driver_name'] as String?;
        dlog('🔐 Trenutno ulogovan vozač: $driverName');
        return driverName;
      }
      return null;
    } catch (e) {
      dlog('❌ Greška pri proveri trenutno ulogovanog vozača: $e');
      return null;
    }
  }

  /// Odjavi vozača iz Supabase
  static Future<bool> signOutDriver() async {
    try {
      await Supabase.instance.client.auth.signOut();
      dlog('👋 Vozač odjavljen iz Supabase');
      return true;
    } catch (e) {
      dlog('❌ Greška pri odjavi vozača: $e');
      return false;
    }
  }
}
