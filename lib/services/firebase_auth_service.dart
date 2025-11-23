import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_manager.dart';

/// Minimal compatibility shim for older code that still references
/// `FirebaseAuthService`.
///
/// This file intentionally avoids any firebase_auth types so it compiles
/// without firebase dependencies. All important operations are delegated to
/// `AuthManager` (Supabase-based) or implemented as safe no-ops.
class FirebaseAuthService {
  static bool get isAvailable => false;

  /// Current auth user (Supabase)
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Preserve a simple email format validator (compat API)
  static bool isValidEmailFormat(String email) => AuthManager.isValidEmailFormat(email);

  /// Sign out from Supabase
  static Future<void> signOut() async => Supabase.instance.client.auth.signOut();

  /// Reset password (compat wrapper)
  static Future<bool> resetPasswordViaEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resend email verification
  static Future<bool> resendEmailVerification() async {
    final res = await AuthManager.resendEmailVerification();
    return res.isSuccess;
  }

  /// Whether the current session is verified
  static bool get isEmailVerified => AuthManager.isEmailVerified();

  /// Small helper placeholder for backward compatibility. Returns null —
  /// actual profile APIs live inside AuthManager.
  static Future<Map<String, dynamic>?> getUserProfileFromSupabase() async => null;

  // No cached error helper in compact shim; keep error handling simple upstream
}
