import '../globals.dart';

/// 🔐 CONFIG SERVICE
/// Upravlja kredencijalima aplikacije (Supabase URL, keys, etc.)
/// Učitava iz app_secrets tabele ili environment varijabli
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

  /// Inicijalizuj osnovne kredencijale (iz environment-a, bez Supabase)
  Future<void> initializeBasic() async {
    // Prvo pokušaj da učitaš iz environment varijabli (--dart-define)
    _supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    _supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    _supabaseServiceRoleKey = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

    // Ako nisu postavljeni, koristi default hardkodovane vrednosti
    if (_supabaseUrl.isEmpty) {
      _supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
      print('📌 [Config] Using hardcoded Supabase URL');
    }

    if (_supabaseAnonKey.isEmpty) {
      _supabaseAnonKey = 'sb_publishable_2ZIoNpLvOQx9Zv78NrHgBA_iXHcgzA5';
      print('📌 [Config] Using hardcoded Supabase Anon Key');
    }

    print('✅ [Config] URL: $_supabaseUrl');
    print('✅ [Config] Anon Key: ${_supabaseAnonKey.substring(0, 20)}...');

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception('Osnovni kredencijali nisu postavljeni. Postavite SUPABASE_URL i SUPABASE_ANON_KEY.');
    }
  }

  /// Inicijalizuj kredencijale iz environment varijabli umesto Vault-a
  Future<void> initializeVaultCredentials() async {
    // Učitaj service role key iz environment varijabli
    if (_supabaseServiceRoleKey.isEmpty) {
      _supabaseServiceRoleKey = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');
      if (_supabaseServiceRoleKey.isEmpty) {
        _supabaseServiceRoleKey = 'sb_secret_KjG-h8DIdo5v2WgIxnDyWw_9By0UDcA';
      }
    }

    // Učitaj keystore podatke iz environment varijabli
    _loadKeystoreFromEnv();
  }

  /// Inicijalizuj kredencijale (stari metod - zadržan za kompatibilnost)
  Future<void> initialize() async {
    await initializeBasic();
    // Vault credentials će biti učitani kasnije nakon Supabase inicijalizacije
  }

  /// Učitaj keystore podatke iz environment varijabli (zamena za Vault)
  void _loadKeystoreFromEnv() {
    // Učitaj iz environment varijabli
    _storePassword = const String.fromEnvironment('KEYSTORE_PASSWORD', defaultValue: 'GavraRelease2024');
    _keyPassword = const String.fromEnvironment('KEY_PASSWORD', defaultValue: 'GavraRelease2024');
    _keyAlias = const String.fromEnvironment('KEY_ALIAS', defaultValue: 'gavra-release-key');

    print('✅ Keystore kredencijali učitani iz environment varijabli');
  }

  String getSupabaseUrl() => _supabaseUrl;
  String getSupabaseAnonKey() => _supabaseAnonKey;
  String getSupabaseServiceRoleKey() => _supabaseServiceRoleKey;
  String getStorePassword() => _storePassword;
  String getKeyPassword() => _keyPassword;
  String getKeyAlias() => _keyAlias;

  /// Dobavi tajnu iz Vault-a
  Future<String?> getSecret(String name) async {
    try {
      final data = await supabase.from('app_secrets').select('value').eq('name', name).single();
      return data['value'] as String?;
    } catch (e) {
      print('Greška pri učitavanju tajne $name: $e');
      return null;
    }
  }

  String getDebugInfo() =>
      'URL: $_supabaseUrl, AnonKey: ${_supabaseAnonKey.substring(0, 10)}..., ServiceKey: ${_supabaseServiceRoleKey.isNotEmpty ? "Postavljen" : "Nije postavljen"}';
}
