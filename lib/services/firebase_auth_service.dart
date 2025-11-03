import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/vozac_boja.dart';

/// 🔥 FIREBASE AUTH + SUPABASE DATA SERVICE
/// Firebase Auth za autentifikaciju, Supabase za podatke
class FirebaseAuthService {
  static final firebase_auth.FirebaseAuth _auth =
      firebase_auth.FirebaseAuth.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Trenutno ulogovan korisnik
  static firebase_auth.User? get currentUser => _auth.currentUser;

  /// Da li je korisnik ulogovan
  static bool get isLoggedIn => currentUser != null;

  /// Stream trenutnog korisnika za realtime updates
  static Stream<firebase_auth.User?> get authStateChanges =>
      _auth.authStateChanges();

  /// Email registracija sa Supabase podacima
  static Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String vozacName,
  }) async {
    try {
      // 🔒 VALIDACIJA: Email mora biti dozvoljen za vozača
      if (!VozacBoja.isEmailDozvoljenForVozac(email, vozacName)) {
        return AuthResult.failure(
          'Email $email nije dozvoljen za vozača $vozacName',
        );
      }

      // 1. Kreiranje korisnika u Firebase Auth
      final firebase_auth.UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Postavljanje display name-a
      await credential.user?.updateDisplayName(vozacName);

      // 3. Slanje email verifikacije
      await credential.user?.sendEmailVerification();

      // 4. Kreiranje profila u Supabase
      await _createUserProfileInSupabase(
        firebaseUid: credential.user!.uid,
        email: email,
        vozacName: vozacName,
      );

      return AuthResult.success(
        user: credential.user,
        message:
            'Registracija uspešna! Proverite svoj email za confirmation link.',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Email login sa verifikacijom
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final firebase_auth.UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔒 PROVERA EMAIL VERIFIKACIJE
      if (credential.user != null && !credential.user!.emailVerified) {
        // Automatski pošaljemo novi verification email
        await credential.user!.sendEmailVerification();

        return AuthResult.failure(
          'Email adresa nije verifikovana.\nNovi confirmation link je poslat na $email.\nProverite svoj inbox i kliknite na link.',
        );
      }

      // Sinhronizuj sa Supabase profilom
      await _syncUserProfileWithSupabase(credential.user!);

      return AuthResult.success(
        user: credential.user,
        message: 'Uspešno ulogovanje!',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Logout
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Reset password preko email-a
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(
        message: 'Link za reset šifre je poslat na $email',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Ponovno slanje email verifikacije
  static Future<AuthResult> resendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('Nema aktivnog korisnika');
      }

      if (user.emailVerified) {
        return AuthResult.success(
          message: 'Email je već verifikovan',
        );
      }

      await user.sendEmailVerification();
      return AuthResult.success(
        message: 'Novi confirmation link je poslat na ${user.email}',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Provera da li je trenutni korisnik verifikovan
  static bool get isEmailVerified {
    return currentUser?.emailVerified ?? false;
  }

  /// Validacija email formata
  static bool isValidEmailFormat(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Reset password preko email-a (kompatibilnost sa starim API)
  static Future<bool> resetPasswordViaEmail(String email) async {
    final result = await resetPassword(email);
    return result.isSuccess;
  }

  /// 🗄️ SUPABASE INTEGRATION

  /// Kreiranje korisničkog profila u Supabase
  static Future<void> _createUserProfileInSupabase({
    required String firebaseUid,
    required String email,
    required String vozacName,
  }) async {
    try {
      await _supabase.from('korisnici').insert({
        'firebase_uid': firebaseUid,
        'email': email,
        'vozac_name': vozacName,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    } catch (e) {
      // Log greška ali ne prekidaj registraciju
      // Tiha greška - Supabase sync nije kritičan za registraciju
    }
  }

  /// Sinhronizacija korisničkog profila sa Supabase
  static Future<void> _syncUserProfileWithSupabase(
    firebase_auth.User user,
  ) async {
    try {
      // Proveri da li postoji profil
      final response = await _supabase
          .from('korisnici')
          .select()
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (response == null) {
        // Kreiraj novi profil ako ne postoji
        await _createUserProfileInSupabase(
          firebaseUid: user.uid,
          email: user.email!,
          vozacName: user.displayName ?? 'Vozač',
        );
      } else {
        // Ažuriraj poslednju prijavu
        await _supabase.from('korisnici').update({
          'last_login': DateTime.now().toIso8601String(),
        }).eq('firebase_uid', user.uid);
      }
    } catch (e) {
      // Tiha greška - Supabase sync nije kritičan
    }
  }

  /// Dobijanje korisničkih podataka iz Supabase
  static Future<Map<String, dynamic>?> getUserProfileFromSupabase() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('korisnici')
          .select()
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      return response;
    } catch (e) {
      // Tiha greška - vraća null ako nema profila
      return null;
    }
  }

  /// Konverzija Firebase grešaka u srpski
  static String _getErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Šifra je previše slaba. Minimum 6 karaktera.';
      case 'email-already-in-use':
        return 'Email je već registrovan. Pokušajte login.';
      case 'invalid-email':
        return 'Email adresa nije validna.';
      case 'user-not-found':
        return 'Korisnik sa tim email-om ne postoji.';
      case 'wrong-password':
        return 'Neispravna šifra.';
      case 'too-many-requests':
        return 'Previše pokušaja. Pokušajte ponovo kasnije.';
      case 'network-request-failed':
        return 'Nema internet konekcije.';
      case 'invalid-credential':
        return 'Neispravni podaci za prijavu.';
      case 'user-disabled':
        return 'Korisnički nalog je onemogućen.';
      default:
        return 'Greška: ${e.message}';
    }
  }
}

/// Result wrapper za auth operacije
class AuthResult {
  AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
  });

  factory AuthResult.success({
    String? message,
    firebase_auth.User? user,
  }) {
    return AuthResult._(
      isSuccess: true,
      message: message ?? 'Operacija uspešna',
      user: user,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }

  final bool isSuccess;
  final String message;
  final firebase_auth.User? user;
}
