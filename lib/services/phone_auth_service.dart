import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logging.dart';

class PhoneAuthService {
  static final _supabase = Supabase.instance.client;

  // Brojevi telefona za vozače
  static const Map<String, String> _driverPhones = {
    'Bojan': '+381641162560',
    'Bruda': '+381641202844',
    'Svetlana': '+381658464160',
    'Bilevski': '+381638466418',
  };

  /// 📱 REGISTRUJ VOZAČA SA BROJEM TELEFONA
  static Future<bool> registerDriverWithPhone(
      String driverName, String phoneNumber, String password) async {
    try {
      dlog('📱 Registrujem vozača $driverName sa brojem: $phoneNumber');

      // Provjeri da li je broj telefona valjan za ovog vozača
      if (_driverPhones[driverName] != phoneNumber) {
        dlog(
            '❌ Broj telefona $phoneNumber nije dozvoljen za vozača $driverName');
        return false;
      }

      final AuthResponse response = await _supabase.auth
          .signUp(phone: phoneNumber, password: password, data: {
        'driver_name': driverName,
        'role': 'driver',
        'registered_at': DateTime.now().toIso8601String(),
      });

      if (response.user != null) {
        dlog('✅ Vozač $driverName uspješno registrovan. Čeka se SMS potvrda.');

        // Sačuvaj podatke lokalno
        await _saveDriverPhoneData(driverName, phoneNumber);

        return true;
      } else {
        dlog('❌ Registracija neuspješna za $driverName');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri registraciji vozača $driverName: $e');
      return false;
    }
  }

  /// 📨 POTVRDI SMS KOD
  static Future<bool> confirmSMSVerification(
      String phoneNumber, String smsCode) async {
    try {
      dlog('📨 Potvrđujem broj: $phoneNumber sa SMS kodom: $smsCode');

      final AuthResponse response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        token: smsCode,
        phone: phoneNumber,
      );

      if (response.user != null && response.user!.phoneConfirmedAt != null) {
        dlog('✅ SMS uspješno potvrđen za: $phoneNumber');

        // Ažuriraj lokalne podatke
        await _updateSMSConfirmationStatus(phoneNumber, true);

        return true;
      } else {
        dlog('❌ SMS potvrda neuspješna za: $phoneNumber');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri potvrdi SMS: $e');
      return false;
    }
  }

  /// 🔐 PRIJAVI SE SA BROJEM I ŠIFROM
  static Future<String?> signInWithPhone(
      String phoneNumber, String password) async {
    try {
      dlog('🔐 Prijavljivanje sa brojem: $phoneNumber');

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        phone: phoneNumber,
        password: password,
      );

      if (response.user != null) {
        // Provjeri da li je broj potvrđen
        if (response.user!.phoneConfirmedAt == null) {
          dlog('⚠️ Broj telefona nije potvrđen za: $phoneNumber');
          return null;
        }

        // Izvuci ime vozača iz metapodataka
        final driverName =
            response.user!.userMetadata?['driver_name'] as String?;

        if (driverName != null) {
          dlog('✅ Uspješna prijava vozača: $driverName');

          // Sačuvaj trenutnu sesiju
          await _saveCurrentSession(driverName, phoneNumber);

          return driverName;
        } else {
          dlog('❌ Nije pronađeno ime vozača u metapodacima');
          return null;
        }
      } else {
        dlog('❌ Neuspješna prijava za broj: $phoneNumber');
        return null;
      }
    } catch (e) {
      dlog('❌ Greška pri prijavi: $e');
      return null;
    }
  }

