import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logging.dart';

class EmailAuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Proveri da li je email u validnom formatu
  static bool isValidEmailFormat(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Registruj vozača sa email-om
  static Future<bool> registerDriverWithEmail(
      String driverName, String email, String password) async {
    try {
      dlog('📧 Registrujem vozača $driverName sa email-om: $email');

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'driver_name': driverName},
      );

      if (response.user != null) {
        dlog('✅ Vozač registrovan uspešno');
        
        // Proveri da li je email već potvrđen (ako confirmations su disabled)
        if (response.user!.emailConfirmedAt != null) {
          dlog('📧 Email je automatski potvrđen - confirmations su disabled');
        } else {
          dlog('📧 Email verifikacija potrebna');
        }
        
        return true;
      } else {
        dlog('❌ Registracija vozača nije uspela');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri registraciji vozača: $e');
      return false;
    }
  }

  /// Proveri da li je email verifikacija potrebna
  static bool isEmailVerificationRequired(User? user) {
    return user != null && user.emailConfirmedAt == null;
  }

  /// Prijavi se sa email-om i lozinkom
  static Future<String?> signInWithEmail(String email, String password) async {
    try {
      dlog('🔐 Prijavljujem se sa email-om: $email');

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final driverName =
            response.user!.userMetadata?['driver_name'] as String?;
        dlog('✅ Prijava uspešna za vozača: $driverName');
        return driverName;
      } else {
        dlog('❌ Prijava nije uspela');
        return null;
      }
    } catch (e) {
      dlog('❌ Greška pri prijavi: $e');
      return null;
    }
  }

  /// Potvrdi email verifikaciju
  static Future<bool> confirmEmailVerification(
      String email, String code) async {
    try {
      dlog('✅ Potvrđujem email verifikaciju za: $email');

      final AuthResponse response = await _supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

      if (response.user != null) {
        dlog('✅ Email verifikacija uspešna');
        return true;
      } else {
        dlog('❌ Email verifikacija nije uspela');
        return false;
      }
    } catch (e) {
      dlog('❌ Greška pri email verifikaciji: $e');
      return false;
    }
  }

  /// Ponovo pošalji email kod
  static Future<bool> resendEmailCode(String email) async {
    try {
      dlog('📧 Ponovo šaljem email kod za: $email');

      await _supabase.auth.resend(
        type: OtpType.email,
        email: email,
      );

      dlog('✅ Email kod ponovo poslat');
      return true;
    } catch (e) {
      dlog('❌ Greška pri ponovnom slanju email koda: $e');
      return false;
    }
  }

  /// Resetuj lozinku preko email-a
  static Future<bool> resetPasswordViaEmail(String email) async {
    try {
      dlog('🔑 Resetujem lozinku za email: $email');

      await _supabase.auth.resetPasswordForEmail(email);

      dlog('✅ Email za reset lozinke poslat');
      return true;
    } catch (e) {
      dlog('❌ Greška pri resetu lozinke: $e');
      return false;
    }
  }

  /// Odjavi se
  static Future<bool> signOut() async {
    try {
      dlog('🚪 Odjavljujem se');

      await _supabase.auth.signOut();

      dlog('✅ Odjava uspešna');
      return true;
    } catch (e) {
      dlog('❌ Greška pri odjavi: $e');
      return false;
    }
  }

  /// Proveri da li je korisnik prijavljen
  static bool isUserLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  /// Dobij trenutnog korisnika
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}
