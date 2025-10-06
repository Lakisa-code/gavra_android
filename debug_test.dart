/// Test script za debug funkcionalnost bez Flutter dependency
void main() {
  print('🚀 Gavra Debug System Test');

  // Proveri debug flag
  const bool debugEnabled = bool.fromEnvironment('DEBUG', defaultValue: false);
  print('Debug enabled: $debugEnabled');

  // Simulacija debug, warning i error logova
  if (debugEnabled) {
    print(
        '[DEBUG ${DateTime.now()}] 🔍 Ovo je debug log - vidljiv samo u debug mode');
  }

  print('[WARNING ${DateTime.now()}] ⚠️ Ovo je warning - uvek vidljiv');
  print('[ERROR ${DateTime.now()}] ❌ Ovo je error - uvek vidljiv');

  // Test sa error objektom
  try {
    throw Exception('Test greška');
  } catch (e, stackTrace) {
    print('[ERROR ${DateTime.now()}] Uhvaćena test greška: $e');
    if (debugEnabled) {
      print('[DEBUG ${DateTime.now()}] Stack trace:\n$stackTrace');
    }
  }

  print('✅ Debug test završen');
}
