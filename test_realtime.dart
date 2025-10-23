import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🧪 TESTIRANJE SUPABASE REALTIME...');

  // Inicijalizacija Supabase
  await Supabase.initialize(
    url: 'https://zkuwueldiusrenlnhnov.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprdXd1ZWxkaXVzcmVubG5obm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjkxOTI4MDQsImV4cCI6MjA0NDc2ODgwNH0.fgzs6XjnrSJqKaJoKj0YZhxmDfXy5n3mMdZNfcR7a8o',
  );

  try {
    print('📡 Pokušavam realtime konekciju...');

    // Test realtime stream
    final subscription = Supabase.instance.client.from('putnik').stream(primaryKey: ['id']).listen(
      (data) {
        print('✅ REALTIME RADI! Primljeni podaci: ${data.length} zapisa');
        print('🎯 Prvo 3 zapisa: ${data.take(3).toList()}');
      },
      onError: (error) {
        print('❌ REALTIME ERROR: $error');
      },
      onDone: () {
        print('🔚 Stream završen');
      },
    );

    print('⏰ Čekam 10 sekundi za test...');
    await Future.delayed(const Duration(seconds: 10));

    subscription.cancel();
    print('🏁 Test završen');
  } catch (e) {
    print('💥 GREŠKA: $e');
  }
}
