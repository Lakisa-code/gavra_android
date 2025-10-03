import 'package:shared_preferences/shared_preferences.dart';
import '../services/phone_auth_service.dart';
import '../utils/logging.dart';

/// Servis za provjeru registracije vozača putem SMS-a
class VozacRegistracijaService {
  
  /// Provjeri da li je vozač registrovan putem SMS-a
  static Future<bool> isVozacRegistrovan(String vozacIme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRegistrovan = prefs.getBool('sms_registrovan_$vozacIme') ?? false;
      dlog('📱 Provjera SMS registracije za $vozacIme: $isRegistrovan');
      return isRegistrovan;
    } catch (e) {
      dlog('❌ Greška pri provjeri SMS registracije: $e');
      return false;
    }
  }

  /// Označi vozača kao registrovanog putem SMS-a
  static Future<void> oznaciVozacaKaoRegistrovanog(String vozacIme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sms_registrovan_$vozacIme', true);
      await prefs.setString('sms_registracija_datum_$vozacIme', DateTime.now().toIso8601String());
      dlog('✅ Vozač $vozacIme označen kao SMS registrovan');
    } catch (e) {
      dlog('❌ Greška pri označavanju SMS registracije: $e');
    }
  }

  /// Dobij datum SMS registracije
  static Future<DateTime?> getDatumSMSRegistracije(String vozacIme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datumString = prefs.getString('sms_registracija_datum_$vozacIme');
      if (datumString != null) {
        return DateTime.parse(datumString);
      }
      return null;
    } catch (e) {
      dlog('❌ Greška pri dohvatanju datuma SMS registracije: $e');
      return null;
    }
  }

  /// Resetuj SMS registraciju (za debug/testing)
  static Future<void> resetSMSRegistraciju(String vozacIme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sms_registrovan_$vozacIme');
      await prefs.remove('sms_registracija_datum_$vozacIme');
      dlog('🔄 SMS registracija resetovana za $vozacIme');
    } catch (e) {
      dlog('❌ Greška pri resetovanju SMS registracije: $e');
    }
  }

  /// Provjeri da li vozač mora prvo da se registruje putem SMS-a
  static Future<bool> trebaSMSRegistracija(String vozacIme) async {
    final isRegistrovan = await isVozacRegistrovan(vozacIme);
    final imaValidanBroj = PhoneAuthService.getDriverPhone(vozacIme) != null;
    
    // Vozač mora SMS registraciju ako:
    // 1. Nije registrovan putem SMS-a
    // 2. Ima validan broj telefona u sistemu
    return !isRegistrovan && imaValidanBroj;
  }

  /// Dohvati sve registrovane vozače
  static Future<List<String>> getRegistrovaneVozace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sviKljucevi = prefs.getKeys();
      final registrovaniVozaci = <String>[];

      for (final kljuc in sviKljucevi) {
        if (kljuc.startsWith('sms_registrovan_') && prefs.getBool(kljuc) == true) {
          final vozacIme = kljuc.replaceFirst('sms_registrovan_', '');
          registrovaniVozaci.add(vozacIme);
        }
      }

      return registrovaniVozaci;
    } catch (e) {
      dlog('❌ Greška pri dohvatanju registrovanih vozača: $e');
      return [];
    }
  }

  /// Validacija broja telefona za vozača
  static bool isBrojTelefonaValidanZaVozaca(String vozacIme, String brojTelefona) {
    final expectedBroj = PhoneAuthService.getDriverPhone(vozacIme);
    return expectedBroj == brojTelefona;
  }
}