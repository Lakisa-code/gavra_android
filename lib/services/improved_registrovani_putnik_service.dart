import 'package:supabase_flutter/supabase_flutter.dart';

import 'registrovani_putnik_service.dart';

/// 🚀 POBOLJŠANI SERVIS ZA MESEČNE PUTNIKE
/// Koristi nove SQL funkcije i optimizovanu logiku filtriranja
class ImprovedRegistrovaniPutnikService extends RegistrovaniPutnikService {
  ImprovedRegistrovaniPutnikService({SupabaseClient? supabaseClient}) : super(supabaseClient: supabaseClient);
}
