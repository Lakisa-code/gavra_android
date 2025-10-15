import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logging.dart';

class EmailAuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Proveri da li je email u validnom formatu
  static bool isValidEmailFormat(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Registruj vozača sa email-om (bez email verification)
  static Future<bool> registerDriverWithEmail(
    String driverName,
    String email,
    String password,
  ) async {
    try {
      dlog(
        '📧 Registrujem vozača $driverName sa email-om: $email (bez verification)',
      );

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'driver_name': driverName},
        emailRedirectTo: 'gavra013://auth/callback', // Omogući email verification
      );

      if (response.user != null) {
        dlog('✅ Vozač registrovan uspešno (bez email verifikacije)');
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
        final driverName = response.user!.userMetadata?['driver_name'] as String?;
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

  /// Pošalji ponovo email za potvrdu
  static Future<bool> resendConfirmationEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        dlog('❌ Nema ulogovanog korisnika');
        return false;
      }

      dlog('📧 Šaljem ponovo email za potvrdu na: ${user.email}');

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email,
        emailRedirectTo: 'gavra013://auth/callback',
      );

      dlog('✅ Email za potvrdu poslat ponovo');
      return true;
    } catch (e) {
      dlog('❌ Greška pri slanju potvrde: $e');
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





