import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 🔐 CONFIG SERVICE
/// Upravlja kredencijalima aplikacije (Supabase URL, keys, etc.)
/// Učitava iz .env fajla ili environment varijabli
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  String _supabaseServiceRoleKey = '';
  String _storePassword = '';
  String _keyPassword = '';
  String _keyAlias = '';

  /// Inicijalizuj osnovne kredencijale (iz .env fajla ili environment varijabli)
  Future<void> initializeBasic() async {
    // Prvo učitaj .env fajl
    await dotenv.load(fileName: '.env');

    // Pokušaj da učitaš iz .env fajla
    _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    _supabaseServiceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

    // Ako nisu u .env, pokušaj iz environment varijabli (--dart-define)
    if (_supabaseUrl.isEmpty) {
      _supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    }
    if (_supabaseAnonKey.isEmpty) {
      _supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    }
    if (_supabaseServiceRoleKey.isEmpty) {
      _supabaseServiceRoleKey = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');
    }

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception(
          'Osnovni kredencijali nisu postavljeni. Postavite SUPABASE_URL i SUPABASE_ANON_KEY u .env fajlu ili kao environment varijable.');
    }

    // Učitaj keystore podatke
    _loadKeystoreFromEnv();
  }

  /// Inicijalizuj kredencijale (stari metod - zadržan za kompatibilnost)
  Future<void> initialize() async {
    await initializeBasic();
    // Vault credentials više nisu potrebni
  }

  /// Učitaj keystore podatke iz .env fajla ili environment varijabli
  void _loadKeystoreFromEnv() {
    // Učitaj iz .env fajla
    _storePassword = dotenv.env['KEYSTORE_PASSWORD'] ??
        const String.fromEnvironment('KEYSTORE_PASSWORD', defaultValue: 'GavraRelease2024');
    _keyPassword =
        dotenv.env['KEY_PASSWORD'] ?? const String.fromEnvironment('KEY_PASSWORD', defaultValue: 'GavraRelease2024');
    _keyAlias = dotenv.env['KEY_ALIAS'] ?? const String.fromEnvironment('KEY_ALIAS', defaultValue: 'gavra-release-key');
  }

  String getSupabaseUrl() => _supabaseUrl;
  String getSupabaseAnonKey() => _supabaseAnonKey;
  String getSupabaseServiceRoleKey() => _supabaseServiceRoleKey;
  String getStorePassword() => _storePassword;
  String getKeyPassword() => _keyPassword;
  String getKeyAlias() => _keyAlias;

  String getDebugInfo() =>
      'URL: $_supabaseUrl, AnonKey: ${_supabaseAnonKey.substring(0, 10)}..., ServiceKey: ${_supabaseServiceRoleKey.isNotEmpty ? "Postavljen" : "Nije postavljen"}';
}