  /// 🚪 ODJAVI SE
  static Future<bool> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _clearCurrentSession();
      dlog('✅ Uspješna odjava');
      return true;
    } catch (e) {
      dlog('❌ Greška pri odjavi: $e');
      return false;
    }
  }

  /// 📬 POŠALJI PONOVO SMS KOD
  static Future<bool> resendSMSCode(String phoneNumber) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.sms,
        phone: phoneNumber,
      );
      dlog('✅ SMS kod ponovno poslan na: $phoneNumber');
      return true;
    } catch (e) {
      dlog('❌ Greška pri slanju SMS koda: $e');
      return false;
    }
  }

  /// 🔑 RESETUJ ŠIFRU PREKO SMS-a
  static Future<bool> resetPasswordViaSMS(String phoneNumber) async {
    try {
      // Koristimo signInWithOtp za reset - šaljemo novi kod
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );
      dlog('✅ SMS za reset šifre poslan na: $phoneNumber');
      return true;
    } catch (e) {
      dlog('❌ Greška pri slanju SMS za reset šifre: $e');
      return false;
    }
  }

  /// ✅ PROVJERI DA LI JE VOZAČ REGISTROVAN I POTVRĐEN
  static Future<bool> isDriverPhoneRegisteredAndConfirmed(
      String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConfirmed = prefs.getBool('phone_confirmed_$driverName') ?? false;
      return isConfirmed;
    } catch (e) {
      dlog('❌ Greška pri provjeri registracije broja: $e');
      return false;
    }
  }

  /// 📋 DOHVATI PODATKE O TRENUTNOJ SESIJI
  static Future<Map<String, String>?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverName = prefs.getString('current_session_driver');
      final phoneNumber = prefs.getString('current_session_phone');

      if (driverName != null && phoneNumber != null) {
        return {
          'driver_name': driverName,
          'phone_number': phoneNumber,
        };
      }
      return null;
    } catch (e) {
      dlog('❌ Greška pri dohvatanju trenutne sesije: $e');
      return null;
    }
  }

  /// 📱 DOHVATI BROJ TELEFONA ZA VOZAČA
  static String? getDriverPhone(String driverName) {
    return _driverPhones[driverName];
  }

  /// 📜 DOHVATI SVE VOZAČE KOJI MOGU DA SE REGISTRUJU
  static List<String> getAllDriversForRegistration() {
    return _driverPhones.keys.toList();
  }

  /// 📞 VALIDIRAJ FORMAT BROJA TELEFONA
  static bool isValidPhoneFormat(String phoneNumber) {
    // Provjeri da li je u formatu +381XXXXXXXXX
    final phoneRegex = RegExp(r'^\+381[0-9]{8,9}$');
    return phoneRegex.hasMatch(phoneNumber);
  }

  /// � REGISTRUJ VOZAČA SA EMAIL-OM
  static Future<bool> registerDriverWithEmail(
      String driverName, String email, String password) async {
    try {
      dlog('📧 Registrujem vozača $driverName sa email-om: $email');

      final AuthResponse response = await _supabase.auth
          .signUp(email: email, password: password, data: {
        'driver_name': driverName,
        'role': 'driver',
        'auth_type': 'email',
        'registered_at': DateTime.now().toIso8601String(),
      });

      if (response.user != null) {
        dlog('✅ Vozač $driverName uspješno registrovan sa email-om. Čeka se email potvrda.');

        // Sačuvaj podatke lokalno
        await _saveDriverEmailData(driverName, email);

        return true;
      } else {
        dlog('❌ Registracija neuspješna za $driverName');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri registraciji vozača $driverName sa email-om: $e');
      return false;
    }
  }

  /// 📧 POTVRDI EMAIL VERIFIKACIJU
  static Future<bool> confirmEmailVerification(
      String email, String emailCode) async {
    try {
      dlog('📧 Potvrđujem email: $email sa kodom: $emailCode');

      final AuthResponse response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        token: emailCode,
        email: email,
      );

      if (response.user != null && response.user!.emailConfirmedAt != null) {
        dlog('✅ Email uspješno potvrđen za: $email');

        // Ažuriraj lokalne podatke
        await _updateEmailConfirmationStatus(email, true);

        return true;
      } else {
        dlog('❌ Email potvrda neuspješna za: $email');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri potvrdi email-a: $e');
      return false;
    }
  }

  /// 🔐 PRIJAVI SE SA EMAIL-OM I ŠIFROM
  static Future<String?> signInWithEmail(
      String email, String password) async {
    try {
      dlog('🔐 Prijavljivanje sa email-om: $email');

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Provjeri da li je email potvrđen
        if (response.user!.emailConfirmedAt == null) {
          dlog('⚠️ Email nije potvrđen za: $email');
          return null;
        }

        // Izvuci ime vozača iz metapodataka
        final driverName =
            response.user!.userMetadata?['driver_name'] as String?;

        if (driverName != null) {
          dlog('✅ Uspješna prijava vozača: $driverName sa email-om');

          // Sačuvaj trenutnu sesiju
          await _saveCurrentEmailSession(driverName, email);

          return driverName;
        } else {
          dlog('❌ Nije pronađeno ime vozača u metapodacima');
          return null;
        }
      } else {
        dlog('❌ Neuspješna prijava za email: $email');
        return null;
      }
    } catch (e) {
      dlog('❌ Greška pri prijavi sa email-om: $e');
      return null;
    }
  }

  /// 📧 POŠALJI PONOVO EMAIL KOD
  static Future<bool> resendEmailCode(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.email,
        email: email,
      );
      dlog('✅ Email kod ponovno poslan na: $email');
      return true;
    } catch (e) {
      dlog('❌ Greška pri slanju email koda: $e');
      return false;
    }
  }

  /// 🔑 RESETUJ ŠIFRU PREKO EMAIL-a
  static Future<bool> resetPasswordViaEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      dlog('✅ Email za reset šifre poslan na: $email');
      return true;
    } catch (e) {
      dlog('❌ Greška pri slanju email-a za reset šifre: $e');
      return false;
    }
  }

  /// ✅ PROVJERI DA LI JE VOZAČ REGISTROVAN I POTVRĐEN SA EMAIL-OM
  static Future<bool> isDriverEmailRegisteredAndConfirmed(
      String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConfirmed = prefs.getBool('email_confirmed_$driverName') ?? false;
      return isConfirmed;
    } catch (e) {
      dlog('❌ Greška pri provjeri registracije email-a: $e');
      return false;
    }
  }

  /// 📧 DOHVATI EMAIL ZA VOZAČA
  static Future<String?> getDriverEmail(String driverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('driver_email_$driverName');
    } catch (e) {
      dlog('❌ Greška pri dohvatanju email-a vozača: $e');
      return null;
    }
  }

  /// 📧 VALIDIRAJ FORMAT EMAIL-A
  static bool isValidEmailFormat(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // PRIVATNE HELPER METODE

  static Future<void> _saveDriverPhoneData(
      String driverName, String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_phone_$driverName', phoneNumber);
      await prefs.setBool('phone_confirmed_$driverName', false);
      dlog('✅ Sačuvani podaci o broju za vozača: $driverName');
    } catch (e) {
      dlog('❌ Greška pri čuvanju podataka o broju: $e');
    }
  }

  static Future<void> _updateSMSConfirmationStatus(
      String phoneNumber, bool confirmed) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pronađi vozača po broju telefona
      String? driverName;
      for (final entry in _driverPhones.entries) {
        if (entry.value == phoneNumber) {
          driverName = entry.key;
          break;
        }
      }

      if (driverName != null) {
        await prefs.setBool('phone_confirmed_$driverName', confirmed);
        dlog('✅ Ažuriran status SMS potvrde za vozača: $driverName');
      }
    } catch (e) {
      dlog('❌ Greška pri ažuriranju statusa SMS potvrde: $e');
    }
  }

  static Future<void> _saveCurrentSession(
      String driverName, String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session_driver', driverName);
      await prefs.setString('current_session_phone', phoneNumber);
      dlog('✅ Sačuvana trenutna sesija za vozača: $driverName');
    } catch (e) {
      dlog('❌ Greška pri čuvanju trenutne sesije: $e');
    }
  }

  static Future<void> _clearCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_driver');
      await prefs.remove('current_session_phone');
      dlog('✅ Obrisana trenutna sesija');
    } catch (e) {
      dlog('❌ Greška pri brisanju trenutne sesije: $e');
    }
  }

  // EMAIL AUTH HELPER METODE

  static Future<void> _saveDriverEmailData(
      String driverName, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_email_$driverName', email);
      await prefs.setBool('email_confirmed_$driverName', false);
      dlog('✅ Sačuvani podaci o email-u za vozača: $driverName');
    } catch (e) {
      dlog('❌ Greška pri čuvanju podataka o email-u: $e');
    }
  }

  static Future<void> _updateEmailConfirmationStatus(
      String email, bool confirmed) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pronađi vozača po email-u
      String? driverName;
      for (final entry in _driverPhones.entries) {
        final driverEmail = prefs.getString('driver_email_${entry.key}');
        if (driverEmail == email) {
          driverName = entry.key;
          break;
        }
      }

      if (driverName != null) {
        await prefs.setBool('email_confirmed_$driverName', confirmed);
        dlog('✅ Ažuriran status email potvrde za vozača: $driverName');
      }
    } catch (e) {
      dlog('❌ Greška pri ažuriranju statusa email potvrde: $e');
    }
  }

  static Future<void> _saveCurrentEmailSession(
      String driverName, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session_driver', driverName);
      await prefs.setString('current_session_email', email);
      dlog('✅ Sačuvana trenutna email sesija za vozača: $driverName');
    } catch (e) {
      dlog('❌ Greška pri čuvanju trenutne email sesije: $e');
    }
  }
}
