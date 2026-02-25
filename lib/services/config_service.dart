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

  /// Inicijalizuj osnovne kredencijale (iz .env fajla ili environment varijabli)
  Future<void> initializeBasic() async {
    // Prvo učitaj .env fajl
    await dotenv.load(fileName: '.env');

    // Pokušaj da učitaš iz .env fajla
    _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    // Ako nisu u .env, pokušaj iz environment varijabli (--dart-define)
    if (_supabaseUrl.isEmpty) {
      _supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    }
    if (_supabaseAnonKey.isEmpty) {
      _supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    }

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception(
          'Osnovni kredencijali nisu postavljeni. Postavite SUPABASE_URL i SUPABASE_ANON_KEY u .env fajlu ili kao environment varijable.');
    }
  }

  String getSupabaseUrl() => _supabaseUrl;
  String getSupabaseAnonKey() => _supabaseAnonKey;
}
