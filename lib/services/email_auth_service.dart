import 'package:supabase_flutter/supabase_flutter.dart';

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
      // Debug logging removed for production
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'driver_name': driverName},
        emailRedirectTo: 'gavra://auth/callback', // Uskladi sa AndroidManifest.xml
      );

      if (response.user != null) {
        // Debug logging removed for production
        return true;
      } else {
        // Debug logging removed for production
        return false;
      }
    } catch (e) {
      // Debug logging removed for production
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
      // Debug logging removed for production
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final driverName = response.user!.userMetadata?['driver_name'] as String?;
        // Debug logging removed for production
        return driverName;
      } else {
        // Debug logging removed for production
        return null;
      }
    } catch (e) {
      // Debug logging removed for production
      return null;
    }
  }

  /// Resetuj lozinku preko email-a
  static Future<bool> resetPasswordViaEmail(String email) async {
    try {
      // Debug logging removed for production
      await _supabase.auth.resetPasswordForEmail(email);
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Pošalji ponovo email za potvrdu
  static Future<bool> resendConfirmationEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed for production
        return false;
      }
      // Debug logging removed for production
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email,
        emailRedirectTo: 'gavra://auth/callback',
      );
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// Odjavi se
  static Future<bool> signOut() async {
    try {
      // Debug logging removed for production
      await _supabase.auth.signOut();
      // Debug logging removed for production
      return true;
    } catch (e) {
      // Debug logging removed for production
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
